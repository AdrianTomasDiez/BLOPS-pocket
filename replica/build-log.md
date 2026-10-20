# Build log

- 2026-10-21 S01 HomeView: partial — status card, buttons; navigation not wired.
- 2026-10-21 S02 ImportView: partial — fileImporter stub.
- 2026-10-21 S03 VerifyView: partial — progress UI only.
- 2026-10-21 S04 SettingsView: partial — controls UI.
- 2026-10-21 S06/S07/S08/S09/S10/S11: partial — placeholders.
- 2026-10-21 Engine: manifest verification logic implemented and tested (C++).
## 2026-10-21 real engine work
- zone.cpp: T5 container verified on retail files (magic IWffu100, version 473, zlib body).
- iwd.cpp: ZIP central-directory reader, entry inflate + CRC check. iw_00.iwd: 1221 entries.
- sha256.cpp: hashing for manifests, tested against FIPS vectors.
- scan.cpp: finds 44 .iwd + 143 .ff in the retail install; manifest in 32s for ~7 GB.
- miniz vendored: no external zlib, builds on Windows/Linux/macOS/iOS.
- CI: Engine (3 OS) + iOS IPA both green.
