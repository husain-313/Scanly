# Scanly

A personal, free document scanner for iPhone & iPad — built from scratch in SwiftUI.
No account, no subscription, everything on-device.

## Features
- **Scan** — Apple VisionKit camera with automatic edge detection and perspective correction.
- **Multi-page** documents, add pages, delete, reorder.
- **Filters** — Original, Enhance, Grayscale, B&W (Core Image), plus rotate.
- **OCR** — extract selectable text (Arabic + English and more) with Vision.
- **PDF export** — share as PDF, optionally searchable (OCR text layer), or as images.
- **Library** — grid of documents, rename, search by title or recognized text.
- **Face ID lock** — optional app lock.

Native iOS look: standard SwiftUI components and SF Symbols throughout.

## Build
No Mac needed locally — the IPA is built in CI (GitHub Actions, macOS runner).

1. Push to GitHub.
2. The **Build IPA** workflow runs on every push to `main`.
3. Download `Scanly.ipa` from the latest release, then sideload (Sideloadly / AltStore) which re-signs it.

Local project generation (Mac only): `xcodegen generate && open Scanly.xcodeproj`.

## Privacy
Scans, filtering and OCR run entirely on your device. Nothing is uploaded.

## Roadmap
- ID-card / passport mode, batch scan.
- Signature & annotations.
- Folders and tags.
- iCloud backup, home-screen widgets.
