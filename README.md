# BO1 Zombies iOS Launcher (clean-room reimplementation)

Vertical slice project: an iOS launcher + native source-port engine that reads a
legally owned copy of Call of Duty: Black Ops (Steam) and runs Kino der Toten
Zombies on iPhone. No Activision assets are shipped; the user imports their own
files.

## Status

- Recon, architecture, design tokens completed under `replica/`.
- Engine core: file-manifest verification implemented and tested (`engine/`).
- iOS app shell: SwiftUI views scaffolded (`app/`), not yet wired to engine.

## Game files (your copy)

On Windows (Steam), the game folder is usually:

```
C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops
```

The app does not download or ship any game files. You import that folder from your PC/iPhone storage. The iOS app only reads files you own.

## Build engine (Windows/dev)

```
cd engine
cmake -S . -B build -G Ninja
ninja -C build
ctest --test-dir build
```

## iOS app

Open `app/` in Xcode (project file to be generated). Requires Apple Developer
account and iOS 17+. Metal renderer and asset parsers are TODO.

## Next steps

- Generate Xcode project and wire SwiftUI to engine via C++ interop.
- Implement T5 fastfile + .iwd parsers.
- Implement Metal renderer and touch controls.
- Run `/replica-test` for end-to-end QA.