import Foundation

public enum LevelSide { case minX, maxX, minZ, maxZ }

public struct Room: Equatable {
    public let id: String
    public let name: String
    public let min: Vec3
    public let max: Vec3

    public init(id: String, name: String, minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        self.id = id
        self.name = name
        self.min = Vec3(minX, 0, minZ)
        self.max = Vec3(maxX, 0, maxZ)
    }

    public var center: Vec3 { Vec3((min.x + max.x) / 2, 0, (min.z + max.z) / 2) }

    public func contains(_ p: Vec3) -> Bool {
        p.x >= min.x && p.x <= max.x && p.z >= min.z && p.z <= max.z
    }
}

public struct DoorDef: Equatable {
    public let id: String
    public let name: String
    public let roomA: String
    public let roomB: String
    public let cost: Int
    public let center: Vec3
    /// True when the doorway sits on a vertical wall (the wall plane normal is X).
    public let alongZ: Bool
    public let width: Float

    public init(id: String, name: String, roomA: String, roomB: String, cost: Int,
                center: Vec3, alongZ: Bool, width: Float = 3) {
        self.id = id
        self.name = name
        self.roomA = roomA
        self.roomB = roomB
        self.cost = cost
        self.center = center
        self.alongZ = alongZ
        self.width = width
    }

    public var collider: AABB {
        if alongZ {
            return AABB(center: Vec3(center.x, 2, center.z), size: Vec3(0.35, 4, width))
        }
        return AABB(center: Vec3(center.x, 2, center.z), size: Vec3(width, 4, 0.35))
    }

    public func interactPoint() -> Vec3 { Vec3(center.x, 0, center.z) }
}

public struct WallBuyDef: Equatable {
    public let id: String
    public let weaponId: String
    public let cost: Int
    public let position: Vec3
    public let label: String

    public init(id: String, weaponId: String, cost: Int, position: Vec3, label: String) {
        self.id = id
        self.weaponId = weaponId
        self.cost = cost
        self.position = position
        self.label = label
    }
}

public enum Perk: String, CaseIterable, Codable {
    case quickRevive, juggernog, speedCola, doubleTap

    public var displayName: String {
        switch self {
        case .quickRevive: return "Quick Revive"
        case .juggernog: return "Juggernog"
        case .speedCola: return "Speed Cola"
        case .doubleTap: return "Double Tap"
        }
    }

    public var cost: Int {
        switch self {
        case .quickRevive: return 500
        case .juggernog: return 2500
        case .speedCola: return 3000
        case .doubleTap: return 2000
        }
    }
}

public struct PerkMachineDef: Equatable {
    public let perk: Perk
    public let position: Vec3
    public init(perk: Perk, position: Vec3) { self.perk = perk; self.position = position }
}

public struct LevelSpec {
    public let id: String
    public let name: String
    public let rooms: [Room]
    public let doors: [DoorDef]
    public let wallBuys: [WallBuyDef]
    public let perkMachines: [PerkMachineDef]
    public let props: [AABB]
    public let playerStart: Vec3
    public let powerPosition: Vec3
    public let packAPunchPosition: Vec3
    public let spawnPoints: [String: [Vec3]]

    public static let wallHeight: Float = 4.0
    public static let wallThickness: Float = 0.35

    public init(id: String, name: String, rooms: [Room], doors: [DoorDef],
                wallBuys: [WallBuyDef], perkMachines: [PerkMachineDef], props: [AABB],
                playerStart: Vec3, powerPosition: Vec3, packAPunchPosition: Vec3,
                spawnPoints: [String: [Vec3]]) {
        self.id = id
        self.name = name
        self.rooms = rooms
        self.doors = doors
        self.wallBuys = wallBuys
        self.perkMachines = perkMachines
        self.props = props
        self.playerStart = playerStart
        self.powerPosition = powerPosition
        self.packAPunchPosition = packAPunchPosition
        self.spawnPoints = spawnPoints
    }

    public func room(containing p: Vec3) -> Room? {
        rooms.first { $0.contains(p) }
    }

    public func room(_ id: String) -> Room? { rooms.first { $0.id == id } }

    public func door(_ id: String) -> DoorDef? { doors.first { $0.id == id } }

    /// Static wall boxes, generated per room with gaps where doorways are.
    public func wallBoxes() -> [AABB] {
        var out: [AABB] = []
        let h = LevelSpec.wallHeight
        let t = LevelSpec.wallThickness
        for room in rooms {
            for side in [LevelSide.minX, .maxX, .minZ, .maxZ] {
                for seg in segments(room: room, side: side) where seg.1 - seg.0 > 0.01 {
                    let mid = (seg.0 + seg.1) / 2
                    switch side {
                    case .minX:
                        out.append(AABB(center: Vec3(room.min.x, h / 2, mid),
                                        size: Vec3(t, h, seg.1 - seg.0)))
                    case .maxX:
                        out.append(AABB(center: Vec3(room.max.x, h / 2, mid),
                                        size: Vec3(t, h, seg.1 - seg.0)))
                    case .minZ:
                        out.append(AABB(center: Vec3(mid, h / 2, room.min.z),
                                        size: Vec3(seg.1 - seg.0, h, t)))
                    case .maxZ:
                        out.append(AABB(center: Vec3(mid, h / 2, room.max.z),
                                        size: Vec3(seg.1 - seg.0, h, t)))
                    }
                }
            }
        }
        return out
    }

    private func segments(room: Room, side: LevelSide) -> [(Float, Float)] {
        var lo: Float
        var hi: Float
        switch side {
        case .minX, .maxX: lo = room.min.z; hi = room.max.z
        case .minZ, .maxZ: lo = room.min.x; hi = room.max.x
        }

        var gaps: [(Float, Float)] = []
        for d in doors where d.roomA == room.id || d.roomB == room.id {
            let half = d.width / 2
            switch side {
            case .minX where abs(d.center.x - room.min.x) < 0.01 && d.alongZ:
                gaps.append((d.center.z - half, d.center.z + half))
            case .maxX where abs(d.center.x - room.max.x) < 0.01 && d.alongZ:
                gaps.append((d.center.z - half, d.center.z + half))
            case .minZ where abs(d.center.z - room.min.z) < 0.01 && !d.alongZ:
                gaps.append((d.center.x - half, d.center.x + half))
            case .maxZ where abs(d.center.z - room.max.z) < 0.01 && !d.alongZ:
                gaps.append((d.center.x - half, d.center.x + half))
            default:
                break
            }
        }
        gaps.sort { $0.0 < $1.0 }

        var result: [(Float, Float)] = []
        var cursor = lo
        for g in gaps {
            let start = Swift.max(lo, g.0)
            if start > cursor { result.append((cursor, start)) }
            cursor = Swift.max(cursor, Swift.min(hi, g.1))
        }
        if cursor < hi { result.append((cursor, hi)) }
        return result
    }
}

public extension LevelSpec {
    /// Kino-inspired theatre layout: start room, foyer, stage, backstage, power alley.
    /// Geometry is original; no assets from the retail game are used.
    static let kino: LevelSpec = {
        let rooms = [
            Room(id: "start", name: "Start Room", minX: 0, maxX: 14, minZ: 0, maxZ: 12),
            Room(id: "foyer", name: "Foyer", minX: 14, maxX: 30, minZ: 0, maxZ: 14),
            Room(id: "stage", name: "Stage", minX: 14, maxX: 30, minZ: 14, maxZ: 28),
            Room(id: "backstage", name: "Backstage", minX: 0, maxX: 14, minZ: 12, maxZ: 28),
            Room(id: "alley", name: "Power Alley", minX: 0, maxX: 14, minZ: 28, maxZ: 40)
        ]

        let doors = [
            DoorDef(id: "d1", name: "Start Room Door", roomA: "start", roomB: "foyer",
                    cost: 750, center: Vec3(14, 0, 5.5), alongZ: true),
            DoorDef(id: "d2", name: "Foyer Door", roomA: "foyer", roomB: "stage",
                    cost: 1000, center: Vec3(21.5, 0, 14), alongZ: false),
            DoorDef(id: "d3", name: "Stage Door", roomA: "stage", roomB: "backstage",
                    cost: 1000, center: Vec3(14, 0, 21.5), alongZ: true),
            DoorDef(id: "d4", name: "Alley Door", roomA: "backstage", roomB: "alley",
                    cost: 1000, center: Vec3(7, 0, 28), alongZ: false)
        ]

        let wallBuys = [
            WallBuyDef(id: "wb_olympia", weaponId: "olympia", cost: 500,
                       position: Vec3(2.5, 0, 11.2), label: "Olympia"),
            WallBuyDef(id: "wb_m14", weaponId: "m14", cost: 500,
                       position: Vec3(11.5, 0, 11.2), label: "M14"),
            WallBuyDef(id: "wb_mp40", weaponId: "mp40", cost: 1000,
                       position: Vec3(16, 0, 0.8), label: "MP40"),
            WallBuyDef(id: "wb_stakeout", weaponId: "stakeout", cost: 1500,
                       position: Vec3(28.5, 0, 11), label: "Stakeout"),
            WallBuyDef(id: "wb_mp5k", weaponId: "mp5k", cost: 1000,
                       position: Vec3(16, 0, 27.2), label: "MP5K"),
            WallBuyDef(id: "wb_ak74u", weaponId: "ak74u", cost: 1200,
                       position: Vec3(28.5, 0, 21), label: "AK74u"),
            WallBuyDef(id: "wb_famas", weaponId: "famas", cost: 1500,
                       position: Vec3(1.2, 0, 20), label: "FAMAS")
        ]

        let perks = [
            PerkMachineDef(perk: .quickRevive, position: Vec3(3, 0, 2)),
            PerkMachineDef(perk: .juggernog, position: Vec3(25, 0, 2)),
            PerkMachineDef(perk: .speedCola, position: Vec3(3, 0, 25)),
            PerkMachineDef(perk: .doubleTap, position: Vec3(11, 0, 31))
        ]

        let props = [
            // Stage platform and crates.
            AABB(center: Vec3(22, 0.3, 22), size: Vec3(10, 0.6, 6)),
            AABB(center: Vec3(4, 0.5, 8), size: Vec3(1.4, 1, 1.4)),
            AABB(center: Vec3(10, 0.5, 8), size: Vec3(1.4, 1, 1.4)),
            AABB(center: Vec3(18, 0.5, 5), size: Vec3(1.6, 1, 1.6)),
            AABB(center: Vec3(26, 0.5, 8), size: Vec3(1.6, 1, 1.6)),
            AABB(center: Vec3(5, 0.5, 18), size: Vec3(1.5, 1, 1.5)),
            AABB(center: Vec3(9, 0.5, 32), size: Vec3(1.5, 1, 1.5))
        ]

        var spawns: [String: [Vec3]] = [:]
        for room in rooms {
            let c = room.center
            spawns[room.id] = [
                Vec3(room.min.x + 1.5, 0, room.min.z + 1.5),
                Vec3(room.max.x - 1.5, 0, room.min.z + 1.5),
                Vec3(room.min.x + 1.5, 0, room.max.z - 1.5),
                Vec3(room.max.x - 1.5, 0, room.max.z - 1.5),
                c
            ]
        }

        return LevelSpec(id: "kino", name: "Kino der Toten",
                         rooms: rooms, doors: doors, wallBuys: wallBuys,
                         perkMachines: perks, props: props,
                         playerStart: Vec3(7, 0, 3),
                         powerPosition: Vec3(12, 0, 27),
                         packAPunchPosition: Vec3(10, 0, 36),
                         spawnPoints: spawns)
    }()
}
