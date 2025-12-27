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
