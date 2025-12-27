# PDF Packet Sender - Developer Guide

## Quick Start for Developers

### Opening the Project

Since this is a SwiftUI-based iOS project, you need to create an Xcode project:

1. **Option A: Create New Xcode Project (Recommended)**
   ```bash
   # Open Xcode
   # File → New → Project
   # Choose: iOS → App
   # Configure:
   #   - Product Name: PDFPacketSender
   #   - Interface: SwiftUI
   #   - Language: Swift
   # Save in this directory
   # Add all PDFPacketSender source files to the project
   ```

2. **Option B: Use Command Line**
   ```bash
   # This will create a basic Xcode project structure
   cd /path/to/PDF-Packet-Sender
   
   # Then open in Xcode and add source files
   ```

### Project Configuration

**Bundle Identifier**: `com.yourcompany.pdfpacketsender`

**Minimum iOS Version**: 16.0

**Required Capabilities**:
- Contacts access
- In-App Purchase
- File sharing

## Code Organization

### Models Layer
Pure data structures, Codable for persistence:
- `AppState.swift` - Central state (@ObservableObject)
- `PDFTemplate.swift` - PDF template with fields
- `Recipient.swift` - Recipient data model
- `SendLog.swift` - Send audit log

### Services Layer
Business logic and external integrations:
- `StorageService.swift` - Local persistence
- `PDFService.swift` - PDF manipulation
- `ContactsService.swift` - iOS Contacts
- `CSVService.swift` - CSV parsing

### Views Layer
SwiftUI views organized by feature:
- `ContentView.swift` - Main navigation
- Template feature: `TemplateView`, `FieldMappingView`
- Recipients feature: `RecipientsView`, `ContactsPickerView`, `CSVImporterView`, `ManualRecipientView`
- Send feature: `SendView`
- Logs feature: `LogsView`
- Settings feature: `SettingsView`, `PurchaseView`

### Utils Layer
Reusable components:
- `DocumentPicker.swift` - UIKit wrapper
- `ShareSheet.swift` - UIKit wrapper

## Key Flows

### 1. PDF Import Flow
```
User taps "Import PDF"
  → DocumentPicker shows
  → User selects PDF
  → PDFService.extractFields(from: data)
  → Create PDFTemplate with fields
  → AppState.saveTemplate()
  → StorageService persists to UserDefaults
```

### 2. Field Mapping Flow
```
User taps "Edit Field Mappings"
  → FieldMappingView shows
  → Display all PDF fields
  → User maps field → recipient property
  → Save mappings to template
  → AppState.saveTemplate()
```

### 3. Contact Import Flow
```
User taps "Import from Contacts"
  → ContactsPickerView shows
  → Check permission
  → Request if needed
  → ContactsService.fetchContacts()
  → Display contacts with emails
  → User selects contacts
  → Convert to Recipients
  → AppState.saveRecipients()
```

### 4. PDF Generation Flow
```
User taps "Generate PDFs"
  → For each recipient:
    - PDFService.generatePersonalizedPDF()
    - Fill fields based on mappings
    - Create PDF data
  → Store PDFs in array
  → Display with share buttons
```

### 5. Share Flow
```
User taps share button
  → Save PDF to documents directory
  → Create ShareSheet with URL
  → System share sheet appears
  → User shares via Mail/Messages/etc
  → Create SendLog
  → AppState.addSendLog()
```

## State Management

### AppState Pattern
```swift
@StateObject var appState = AppState()  // In App
@EnvironmentObject var appState: AppState  // In Views

// Views react to changes:
appState.pdfTemplate  // Triggers UI update when changed
appState.recipients   // Triggers UI update when changed
appState.sendLogs     // Triggers UI update when changed
```

### Data Flow
```
View modification
  ↓
AppState method call
  ↓
Service method call
  ↓
Storage update
  ↓
@Published property update
  ↓
View re-renders
```

## Adding New Features

### Add a New Recipient Source

1. Create service:
```swift
class NewSourceService {
    func fetchRecipients() async -> [Recipient] {
        // Implementation
    }
}
```

2. Create view:
```swift
struct NewSourcePickerView: View {
    @EnvironmentObject var appState: AppState
    @State private var recipients: [Recipient] = []
    
    var body: some View {
        // UI
    }
}
```

3. Add to RecipientsView:
```swift
Button(action: { showingNewSource = true }) {
    Label("Import from New Source", systemImage: "...")
}
.sheet(isPresented: $showingNewSource) {
    NewSourcePickerView()
}
```

### Add a New Field Type

1. Update PDFField.FieldType:
```swift
enum FieldType: String, Codable {
    case text
    case number
    case date
    case checkbox
    case newType  // Add here
}
```

2. Update PDFService.determineFieldType():
```swift
private func determineFieldType(_ annotation: PDFAnnotation) -> PDFField.FieldType {
    // Add logic for new type
}
```

3. Update PDFService.generatePersonalizedPDF():
```swift
// Handle new type when filling fields
```

### Add a New Export Format

1. Update AppState:
```swift
func exportLogsAsJSON() -> String {
    // Implementation
}
```

2. Add button in LogsView:
```swift
Button(action: exportAsJSON) {
    Label("Export as JSON", systemImage: "doc.text")
}
```

## Testing

### Manual Testing Checklist

**PDF Import**:
- [ ] Import PDF with form fields
- [ ] Import PDF without form fields
- [ ] Import large PDF (>5MB)
- [ ] Import password-protected PDF

**Field Mapping**:
- [ ] Map all field types
- [ ] Save and verify persistence
- [ ] Unmapped fields remain empty

**Recipients**:
- [ ] Import from Contacts
- [ ] Import from CSV (various formats)
- [ ] Add manually
- [ ] Delete recipients
- [ ] Clear all recipients

**PDF Generation**:
- [ ] Generate for single recipient
- [ ] Generate for multiple recipients
- [ ] Verify field values correct
- [ ] Large recipient list (100+)

**Sharing**:
- [ ] Share via Mail
- [ ] Share via Messages
- [ ] Share via AirDrop
- [ ] Save to Files app

**Logs**:
- [ ] Log created on share
- [ ] Export logs as CSV
- [ ] Delete individual log
- [ ] Clear all logs

**IAP**:
- [ ] Load products
- [ ] Purchase Full App
- [ ] Purchase Pro Features
- [ ] Restore purchases
- [ ] Sandbox testing

### Unit Testing (To Implement)

```swift
// Example test structure
import XCTest
@testable import PDFPacketSender

class CSVServiceTests: XCTestCase {
    func testParseSimpleCSV() {
        let csv = "FirstName,LastName,Email\nJohn,Doe,john@example.com"
        let recipients = CSVService().parseCSV(data: csv)
        XCTAssertEqual(recipients.count, 1)
        XCTAssertEqual(recipients[0].firstName, "John")
    }
}
```

## Performance Considerations

### Memory
- PDFs loaded on demand, not kept in memory
- Large recipient lists may use significant memory
- Consider implementing pagination for 1000+ recipients

### Processing
- PDF generation is CPU-intensive
- Currently done on background thread
- Progress indicator shown during generation

### Storage
- UserDefaults limited to ~1MB
- Consider Core Data for 10,000+ recipients
- Consider CloudKit for sync

## Common Development Tasks

### Change App Icon
1. Create 1024x1024 PNG
2. Add to `Assets.xcassets/AppIcon.appiconset/`
3. Update Contents.json

### Add New Tab
1. Create new View file
2. Add to ContentView TabView:
```swift
NewView()
    .tabItem {
        Label("New", systemImage: "icon.name")
    }
    .tag(4)
```

### Change Color Scheme
1. Add to Assets.xcassets:
   - Create Color Set
   - Define light/dark variants
2. Use in code:
```swift
.background(Color("CustomColor"))
```

### Add Localization
1. Create Localizable.strings
2. Add languages in project settings
3. Replace strings:
```swift
Text("Hello")  →  Text(NSLocalizedString("greeting", comment: ""))
```

## Debugging

### Common Issues

**PDF fields not detected**:
- Check PDF has actual form fields (not just text)
- Use Preview.app to verify fields
- Check PDFKit can read the PDF

**Contacts not loading**:
- Verify Info.plist has usage description
- Check permission granted in Settings
- Reset simulator if needed

**IAP not working**:
- Check product IDs match App Store Connect
- Ensure signed in to sandbox account
- Check products are "Ready to Submit"

**Data not persisting**:
- Check UserDefaults.standard being used
- Verify Codable implementation
- Check for encoding/decoding errors

### Debug Logging

Add throughout code:
```swift
print("🐛 [DEBUG] PDF imported: \(template.name)")
print("📊 [INFO] Recipients loaded: \(recipients.count)")
print("❌ [ERROR] Failed to parse CSV: \(error)")
```

Use emoji for easy filtering in console.

## Performance Profiling

### Instruments
- Time Profiler: Find slow code
- Allocations: Memory usage
- Leaks: Memory leaks

### SwiftUI View Debugging
```swift
let _ = Self._printChanges()  // In view body
```

## Git Workflow

### Branch Strategy
```
main - Production ready
develop - Integration branch
feature/* - New features
fix/* - Bug fixes
```

### Commit Messages
```
feat: Add PDF encryption
fix: Correct CSV parsing for quoted fields
docs: Update README with new features
refactor: Simplify PDFService
test: Add CSVService tests
```

## Deployment

### TestFlight
1. Archive in Xcode
2. Upload to App Store Connect
3. Add to TestFlight
4. Invite testers

### App Store
1. Create app in App Store Connect
2. Add metadata, screenshots
3. Configure IAP products
4. Submit for review

## Resources

### Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [PDFKit Documentation](https://developer.apple.com/documentation/pdfkit)
- [StoreKit 2 Guide](https://developer.apple.com/documentation/storekit)

### Tools
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Icons
- [Xcode](https://developer.apple.com/xcode/) - IDE
- [RocketSim](https://www.rocketsim.app/) - Simulator enhancement

### Community
- [Swift Forums](https://forums.swift.org)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/swiftui)
- [Hacking with Swift](https://www.hackingwithswift.com)

## Maintenance

### Regular Tasks
- [ ] Update to latest iOS version
- [ ] Test with new Xcode
- [ ] Update dependencies
- [ ] Review crash reports
- [ ] Respond to user feedback

### Security
- [ ] Review IAP implementation
- [ ] Check for data leaks
- [ ] Update privacy policy
- [ ] Audit third-party code (if any)

## Support

For questions or issues:
1. Check ARCHITECTURE.md
2. Check SETUP.md
3. Review this guide
4. Open GitHub issue
5. Contact maintainers

---

**Happy Coding! 🚀**
