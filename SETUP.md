# PDF Packet Sender - Setup Guide

This document provides detailed instructions for setting up and running the PDF Packet Sender iOS app.

## Quick Start

Since this is a pure SwiftUI project, you can create an Xcode project easily:

### Method 1: Create Xcode Project (Recommended)

1. **Open Xcode**
2. **File → New → Project**
3. Choose **iOS → App**
4. Set:
   - Product Name: `PDFPacketSender`
   - Team: Your team
   - Organization Identifier: `com.yourcompany`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we use UserDefaults)
   - Include Tests: Optional
5. **Save to this directory** (replace the created files with our files)
6. **Add all source files to the project**:
   - Drag the `PDFPacketSender` folder into Xcode
   - Ensure "Copy items if needed" is unchecked
   - Ensure "Create groups" is selected
   - Add to targets: PDFPacketSender

### Method 2: Use Swift Package Manager

This project includes a `Package.swift` file that can be used with Xcode:

1. Open the repository folder in Xcode: **File → Open**
2. Select `Package.swift`
3. Xcode will recognize it as a Swift Package
4. Build and run (note: you'll need to create an app target)

## Configuration Steps

### 1. Bundle Identifier

Update the bundle identifier throughout the project:
- In Xcode: Target → General → Bundle Identifier
- Change from `com.yourcompany.pdfpacketsender` to your identifier
- Update in `IAPManager.swift` for product IDs

### 2. Signing & Capabilities

Add required capabilities:
- **Contacts**: Automatically added (permission in Info.plist)
- **In-App Purchase**: Add in Signing & Capabilities
- Optional: **iCloud** if you want cloud sync in future

### 3. In-App Purchase Setup

#### In Code (IAPManager.swift):
```swift
static let fullAppProductID = "com.yourcompany.pdfpacketsender.fullapp"
static let proFeaturesProductID = "com.yourcompany.pdfpacketsender.pro"
```

#### In App Store Connect:
1. Create your app
2. Go to **Features → In-App Purchases**
3. Create two products:
   - **Full App** (Non-Consumable)
     - Product ID: `com.yourcompany.pdfpacketsender.fullapp`
     - Reference Name: "Full App"
     - Price: Your choice (e.g., $4.99)
   - **Pro Features** (Non-Consumable)
     - Product ID: `com.yourcompany.pdfpacketsender.pro`
     - Reference Name: "Pro Features"
     - Price: Your choice (e.g., $9.99)
4. Submit products for review

### 4. Permissions Setup

Already configured in `Info.plist`:
- `NSContactsUsageDescription`: "We need access to your contacts to help you select recipients for PDF packets."
- `UISupportsDocumentBrowser`: true
- `UIFileSharingEnabled`: true

### 5. Assets

Add app icon:
1. Create app icon (1024x1024)
2. Add to `Assets.xcassets/AppIcon.appiconset`
3. Or use an app icon generator

## File Structure Verification

Ensure all these files are in the project:

```
✓ PDFPacketSender/
  ✓ PDFPacketSenderApp.swift
  ✓ Models/
    ✓ AppState.swift
    ✓ PDFTemplate.swift
    ✓ Recipient.swift
    ✓ SendLog.swift
  ✓ Views/
    ✓ ContentView.swift
    ✓ TemplateView.swift
    ✓ FieldMappingView.swift
    ✓ RecipientsView.swift
    ✓ ContactsPickerView.swift
    ✓ CSVImporterView.swift
    ✓ ManualRecipientView.swift
    ✓ SendView.swift
    ✓ LogsView.swift
    ✓ SettingsView.swift
    ✓ PurchaseView.swift
  ✓ Services/
    ✓ StorageService.swift
    ✓ PDFService.swift
    ✓ ContactsService.swift
    ✓ CSVService.swift
  ✓ IAP/
    ✓ IAPManager.swift
  ✓ Utils/
    ✓ DocumentPicker.swift
    ✓ ShareSheet.swift
  ✓ Resources/
    ✓ Info.plist
    ✓ Assets.xcassets/
    ✓ PDFPacketSender.entitlements
```

## Testing

### Simulator Testing

Most features work in the simulator:
- PDF import
- Field mapping
- Manual recipient entry
- CSV import
- PDF generation
- Logs

Note: IAP testing requires a real device.

### Device Testing

For full testing including IAP:
1. Connect iOS device
2. Select device as target
3. Enable **Developer Mode** on device (Settings → Privacy & Security)
4. Trust your computer
5. Build and run

### IAP Testing

1. **Create Sandbox Tester**:
   - App Store Connect → Users and Access → Sandbox Testers
   - Create test account

2. **Sign out of App Store** on test device:
   - Settings → App Store → Sign Out

3. **Test purchases**:
   - Run app
   - Attempt purchase
   - Sign in with sandbox account when prompted
   - Test purchase flow

4. **Test restore**:
   - Delete and reinstall app
   - Tap "Restore Purchases"
   - Verify purchases restored

## Common Issues & Solutions

### Issue: App won't build
**Solution**: Check that all files are added to the target

### Issue: Contacts access not working
**Solution**: Ensure `NSContactsUsageDescription` is in Info.plist

### Issue: IAP products not loading
**Solution**: 
- Check product IDs match App Store Connect
- Ensure products are "Ready to Submit" status
- Test with sandbox account

### Issue: PDF fields not detected
**Solution**: Ensure PDF has actual form fields (not just text)

### Issue: Can't import files
**Solution**: Check Info.plist has `UISupportsDocumentBrowser = true`

## Development Tips

### Hot Reload
- Use SwiftUI Previews for fast iteration
- Each view has a preview provider

### Debugging
- Use `print()` statements in services
- Check UserDefaults: `defaults read com.yourcompany.pdfpacketsender`

### Performance
- PDF generation happens on background thread
- Large recipient lists may take time
- Consider adding progress indicators

## Build for Release

1. **Archive**:
   - Product → Archive
   - Wait for build to complete

2. **Distribute**:
   - Window → Organizer
   - Select archive
   - Click "Distribute App"
   - Choose "App Store Connect"

3. **Submit for Review**:
   - Fill in app metadata in App Store Connect
   - Submit screenshots
   - Submit for review

## Next Steps

After setup:
1. ✅ Build and run in simulator
2. ✅ Test basic flows (import template, add recipients)
3. ✅ Test on device with real contacts
4. ✅ Set up IAP products
5. ✅ Test sandbox purchases
6. ✅ Create app icon and screenshots
7. ✅ Submit to App Store

## Support

For issues:
- Check this guide
- Review README.md
- Open GitHub issue
- Check Xcode console for errors

## Additional Resources

- [Apple StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [PDFKit Documentation](https://developer.apple.com/documentation/pdfkit)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Contacts Framework](https://developer.apple.com/documentation/contacts)

---

**Happy Coding! 🚀**
