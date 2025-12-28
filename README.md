# PDF Packet Builder

iOS app for filling PDF forms with recipient data from CSV files.

## What it does

Import a PDF form, import a CSV file with recipient data, map the fields, and generate filled PDFs for each recipient.

## v1 Features

- Import fillable PDF templates (AcroForm text fields)
- Import recipient data from CSV
- Map CSV columns to PDF fields
- Generate one PDF per recipient
- Share generated PDFs
- Log generation history

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Fillable PDFs with AcroForm fields

## Build

1. Clone the repository
2. Open `PDFPacketBuilder.xcodeproj` in Xcode
3. Update Bundle Identifier to your own: `com.yancmo.pdfpacketbuilder`
4. Update IAP product IDs in `IAPManager.swift`
5. Build and run

## Fastlane (TestFlight / App Store)

This repo is set up to run Fastlane via Bundler for reproducible builds.

- Config lives in `fastlane/Fastfile` and `fastlane/Appfile`
- VS Code tasks live in `.vscode/tasks.json`

### App Store Connect authentication

Preferred: App Store Connect API key via env vars. Apple ID auth is supported as a fallback.

- Copy `.env.example` → `.env` (local only) **or** copy `.envrc.example` → `.envrc` (direnv)
- Set:
	- `ASC_KEY_ID`
	- `ASC_ISSUER_ID`
	- `ASC_KEY_PATH` (absolute path to your `.p8`)

The `.p8` key should live outside the repo (for example under `$HOME/.appstoreconnect/private_keys/`).

Fallback (Apple ID): set `FASTLANE_USER` and `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` (or `FASTLANE_SESSION`).

## Free Plan Limits

- 1 template max
- 10 recipients per batch
- 7-day log retention

Unlock Pro removes all limits.

## CSV Format

```csv
FirstName,LastName,Email
John,Doe,john@example.com
Jane,Smith,jane@example.com
```

Map any columns to PDF fields. Email is optional.

## License

See LICENSE file.
