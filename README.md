# BO1 Zombies iOS Launcher (clean-room reimplementation)

Vertical slice project: an iOS launcher + native source-port engine that reads a
legally owned copy of Call of Duty: Black Ops (Steam) and runs Kino der Toten
Zombies on iPhone. No Activision assets are shipped; the user imports their own
files.

## Status

- Recon, architecture, design tokens completed under `replica/`.
- Engine core: file-manifest verification implemented and tested (`engine/`).
- iOS app shell: SwiftUI views scaffolded (`app/`), not yet wired to engine.

## Legal

You must own Call of Duty: Black Ops on Steam. This project does not include or
distribute any game assets, trademarks, or copyrighted content. Clean-room
reimplementation of functionality/UX only.

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