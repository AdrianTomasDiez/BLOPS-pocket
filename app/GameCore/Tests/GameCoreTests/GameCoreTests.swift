import XCTest
@testable import GameCore

final class GameCoreTests: XCTestCase {
    func testWeaponReloadAndFire() {
        let def = WeaponTable.def("m1911")
        var w = WeaponState(def: def)
        XCTAssertEqual(w.mag, 8)
        XCTAssertEqual(w.reserve, 80)
        XCTAssertFalse(w.isReloading)

        w.beginReload()
        XCTAssertFalse(w.isReloading) // timer starts but not finished

        for _ in 0..<10 { _ = w.tick(dt: 0.2, reloadSpeedMultiplier: 1.0) }
        XCTAssertFalse(w.isReloading)
        XCTAssertEqual(w.mag, 8)
        XCTAssertEqual(w.reserve, 80)

        w.mag = 3
        w.beginReload()
        for _ in 0..<8 { _ = w.tick(dt: 0.2, reloadSpeedMultiplier: 1.0) }
        XCTAssertEqual(w.mag, 8)
        XCTAssertEqual(w.reserve, 75)
    }

    func testWeaponUpgradeChangesStats() {
        var w = WeaponState(def: WeaponTable.def("olympia"))
        let baseDmg = w.damage
        let baseMag = w.magCapacity
        let baseRes = w.reserveCapacity
        w.upgrade()
        XCTAssertTrue(w.packed)
        XCTAssertEqual(w.damage, baseDmg * 2.6)
        XCTAssertEqual(w.magCapacity, Int(Float(baseMag) * 1.6))
        XCTAssertEqual(w.reserveCapacity, Int(Float(baseRes) * 1.5))
    }

    func testPlayerRegen() {
        var rng = SplitMix64(seed: 42)
        var p = Player(position: .zero)
        p.health = 40
        p.tick(dt: 1.0, speedMultiplier: 1.0)
        XCTAssertEqual(p.health, 40) // within delay

        p.lastHurtTime = 2.0
        p.tick(dt: 1.0, speedMultiplier: 1.0)
        XCTAssertEqual(p.health, 60)

        p.tick(dt: 1.0, speedMultiplier: 1.0)
        XCTAssertEqual(p.health, 80)

        p.tick(dt: 1.0, speedMultiplier: 1.0)
        XCTAssertEqual(p.health, 100) // capped
    }

    func testPlayerQuickRevive() {
        var rng = SplitMix64(seed: 42)
        var p = Player(position: .zero)
        p.perks.insert(.quickRevive)
        p.quickReviveUses = 3
        let revived = p.takeDamage(1000, rng: &rng)
        XCTAssertTrue(revived)
        XCTAssertEqual(p.health, p.maxHealth)
        XCTAssertFalse(p.isDowned)
        XCTAssertEqual(p.quickReviveUses, 2)
    }

    func testRoundCountsAndSpawn() {
        let w = GameWorld(seed: 1)
        XCTAssertEqual(w.round, 1)
        XCTAssertEqual(w.zombiesRemainingThisRound, 6)

        let w2 = GameWorld(seed: 1)
        var i = PlayerInput()
        for _ in 0..<400 {
            // Advance spawn and then just kill all spawned zombies so round completes
            _ = w2.update(dt: 0.05, input: i)
            // Kill any alive zombies (simulates the player clearing the round)
            for idx in w2.zombies.indices {
                if !w2.zombies[idx].isDying {
                    var z = w2.zombies[idx]
                    z.isDying = true
                    z.deathTimer = 1.5
                    w2.zombies[idx] = z
                }
            }
            if w2.round == 2 { break }
        }
        XCTAssertEqual(w2.round, 2)
        XCTAssertEqual(w2.highestRound, 2)
    }

    func testBuyDoorAndPerk() {
        var w = GameWorld(seed: 1)
        w.player.position = w.level.door("d1")!.interactPoint()
        var i = PlayerInput()
        i.interact = true

        w.player.addPoints(1000)
        let ev = w.update(dt: 0.05, input: i)
        XCTAssertTrue(ev.contains { if case .buyDoor = $0 { return true } else { return false } })
        XCTAssertTrue(w.doorsOpen.contains("d1"))

        w.player.addPoints(3000)
        w.player.position = w.level.perkMachines[0].position
        let ev2 = w.update(dt: 0.05, input: i)
        XCTAssertTrue(ev2.contains { if case .buyPerk = $0 { return true } else { return false } })
        XCTAssertTrue(w.player.perks.contains(.quickRevive))
    }

    func testPackAPunch() {
        var w = GameWorld(seed: 1)
        w.powerOn = true
        w.player.addPoints(6000)
        w.player.position = w.level.packAPunchPosition
        var i = PlayerInput()
        i.interact = true
        let ev = w.update(dt: 0.05, input: i)
        XCTAssertTrue(ev.contains { if case .packAPunchUsed = $0 { return true } else { return false } })
        XCTAssertTrue(w.player.currentWeapon?.packed == true)
    }

    func testShotHitsZombie() {
        var w = GameWorld(seed: 1)
        w.player.addPoints(1000)
        let z = Zombie(id: 1, position: Vec3(10, 0, 5), health: 100, speed: 1.5)
        w.zombies = [z]
        w.zombiesRemainingThisRound = 1
        w.zombiesSpawnedThisRound = 1

        w.player.yaw = atan2(10 - w.player.position.x, 5 - w.player.position.z)
        var i = PlayerInput()
        i.firing = true
        let ev = w.update(dt: 0.05, input: i)
        XCTAssertTrue(ev.contains { if case .zombieHit = $0 { return true } else { return false } })
    }

    func testDeterministicRNG() {
        var a = SplitMix64(seed: 12345)
        var b = SplitMix64(seed: 12345)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
            XCTAssertEqual(a.unit(), b.unit(), accuracy: 0.0001)
        }
    }
}