import Foundation

public struct WeaponDef: Equatable {
    public let id: String
    public let name: String
    public let upgradedName: String
    public let damage: Float
    public let headshotMultiplier: Float
    public let rpm: Float
    public let magSize: Int
    public let reserveMax: Int
    public let reloadTime: Float
    public let spread: Float
    public let isAutomatic: Bool
    public let pellets: Int
    public let wallCost: Int
    public let isWonder: Bool

    public init(id: String, name: String, upgradedName: String, damage: Float,
                headshotMultiplier: Float = 2.0, rpm: Float, magSize: Int, reserveMax: Int,
                reloadTime: Float, spread: Float, isAutomatic: Bool, pellets: Int = 1,
                wallCost: Int = 0, isWonder: Bool = false) {
        self.id = id
        self.name = name
        self.upgradedName = upgradedName
        self.damage = damage
        self.headshotMultiplier = headshotMultiplier
        self.rpm = rpm
        self.magSize = magSize
        self.reserveMax = reserveMax
        self.reloadTime = reloadTime
        self.spread = spread
        self.isAutomatic = isAutomatic
        self.pellets = pellets
        self.wallCost = wallCost
        self.isWonder = isWonder
    }

    public var fireInterval: Float { 60.0 / rpm }
}

public struct WeaponState: Equatable {
    public var def: WeaponDef
    public var mag: Int
    public var reserve: Int
    public var packed: Bool
    public var reloadTimer: Float
    public var cooldown: Float

    public init(def: WeaponDef, packed: Bool = false) {
        self.def = def
        self.mag = def.magSize
        self.reserve = def.reserveMax
        self.packed = false
        self.reloadTimer = 0
        self.cooldown = 0
        self.packed = packed
    }

    public var displayName: String { packed ? def.upgradedName : def.name }
    public var magCapacity: Int { packed ? Int(Float(def.magSize) * 1.6) : def.magSize }
    public var reserveCapacity: Int { packed ? Int(Float(def.reserveMax) * 1.5) : def.reserveMax }
    public var damage: Float { packed ? def.damage * 2.6 : def.damage }
    public var isReloading: Bool { reloadTimer > 0 }
    public var canFire: Bool { !isReloading && cooldown <= 0 && mag > 0 }

    public mutating func beginReload() {
        guard !isReloading, mag < magCapacity, reserve > 0 else { return }
        reloadTimer = def.reloadTime
    }

    /// Completes a reload when the timer runs out. Returns true on completion.
    public mutating func tick(dt: Float, reloadSpeedMultiplier: Float) -> Bool {
        cooldown = Swift.max(0, cooldown - dt)
        guard reloadTimer > 0 else { return false }
        reloadTimer -= dt * reloadSpeedMultiplier
        if reloadTimer > 0 { return false }
        reloadTimer = 0
        let needed = magCapacity - mag
        let moved = Swift.min(needed, reserve)
        mag += moved
        reserve -= moved
        return true
    }

    public mutating func upgrade() {
        let oldCapacity = magCapacity
        let oldReserve = reserveCapacity
        packed = true
        mag = Swift.min(magCapacity, mag == oldCapacity ? magCapacity : mag + (magCapacity - oldCapacity))
        reserve = Swift.min(reserveCapacity, reserve + (reserveCapacity - oldReserve))
    }

    public mutating func refillReserve() {
        reserve = reserveCapacity
    }
}

public enum WeaponTable {
    public static let all: [String: WeaponDef] = {
        let list: [WeaponDef] = [
            WeaponDef(id: "m1911", name: "M1911", upgradedName: "Mustang & Sally",
                      damage: 40, headshotMultiplier: 2.0, rpm: 420, magSize: 8, reserveMax: 80, reloadTime: 1.6,
                      spread: 0.012, isAutomatic: false),
            WeaponDef(id: "olympia", name: "Olympia", upgradedName: "Hades",
                      damage: 110, headshotMultiplier: 1.5, rpm: 180, magSize: 2, reserveMax: 38, reloadTime: 2.1,
                      spread: 0.06, isAutomatic: false, pellets: 8, wallCost: 500),
            WeaponDef(id: "m14", name: "M14", upgradedName: "Mnesia",
                      damage: 120, headshotMultiplier: 2.0, rpm: 320, magSize: 8, reserveMax: 96, reloadTime: 2.0,
                      spread: 0.008, isAutomatic: false, wallCost: 500),
            WeaponDef(id: "mp40", name: "MP40", upgradedName: "The Afterburner",
                      damage: 70, headshotMultiplier: 2.0, rpm: 620, magSize: 32, reserveMax: 192, reloadTime: 2.4,
                      spread: 0.022, isAutomatic: true, wallCost: 1000),
            WeaponDef(id: "mp5k", name: "MP5K", upgradedName: "MP115 Kollider",
                      damage: 65, headshotMultiplier: 2.0, rpm: 800, magSize: 30, reserveMax: 120, reloadTime: 2.2,
                      spread: 0.02, isAutomatic: true, wallCost: 1000),
            WeaponDef(id: "mpl", name: "MPL", upgradedName: "MPL-LF",
                      damage: 70, headshotMultiplier: 2.0, rpm: 700, magSize: 24, reserveMax: 120, reloadTime: 2.3,
                      spread: 0.021, isAutomatic: true, wallCost: 1000),
            WeaponDef(id: "ak74u", name: "AK74u", upgradedName: "AK74fu2",
                      damage: 85, headshotMultiplier: 2.0, rpm: 700, magSize: 20, reserveMax: 160, reloadTime: 2.4,
                      spread: 0.024, isAutomatic: true, wallCost: 1200),
            WeaponDef(id: "stakeout", name: "Stakeout", upgradedName: "Raise the Stakes",
                      damage: 140, headshotMultiplier: 1.5, rpm: 90, magSize: 6, reserveMax: 48, reloadTime: 3.0,
                      spread: 0.07, isAutomatic: false, pellets: 10, wallCost: 1500),
            WeaponDef(id: "famas", name: "FAMAS", upgradedName: "G16-GL35",
                      damage: 90, headshotMultiplier: 2.0, rpm: 750, magSize: 30, reserveMax: 180, reloadTime: 2.5,
                      spread: 0.02, isAutomatic: true, wallCost: 1500),
            WeaponDef(id: "galil", name: "Galil", upgradedName: "Lamentation",
                      damage: 110, headshotMultiplier: 2.0, rpm: 700, magSize: 35, reserveMax: 210, reloadTime: 2.6,
                      spread: 0.02, isAutomatic: true, wallCost: 1600),
            WeaponDef(id: "commando", name: "Commando", upgradedName: "Predator",
                      damage: 115, headshotMultiplier: 2.0, rpm: 700, magSize: 30, reserveMax: 180, reloadTime: 2.5,
                      spread: 0.018, isAutomatic: true, wallCost: 1500),
            WeaponDef(id: "rpk", name: "RPK", upgradedName: "Relentless",
                      damage: 125, headshotMultiplier: 2.0, rpm: 600, magSize: 100, reserveMax: 400, reloadTime: 4.0,
                      spread: 0.025, isAutomatic: true, wallCost: 1600),
            WeaponDef(id: "python", name: "Python", upgradedName: "Cobra",
                      damage: 300, headshotMultiplier: 2.0, rpm: 220, magSize: 6, reserveMax: 84, reloadTime: 3.2,
                      spread: 0.01, isAutomatic: false, wallCost: 1500),
            WeaponDef(id: "raygun", name: "Ray Gun", upgradedName: "Porter's X2 Ray Gun",
                      damage: 1000, headshotMultiplier: 1.5, rpm: 180, magSize: 20, reserveMax: 160, reloadTime: 3.2,
                      spread: 0.01, isAutomatic: false, isWonder: true),
            WeaponDef(id: "thundergun", name: "Thundergun", upgradedName: "Zeus Cannon",
                      damage: 2000, headshotMultiplier: 1.5, rpm: 60, magSize: 2, reserveMax: 12, reloadTime: 3.5,
                      spread: 0.25, isAutomatic: false, pellets: 12, isWonder: true)
        ]
        var map: [String: WeaponDef] = [:]
        for w in list { map[w.id] = w }
        return map
    }()

    public static func def(_ id: String) -> WeaponDef {
        all[id] ?? WeaponTable.all["m1911"]!
    }

    public static let startingWeapon = "m1911"
}
