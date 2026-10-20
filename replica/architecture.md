# Architecture: BO1 Zombies iOS Launcher (rebuild of Call of Duty: Black Ops Zombies core features)

## Stack

| layer | choice | why |
| --- | --- | --- |
| app shell | SwiftUI (iOS 17+) | native UI, document picker, settings, lifecycle |
| game engine | C++20 + Metal renderer | native code allowed on iOS; no JIT; performance |
| asset parsers | C++ (zlib, custom T5 fastfile, minizip for .iwd) | read owned Steam files without private APIs |
| local data | SQLite (via GRDB.swift) | offline-first profiles, saves, manifests |
| file access | iOS document picker + security-scoped bookmarks | sandbox-compliant import of large game folders |
| rendering | Metal (PBR-lite, forward) | iOS GPU API; no OpenGL ES deprecation issues |
| audio | AVAudioEngine + OpenAL-style mixer | positional 3D audio for zombies |
| input | UIKit touch + GameController (optional) | virtual sticks + MFi controllers |
| build | Xcode + Swift Package Manager + CMake (engine) | standard iOS toolchain |
| testing | XCTest + engine unit tests | verify parsers and gameplay math |

No backend, no microservices, no auth, no payments: the clone runs fully offline and only reads files the user already owns.

## Schema

Tables: 6. Access rules: single-user device; data-layer checks in Swift/C++ (no network).

See `replica/schema.sql`.

## API

Internal services (no HTTP). Listed as `service::method`.

| method | does | who | input | output | flow |
| --- | --- | --- | --- | --- | --- |
| InstallationService::importFolder | copy/bookmark game files | user | URL | Installation | F01 |
| InstallationService::verify | hash/size check vs manifest | user | installationId | VerifyResult | F02 |
| LaunchService::launchMap | load map + start engine | user | mapId, profileId | Session | F03 |
| SaveService::recordRun | store best round/score | engine | SessionResult | SaveData | F06 |
| ProfileService::load/update | read/write settings | user | Profile | Profile | F07 |
| AssetService::resolve | find file by logical name | engine | assetKey | URL/bytes | F03-F04 |

Webhooks in: none. Webhooks out: none.
Jobs: none (all on-device). Optional: background asset indexing on import (BGTaskScheduler).

## The parts that bite

- time zones: not applicable (offline); only local device time.
- idempotency: file import must be resumable; verification re-runnable.
- races: asset loading vs render thread; use serial loader + fence.
- rate limits: none (offline).
- file size limits: iOS app sandbox storage; 100GB+ game files may not fit; stream from Files without full copy where possible.
- search: local only.
- realtime: none (offline solo first).
- offline: core design; no network required after import.
- memory: mobile RAM limits; stream textures, unload unused zones.
- legal: must not ship Activision assets; user owns and imports; display ownership attestation.
- iOS restrictions: no JIT; engine must be fully AOT-compiled C++.

## Build order

1. Vertical slice: S01, S02, S03, S06 (minimal), S08 (empty scene), S09 (one zombie, one weapon), S10, S11 — tables: installations, files, profiles — services: import, verify, launch, save.
2. Must-haves: S07, full Kino map, perks, PaP, power, doors, HUD polish.
3. Should-haves: S04 settings, S12 stats, power-ups, pause polish.
4. Could-haves: S13 mods, hellhounds, mystery box, gamepad support.
5. Fixes from replica-entrepreneur: performance, controls, accessibility.