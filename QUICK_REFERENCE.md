# Quick Reference - PDF Packet Sender

## 🚀 Quick Start

### For Users
1. Import PDF template → Template tab
2. Map fields → Edit Field Mappings
3. Add recipients → Recipients tab
4. Generate PDFs → Send tab
5. Share individually → Tap share icon
6. View history → Logs tab

### For Developers
1. Create Xcode project (iOS App, SwiftUI)
2. Add all files from `PDFPacketSender/` folder
3. Update bundle identifier
4. Configure IAP products (see SETUP.md)
5. Build & run

## 📱 Main Features

| Feature | Location | Action |
|---------|----------|--------|
| Import PDF | Template Tab | Tap "Import PDF Template" |
| Map Fields | Template Tab | Tap "Edit Field Mappings" |
| Add Contacts | Recipients Tab | Menu → Import from Contacts |
| Import CSV | Recipients Tab | Menu → Import from CSV |
| Add Manual | Recipients Tab | Menu → Add Manually |
| Generate PDFs | Send Tab | Tap "Generate PDFs" |
| Share PDF | Send Tab | Tap share icon per recipient |
| Export Logs | Logs Tab | Menu → Export as CSV |
| Purchase | Settings Tab | View Available Purchases |
| Restore IAP | Settings Tab | Restore Purchases |

## 💻 Key Code Locations

### Models
```swift
AppState.swift       // Central app state
PDFTemplate.swift    // Template & fields
Recipient.swift      // Recipient data
SendLog.swift        // Send audit log
```

### Services
```swift
StorageService.swift   // Save/load data
PDFService.swift       // PDF operations
ContactsService.swift  // iOS Contacts
CSVService.swift       // CSV parsing
```

### Main Views
```swift
ContentView.swift      // Tab navigation
TemplateView.swift     // PDF import
RecipientsView.swift   // Recipients list
SendView.swift         // Generate & send
LogsView.swift         // Send history
SettingsView.swift     // IAP & settings
```

## 🔧 Common Tasks

### Add a New View
```swift
// 1. Create View file
struct NewView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        Text("New View")
    }
}

// 2. Add to navigation (ContentView.swift)
NewView()
    .tabItem {
        Label("New", systemImage: "icon")
    }
    .tag(5)
```

### Access App State
```swift
// In any view:
@EnvironmentObject var appState: AppState

// Then use:
appState.pdfTemplate
appState.recipients
appState.sendLogs
```

### Save Data
```swift
// Update state (auto-saves):
appState.saveTemplate(template)
appState.saveRecipients(recipients)
appState.addSendLog(log)
```

### Generate PDF
```swift
let pdfService = PDFService()
if let pdfData = pdfService.generatePersonalizedPDF(
    template: template,
    recipient: recipient
) {
    // Use pdfData
}
```

## 🎨 UI Patterns

### Empty State
```swift
VStack(spacing: 20) {
    Image(systemName: "icon")
        .font(.system(size: 80))
        .foregroundColor(.gray)
    Text("Title")
        .font(.title2)
        .fontWeight(.semibold)
    Text("Description")
        .foregroundColor(.secondary)
}
```

### List Item
```swift
HStack {
    VStack(alignment: .leading) {
        Text("Title")
            .fontWeight(.semibold)
        Text("Subtitle")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    Spacer()
    Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.blue)
}
```

### Action Button
```swift
Button(action: { /* action */ }) {
    Label("Title", systemImage: "icon")
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
}
```

## 📊 Data Flow

```
View → AppState → Service → Storage
 ↑                                ↓
 └────────── Update ──────────────┘
```

## 🔐 Permissions

| Permission | Usage | Key |
|------------|-------|-----|
| Contacts | Import recipients | NSContactsUsageDescription |
| Files | Import PDF/CSV | UISupportsDocumentBrowser |

## 💰 IAP Product IDs

```swift
// Update these in IAPManager.swift:
static let fullAppProductID = "com.yourcompany.pdfpacketsender.fullapp"
static let proFeaturesProductID = "com.yourcompany.pdfpacketsender.pro"

// Match in App Store Connect
```

## 🐛 Debugging

### Console Logs
```swift
print("🐛 [DEBUG] Message")
print("📊 [INFO] Message")
print("❌ [ERROR] Message")
```

### Check Storage
```bash
# View UserDefaults
defaults read com.yourcompany.pdfpacketsender
```

### Common Issues
| Issue | Solution |
|-------|----------|
| Fields not detected | PDF must have form fields |
| Contacts empty | Check permission in Settings |
| IAP not loading | Check product IDs match |
| Data not saving | Check Codable implementation |

## 📝 File Naming

- Views: `*View.swift` (e.g., `TemplateView.swift`)
- Models: Noun (e.g., `Recipient.swift`)
- Services: `*Service.swift` (e.g., `PDFService.swift`)
- Utils: Descriptive (e.g., `DocumentPicker.swift`)

## 🏗️ Architecture

```
View Layer (SwiftUI)
    ↓
State Layer (AppState)
    ↓
Service Layer (Business Logic)
    ↓
Storage Layer (UserDefaults/Files)
```

## 🚦 Build & Run

### Simulator
```
Cmd + R          // Build & run
Cmd + .          // Stop
Cmd + Shift + K  // Clean build
```

### Device
1. Connect device
2. Select in Xcode
3. Trust computer on device
4. Build & run

## 📦 Export/Share

### Export Logs as CSV
```swift
let csv = appState.exportLogsAsCSV()
// Save to temp file
// Share via ShareSheet
```

### Share PDF
```swift
let url = storageService.savePDFToDocuments(data: pdfData, filename: name)
ShareSheet(items: [url])
```

## 🔄 State Updates

### Pattern
```swift
// 1. User action
button.onTap {
    // 2. Update state
    appState.saveTemplate(newTemplate)
}

// 3. AppState publishes change
@Published var pdfTemplate: PDFTemplate?

// 4. View auto-updates
if let template = appState.pdfTemplate {
    Text(template.name)
}
```

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| README.md | Overview & features |
| SETUP.md | Setup instructions |
| ARCHITECTURE.md | Technical details |
| DEVELOPER_GUIDE.md | Development guide |
| CONTRIBUTING.md | Contribution guidelines |
| FLOW_DIAGRAM.md | Visual flows |
| QUICK_REFERENCE.md | This file |

## 🎯 Next Steps

### Phase 1 (Current) ✅
- Complete app scaffolding
- All features implemented
- Documentation complete

### Phase 2 (Future)
- [ ] Add unit tests
- [ ] Add UI tests
- [ ] Performance optimization
- [ ] Additional PDF features
- [ ] Cloud sync (iCloud)

## 💡 Pro Tips

1. **Use SwiftUI Previews** for fast iteration
2. **Test on real device** for Contacts & IAP
3. **Keep files organized** by feature
4. **Document complex logic** with comments
5. **Use background threads** for heavy work
6. **Show progress indicators** for long tasks
7. **Handle errors gracefully** with alerts
8. **Test with various PDFs** to ensure compatibility

## 🔗 Useful Links

- [SwiftUI Docs](https://developer.apple.com/documentation/swiftui)
- [PDFKit Docs](https://developer.apple.com/documentation/pdfkit)
- [StoreKit 2 Docs](https://developer.apple.com/documentation/storekit)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

## 📞 Get Help

1. Check this quick reference
2. Read detailed documentation
3. Search existing issues
4. Open new issue on GitHub
5. Include error messages and steps to reproduce

---

**Keep this handy while developing! 📌**
