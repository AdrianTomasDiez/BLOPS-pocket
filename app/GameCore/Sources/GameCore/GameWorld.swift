import Foundation

public enum GameEvent: Equatable {
    case shotFired(weaponId: String, from: Vec3, direction: Vec3)
    case zombieHit(zombieId: Int, damage: Float, killed: Bool, headshot: Bool)
    case zombieSpawned(zombieId: Int)
    case buyDoor(doorId: String)
    case buyWeapon(wallBuyId: String, weaponId: String)
    case buyAmmo(wallBuyId: String)
    case buyPerk(perk: Perk)
    case upgradeWeapon(weaponIndex: Int)
    case reloadStart
    case playerHurt(amount: Float, downed: Bool)
    case playerRevived
    case roundStart(round: Int)
    case roundEnd(round: Int)
    case powerActivated
    case packAPunchUsed
    case gameOver(score: Int, highestRound: Int)
}

public struct PlayerInput: Equatable {
    public var moveX: Float = 0   // strafe right +
    public var moveZ: Float = 0   // forward +
    public var lookDX: Float = 0
    public var lookDY: Float = 0
    public var firing: Bool = false
    public var sprint: Bool = false
    public var reload: Bool = false
    public var interact: Bool = false

    public init() {}
}

public enum GameState { case playing, gameOver }

public struct Player: Equatable {
    public var position: Vec3
    public var yaw: Float = 0
    public var pitch: Float = 0
    public var health: Float = 100
    public var maxHealth: Float = 100
    public var points: Int = 0
    public var weapons: [WeaponState] = []
    public var currentWeaponIndex: Int = 0
    public var perks: Set<Perk> = []
    public var quickReviveUses: Int = 3
    public var isDowned: Bool = false
    public var downTimer: Float = 0
    public var lastHurtTime: Float = 0
    public var regenDelay: Float = 2.0
    public var regenRate: Float = 20.0

    public static let height: Float = 1.6
    public static let radius: Float = 0.35

    public init(position: Vec3) {
        self.position = position
        let w = WeaponState(def: WeaponTable.def(WeaponTable.startingWeapon))
        weapons = [w]
    }

    public var currentWeapon: WeaponState? {
        guard currentWeaponIndex < weapons.count else { return nil }
        return weapons[currentWeaponIndex]
    }

    public mutating func addPoints(_ n: Int) { points = Swift.max(0, points + n) }

    public mutating func takeDamage(_ amount: Float, rng: inout SplitMix64) -> Bool {
        if isDowned { return false }
        health -= amount
        lastHurtTime = 0
        if health <= 0 {
            if perks.contains(.quickRevive) && quickReviveUses > 0 {
                quickReviveUses -= 1
                health = maxHealth
                isDowned = false
                return true // revived
            }
            health = 0
            isDowned = true
        }
        return false
    }

    public mutating func heal(_ amount: Float) {
        health = Swift.min(maxHealth, health + amount)
    }

    public mutating func tick(dt: Float, speedMultiplier: Float) {
        if isDowned { return }
        if lastHurtTime < regenDelay { lastHurtTime += dt }
        else if health < maxHealth { heal(regenRate * dt) }
    }
}

public struct Zombie: Equatable {
    public let id: Int
    public var position: Vec3
    public var health: Float
    public var maxHealth: Float
    public var attackCooldown: Float = 0
    public var speed: Float
    public let radius: Float = 0.35
    public let height: Float = 1.8
    public var isDying: Bool = false
    public var deathTimer: Float = 0
    public var stagger: Float = 0
    public var kind: Kind

    public enum Kind: String { case normal, runner, crawler }

    public init(id: Int, position: Vec3, health: Float, speed: Float, kind: Kind = .normal) {
        self.id = id
        self.position = position
        self.health = health
        self.maxHealth = health
        self.speed = speed
        self.kind = kind
    }
}

public final class GameWorld {
    public let level: LevelSpec
    public var player: Player
    public var zombies: [Zombie] = []
    public var doorsOpen: Set<String> = []
    public var powerOn: Bool = false
    public var round: Int = 1
    public var zombiesRemainingThisRound: Int = 0
    public var zombiesToSpawn: Int = 0
    public var zombiesSpawnedThisRound: Int = 0
    public var maxAliveZombies: Int = 6
    public var spawnInterval: Float = 1.0
    public var spawnTimer: Float = 0
    public var roundEndTimer: Float = -1
    public var state: GameState = .playing
    public var highestRound: Int = 1
    public var rng: SplitMix64

    private var nextZombieId: Int = 1

    public init(level: LevelSpec = .kino, seed: UInt64 = 1) {
        self.level = level
        self.player = Player(position: level.playerStart)
        self.rng = SplitMix64(seed: seed)
        beginRound()
    }

    public func update(dt: Float, input: PlayerInput) -> [GameEvent] {
        guard state == .playing else { return [] }
        var events: [GameEvent] = []

        player.tick(dt: dt, speedMultiplier: 1.0)
        if var w = player.currentWeapon {
            _ = w.tick(dt: dt, reloadSpeedMultiplier: 1.0)
            player.weapons[player.currentWeaponIndex] = w
        }

        if !player.isDowned {
            movePlayer(dt: dt, input: input, events: &events)
        }

        updateZombies(dt: dt, events: &events)
        handleSpawning(dt: dt, events: &events)
        handleRoundEnd(dt: dt, events: &events)
        processInput(input: input, dt: dt, events: &events)


        if player.isDowned {
            state = .gameOver
            events.append(.gameOver(score: player.points, highestRound: highestRound))
        }

        return events
    }

    private func movePlayer(dt: Float, input: PlayerInput, events: inout [GameEvent]) {
        let speed: Float = (input.sprint ? Float(6.5) : Float(4.2)) * (player.perks.contains(.speedCola) ? Float(1.3) : Float(1.0))
        let forward = Vec3(sin(player.yaw), 0, cos(player.yaw)).normalized()
        let right = Vec3(-forward.z, 0, forward.x)

        var pos = player.position
        pos = pos + forward * (input.moveZ * speed * dt)
        pos = pos + right * (input.moveX * speed * dt)

        pos.y = player.position.y
        pos = resolveCollision(pos, radius: Player.radius, height: Player.height)

        player.position = pos
        player.yaw += input.lookDX
        let twopi = 2 * Float.pi
        if player.yaw > twopi { player.yaw = player.yaw.truncatingRemainder(dividingBy: twopi) }
        if player.yaw < -twopi { player.yaw = -player.yaw.truncatingRemainder(dividingBy: twopi) }
        player.pitch = Swift.max(-Float.pi / 2, Swift.min(Float.pi / 2, player.pitch + input.lookDY))
    }

    private func updateZombies(dt: Float, events: inout [GameEvent]) {
        for i in zombies.indices {
            guard !zombies[i].isDying else {
                zombies[i].deathTimer -= dt
                continue
            }
            if zombies[i].stagger > 0 { zombies[i].stagger = Swift.max(0, zombies[i].stagger - dt) }
            if zombies[i].attackCooldown > 0 { zombies[i].attackCooldown -= dt }

            let target = player.position
            let toTarget = target - zombies[i].position
            let hx = sqrt(toTarget.x * toTarget.x + toTarget.z * toTarget.z)
            if hx < 0.001 { continue }
            let nx = toTarget.x / hx
            let nz = toTarget.z / hx

            let sep = separation(zombies[i])
            let moveSpeed = zombies[i].speed * (zombies[i].stagger > 0 ? 0.25 : 1.0)
            var newPos = zombies[i].position
            newPos.x += (nx + sep.x) * moveSpeed * dt
            newPos.z += (nz + sep.z) * moveSpeed * dt
            newPos = resolveCollision(newPos, radius: zombies[i].radius, height: zombies[i].height)
            zombies[i].position = newPos

            if hx < 1.0 && zombies[i].attackCooldown <= 0 {
                zombies[i].attackCooldown = 1.0
                let dmg: Float = 25
                let revived = player.takeDamage(dmg, rng: &rng)
                events.append(.playerHurt(amount: dmg, downed: player.isDowned))
                if revived { events.append(.playerRevived) }
            }
        }
        // Purge fully dead zombies so the array doesn't grow
        zombies.removeAll { $0.isDying && $0.deathTimer <= 0 }
    }

    private func separation(_ z: Zombie) -> Vec3 {
        var sx: Float = 0, sz: Float = 0
        for o in zombies where o.id != z.id && !o.isDying {
            let dx = z.position.x - o.position.x
            let dz = z.position.z - o.position.z
            let d2 = dx * dx + dz * dz
            if d2 < 0.8 * 0.8 && d2 > 0.001 {
                let inv = 0.8 / d2.squareRoot()
                sx += dx * inv * 0.5
                sz += dz * inv * 0.5
            }
        }
        return Vec3(sx, 0, sz)
    }

    private func handleSpawning(dt: Float, events: inout [GameEvent]) {
        guard zombiesSpawnedThisRound < zombiesToSpawn else { return }
        let alive = zombies.filter { !$0.isDying }.count
        guard alive < maxAliveZombies else { return }
        spawnTimer -= dt
        guard spawnTimer <= 0 else { return }
        spawnTimer = spawnInterval

        guard let spawnPos = pickSpawnPoint() else { return }
        let baseHP = 150 + Float(round - 1) * 100
        let spd = 1.2 + Float(min(round, 10)) * 0.25
        let kind: Zombie.Kind = round > 10 && rng.unit() < 0.15 ? .runner : .normal
        let hp = kind == .runner ? baseHP * 0.5 : baseHP
        let speed = kind == .runner ? spd * 1.6 : spd

        let z = Zombie(id: nextZombieId, position: spawnPos, health: hp, speed: speed, kind: kind)
        nextZombieId += 1
        zombies.append(z)
        zombiesSpawnedThisRound += 1
        zombiesRemainingThisRound = Swift.max(0, zombiesToSpawn - zombiesSpawnedThisRound)
        events.append(.zombieSpawned(zombieId: z.id))
    }

    private func pickSpawnPoint() -> Vec3? {
        guard let pRoom = level.room(containing: player.position) else { return nil }
        var reachable: Set<String> = [pRoom.id]
        var frontier = [pRoom.id]
        while !frontier.isEmpty {
            let cur = frontier.removeLast()
            for d in level.doors where doorsOpen.contains(d.id) {
                if d.roomA == cur && !reachable.contains(d.roomB) {
                    reachable.insert(d.roomB); frontier.append(d.roomB)
                } else if d.roomB == cur && !reachable.contains(d.roomA) {
                    reachable.insert(d.roomA); frontier.append(d.roomA)
                }
            }
        }

        var candidates: [Vec3] = []
        for r in reachable {
            guard let pts = level.spawnPoints[r] else { continue }
            for p in pts {
                let dx = p.x - player.position.x
                let dz = p.z - player.position.z
                if dx * dx + dz * dz >= 8 * 8 { candidates.append(p) }
            }
        }
        guard !candidates.isEmpty else { return nil }
        return candidates[rng.int(0, candidates.count - 1)]
    }

    private func handleRoundEnd(dt: Float, events: inout [GameEvent]) {
        if zombiesSpawnedThisRound >= zombiesToSpawn && zombies.filter({ !$0.isDying }).isEmpty {
            if roundEndTimer < 0 {
                roundEndTimer = 3.0
                events.append(.roundEnd(round: round))
            } else {
                roundEndTimer -= dt
                if roundEndTimer <= 0 {
                    round += 1
                    highestRound = Swift.max(highestRound, round)
                    beginRound()
                    events.append(.roundStart(round: round))
                    roundEndTimer = -1
                }
            }
        }
    }

    private func beginRound() {
        let counts = [6, 8, 13, 16, 19, 22, 25, 28, 31, 33]
        zombiesToSpawn = round <= counts.count ? counts[round - 1] : 33
        zombiesSpawnedThisRound = 0
        zombiesRemainingThisRound = zombiesToSpawn
        maxAliveZombies = Swift.min(24, 4 + round * 2)
        spawnInterval = Swift.max(0.25, 0.6 - Float(round) * 0.05)
    }

    private func processInput(input: PlayerInput, dt: Float, events: inout [GameEvent]) {
        if input.reload, var w = player.currentWeapon {
            w.beginReload()
            player.weapons[player.currentWeaponIndex] = w
            events.append(.reloadStart)
        }

        if input.firing, var w = player.currentWeapon {
            if w.canFire {
                w.cooldown = w.def.fireInterval
                let dir = Vec3.direction(yaw: player.yaw, pitch: player.pitch)
                events.append(.shotFired(weaponId: w.def.id,
                                         from: player.position + Vec3(0, Player.height * 0.9, 0),
                                         direction: dir))
                let hit = traceShot(origin: player.position + Vec3(0, Player.height * 0.9, 0),
                                    direction: dir, weapon: w, events: &events)
                if hit { w.mag -= 1 }
            } else if w.mag == 0 && !w.isReloading {
                w.beginReload()
                events.append(.reloadStart)
            }
            player.weapons[player.currentWeaponIndex] = w
        }

        if input.interact {
            tryInteract(events: &events)
        }
    }

    private func traceShot(origin: Vec3, direction: Vec3, weapon: WeaponState, events: inout [GameEvent]) -> Bool {
        var hitAny = false
        let spread = weapon.def.spread
        for _ in 0..<weapon.def.pellets {
            let dir = direction
            var pos = origin
            let step: Float = 0.15
            var dist: Float = 0
            while dist < 60 {
                pos = pos + dir * step
                dist += step

                if collidesWalls(pos) { break }

                for i in zombies.indices where !zombies[i].isDying {
                    let z = zombies[i]
                    let dx = pos.x - z.position.x
                    let dz = pos.z - z.position.z
                    let h2 = dx * dx + dz * dz
                    if h2 < z.radius * z.radius && pos.y < z.position.y + z.height && pos.y > z.position.y {
                        let headshot = pos.y > z.position.y + z.height * 0.75
                        let mult = headshot ? weapon.def.headshotMultiplier : 1.0
                        var dmg = weapon.damage * mult
                        if weapon.def.pellets > 1 { dmg /= Float(weapon.def.pellets) }
                        var zc = zombies[i]
                        zc.health -= dmg
                        zc.stagger = 0.2
                        let killed = zc.health <= 0
                        if killed {
                            zc.isDying = true
                            zc.deathTimer = 1.5
                            let points = headshot ? 100 : 60
                            player.addPoints(points)

                        } else {
                            player.addPoints(10)
                        }
                        zombies[i] = zc
                        events.append(.zombieHit(zombieId: z.id, damage: dmg, killed: killed, headshot: headshot))
                        hitAny = true
                        break
                    }
                }
                if hitAny { break }
            }
        }
        return hitAny
    }

    private func collidesWalls(_ p: Vec3) -> Bool {
        for w in level.wallBoxes() where w.contains(point: p) { return true }
        for d in level.doors where !doorsOpen.contains(d.id) && d.collider.contains(point: p) { return true }
        for prop in level.props where prop.contains(point: p) { return true }
        return false
    }

    private func resolveCollision(_ pos: Vec3, radius: Float, height: Float) -> Vec3 {
        var p = pos
        for w in level.wallBoxes() { p = w.pushOut(p, radius: radius, height: height) }
        for d in level.doors where !doorsOpen.contains(d.id) { p = d.collider.pushOut(p, radius: radius, height: height) }
        for prop in level.props { p = prop.pushOut(p, radius: radius, height: height) }
        return p
    }

    private func tryInteract(events: inout [GameEvent]) {
        let p = player.position
        let reach: Float = 2.5

        if !powerOn, (p - level.powerPosition).horizontalLength < reach {
            powerOn = true
            events.append(.powerActivated)
            return
        }
        if powerOn, (p - level.packAPunchPosition).horizontalLength < reach {
            if player.points >= 5000, var w = player.currentWeapon, !w.packed {
                player.points -= 5000
                w.upgrade()
                player.weapons[player.currentWeaponIndex] = w
                events.append(.upgradeWeapon(weaponIndex: player.currentWeaponIndex))
                events.append(.packAPunchUsed)
            }
            return
        }
        for wb in level.wallBuys where (p - wb.position).horizontalLength < reach {
            if player.weapons.count < 2 {
                if player.points >= wb.cost {
                    player.points -= wb.cost
                    let ws = WeaponState(def: WeaponTable.def(wb.weaponId))
                    player.weapons.append(ws)
                    player.currentWeaponIndex = player.weapons.count - 1
                    events.append(.buyWeapon(wallBuyId: wb.id, weaponId: wb.weaponId))
                }
            } else {
                if player.points >= wb.cost / 2 {
                    player.points -= wb.cost / 2
                    if let idx = player.weapons.firstIndex(where: { $0.def.id == wb.weaponId }) {
                        player.weapons[idx].refillReserve()
                        events.append(.buyAmmo(wallBuyId: wb.id))
                    }
                }
            }
            return
        }
        for pm in level.perkMachines where (p - pm.position).horizontalLength < reach {
            if !player.perks.contains(pm.perk), player.points >= pm.perk.cost {
                player.points -= pm.perk.cost
                player.perks.insert(pm.perk)
                if pm.perk == .quickRevive {
                    player.quickReviveUses = 3
                    player.maxHealth = 250
                    player.health = Swift.min(player.maxHealth, player.health + 150)
                } else if pm.perk == .juggernog {
                    player.maxHealth = 250
                    player.health = Swift.min(player.maxHealth, player.health)
                }
                events.append(.buyPerk(perk: pm.perk))
            }
            return
        }
        for d in level.doors where !doorsOpen.contains(d.id) && (p - d.interactPoint()).horizontalLength < reach {
            if player.points >= d.cost {
                player.points -= d.cost
                doorsOpen.insert(d.id)
                events.append(.buyDoor(doorId: d.id))
            }
            return
        }
    }
}