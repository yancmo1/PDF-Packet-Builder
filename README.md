# PDF Packet Sender

A powerful iOS app for creating and sending personalized PDF documents to multiple recipients. Perfect for certificates, invitations, contracts, or any document that needs to be customized for each recipient.

## Features

### Core Functionality
- **PDF Template Import**: Import any PDF form as a template
- **Smart Field Mapping**: Automatically detect PDF form fields and map them to recipient data
- **Multiple Recipient Sources**:
  - Import from iOS Contacts
  - Import from CSV files
  - Add recipients manually
- **1:1 PDF Generation**: Create personalized PDFs for each recipient
- **Share & Send**: Share PDFs individually via iOS share sheet
- **Send Logging**: Track all sent PDFs with timestamps and recipient details

### Data Management
- **Offline First**: All data stored locally, works without internet
- **Export Options**:
  - Export send logs as CSV
  - Export generated PDFs
- **Persistent Storage**: All data saved using UserDefaults and local file system

### In-App Purchases
- **Full App Purchase**: One-time purchase to unlock the app
- **Pro Features**: Optional upgrade for advanced features
- **Restore Purchases**: Easy restoration across devices

## Technical Stack

- **Platform**: iOS 16.0+
- **Framework**: SwiftUI
- **PDF Processing**: PDFKit
- **Contacts Integration**: Contacts framework
- **Payments**: StoreKit 2
- **Storage**: UserDefaults + FileManager

## Project Structure

```
PDFPacketSender/
├── PDFPacketSenderApp.swift       # App entry point
├── Models/
│   ├── AppState.swift             # Central state management
│   ├── PDFTemplate.swift          # PDF template model
│   ├── Recipient.swift            # Recipient data model
│   └── SendLog.swift              # Send log model
├── Views/
│   ├── ContentView.swift          # Main tab view
│   ├── TemplateView.swift         # PDF template management
│   ├── FieldMappingView.swift     # Field mapping interface
│   ├── RecipientsView.swift       # Recipients list
│   ├── ContactsPickerView.swift   # Contacts import
│   ├── CSVImporterView.swift      # CSV import
│   ├── ManualRecipientView.swift  # Manual recipient entry
│   ├── SendView.swift             # PDF generation & sending
│   ├── LogsView.swift             # Send logs
│   ├── SettingsView.swift         # Settings & IAP
│   └── PurchaseView.swift         # IAP purchase screen
├── Services/
│   ├── StorageService.swift       # Local data persistence
│   ├── PDFService.swift           # PDF processing
│   ├── ContactsService.swift      # Contacts access
│   └── CSVService.swift           # CSV parsing
├── IAP/
│   └── IAPManager.swift           # In-App Purchase logic
├── Utils/
│   ├── DocumentPicker.swift       # File picker wrapper
│   └── ShareSheet.swift           # Share sheet wrapper
└── Resources/
    ├── Info.plist                 # App configuration
    └── Assets.xcassets/           # App assets

```

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0+ device or simulator
- Apple Developer account (for device deployment and IAP)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yancmo1/PDF-Packet-Sender.git
   cd PDF-Packet-Sender
   ```

2. **Open in Xcode**
   ```bash
   open PDFPacketSender.xcodeproj
   ```

3. **Configure Bundle Identifier**
   - In Xcode, select the PDFPacketSender target
   - Change the Bundle Identifier to your own (e.g., `com.yourcompany.pdfpacketsender`)

4. **Configure In-App Purchases**
   - Update product IDs in `IAPManager.swift`:
     ```swift
     static let fullAppProductID = "com.yourcompany.pdfpacketsender.fullapp"
     static let proFeaturesProductID = "com.yourcompany.pdfpacketsender.pro"
     ```
   - Set up products in App Store Connect with matching IDs

5. **Configure Entitlements**
   - Update merchant ID in `PDFPacketSender.entitlements` if needed

6. **Build and Run**
   - Select your target device or simulator
   - Press Cmd+R to build and run

## Usage Guide

### 1. Import PDF Template
- Tap the **Template** tab
- Tap **Import PDF Template**
- Select a PDF file with form fields
- The app will automatically detect all form fields

### 2. Map Fields
- Tap **Edit Field Mappings**
- Map each PDF field to recipient properties (FirstName, LastName, Email, etc.)
- Tap **Save**

### 3. Add Recipients
- Tap the **Recipients** tab
- Choose one of three options:
  - **Import from Contacts**: Select contacts with email addresses
  - **Import from CSV**: Upload a CSV file (columns: FirstName, LastName, Email, Phone)
  - **Add Manually**: Enter recipient details manually

### 4. Generate & Send PDFs
- Tap the **Send** tab
- Tap **Generate PDFs** to create personalized PDFs for all recipients
- Tap the share icon next to each recipient to share their PDF
- PDFs are saved locally and can be shared via Mail, Messages, AirDrop, etc.

### 5. View Logs
- Tap the **Logs** tab to see all sent PDFs
- Export logs as CSV for record-keeping
- Clear individual or all logs as needed

### 6. Settings & Purchases
- Tap the **Settings** tab
- View app status and data statistics
- Purchase full app or Pro features
- Restore previous purchases

## CSV Format

For CSV import, use this format:

```csv
FirstName,LastName,Email,Phone
John,Doe,john.doe@example.com,555-1234
Jane,Smith,jane.smith@example.com,555-5678
```

- **Required**: Email
- **Optional**: FirstName, LastName, Phone
- Additional columns will be stored as custom fields and can be mapped to PDF fields

## Privacy & Data

- All data is stored locally on the device
- No data is sent to external servers
- Contacts are only accessed with user permission
- PDFs are generated and stored in the app's document directory

## In-App Purchase Configuration

### App Store Connect Setup

1. Create two In-App Purchase products:
   - **Full App** (Non-Consumable): One-time purchase to unlock the app
   - **Pro Features** (Non-Consumable): Optional upgrade for advanced features

2. Set pricing and metadata for each product

3. Submit for review with your app

### Testing IAP in Development

- Use Sandbox testing accounts from App Store Connect
- Test purchases in the StoreKit Configuration file (optional)

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Build Configurations

### Debug
- Default configuration for development
- Includes debug symbols

### Release
- Optimized for App Store submission
- Code signing required

## Future Enhancements

- [ ] Support for multiple templates
- [ ] PDF preview before sending
- [ ] Batch email sending
- [ ] Cloud sync (iCloud)
- [ ] Custom field types
- [ ] PDF encryption
- [ ] Template library
- [ ] Analytics dashboard

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is available for personal and commercial use.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

## Acknowledgments

Built with SwiftUI, PDFKit, and StoreKit 2.

---

**Note**: This app requires proper App Store Connect configuration for In-App Purchases to work in production. Update the product IDs and bundle identifier before submitting to the App Store.