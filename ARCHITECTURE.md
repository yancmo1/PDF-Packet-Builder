# PDF Packet Sender - Architecture Documentation

## Overview

PDF Packet Sender is built with a modern iOS architecture using SwiftUI, following MVVM patterns and offline-first principles.

## Architecture Principles

1. **Offline First**: All data stored locally, no network dependency
2. **Reactive**: SwiftUI with ObservableObject for state management
3. **Service-Oriented**: Separate services for distinct responsibilities
4. **Type-Safe**: Strong typing with Swift's type system
5. **Testable**: Separation of concerns enables unit testing

## Data Flow

```
User Interaction
    ↓
View (SwiftUI)
    ↓
AppState (ObservableObject)
    ↓
Service Layer
    ↓
Storage/System APIs
```

## Core Components

### 1. App State Management

**AppState.swift**
- Central source of truth for app data
- Uses `@Published` properties for reactive updates
- Coordinates between services and views
- Manages:
  - PDF template
  - Recipients list
  - Send logs
  - Pro status

### 2. Models

#### PDFTemplate
```swift
struct PDFTemplate {
    - id: UUID
    - name: String
    - pdfData: Data
    - fields: [PDFField]
    - fieldMappings: [String: String]
    - createdAt: Date
}
```
Represents the PDF template with detected form fields and their mappings to recipient properties.

#### Recipient
```swift
struct Recipient {
    - id: UUID
    - firstName: String
    - lastName: String
    - email: String
    - phoneNumber: String?
    - customFields: [String: String]
    - source: RecipientSource
}
```
Represents a recipient with standard fields plus custom fields from CSV.

#### SendLog
```swift
struct SendLog {
    - id: UUID
    - recipientName: String
    - recipientEmail: String
    - pdfName: String
    - timestamp: Date
    - status: String
    - notes: String?
}
```
Tracks each PDF send operation for audit purposes.

### 3. Services

#### StorageService
**Purpose**: Local data persistence
**Technology**: UserDefaults + FileManager
**Operations**:
- Save/load template
- Save/load recipients
- Save/load logs
- Save/load Pro status
- Save PDFs to documents directory

**Design Decision**: UserDefaults for simple data, FileManager for PDFs
- Pros: Simple, fast, no dependencies
- Cons: Size limits (but acceptable for this use case)
- Alternative considered: Core Data (rejected as overkill)

#### PDFService
**Purpose**: PDF manipulation and generation
**Technology**: PDFKit
**Operations**:
- Extract form fields from PDF
- Generate personalized PDFs
- Fill PDF form fields
- Flatten PDFs (optional)

**Key Algorithm**: Field Extraction
```swift
1. Load PDF document
2. Iterate through pages
3. Extract annotations (form fields)
4. Parse field names and types
5. Return structured PDFField array
```

**Key Algorithm**: PDF Personalization
```swift
1. Load template PDF
2. Create copy of document
3. For each page:
   a. Get annotations
   b. Match field names to mappings
   c. Get recipient value
   d. Set field value
4. Return modified PDF data
```

#### ContactsService
**Purpose**: iOS Contacts integration
**Technology**: Contacts framework
**Operations**:
- Request contacts permission
- Fetch contacts with email addresses
- Convert CNContact to Recipient

**Privacy**: Requires NSContactsUsageDescription in Info.plist

#### CSVService
**Purpose**: CSV file parsing
**Technology**: String manipulation
**Operations**:
- Parse CSV with headers
- Handle quoted values with commas
- Map columns to Recipient fields
- Support custom fields

**Parser Design**:
- Handles quoted fields: "Last, First"
- Flexible column mapping
- Case-insensitive header matching
- Graceful error handling

### 4. Views

#### Navigation Structure
```
TabView
├── TemplateView
│   └── FieldMappingView (sheet)
├── RecipientsView
│   ├── ContactsPickerView (sheet)
│   ├── CSVImporterView (sheet)
│   └── ManualRecipientView (sheet)
├── SendView
│   └── ShareSheet (sheet)
├── LogsView
│   └── ShareSheet (sheet)
└── SettingsView
    └── PurchaseView (sheet)
```

#### View Responsibilities

**ContentView**: Main navigation container with TabView

**TemplateView**: 
- Import PDF template
- Display template info
- Navigate to field mapping

**FieldMappingView**:
- Display PDF fields
- Map fields to recipient properties
- Save mappings

**RecipientsView**:
- Display recipients list
- Add/delete recipients
- Navigate to import options

**ContactsPickerView**:
- Request contacts permission
- Display contacts with emails
- Multi-select interface
- Import selected contacts

**CSVImporterView**:
- File picker for CSV
- Parse and preview recipients
- Import to recipients list

**ManualRecipientView**:
- Form for manual entry
- Validation
- Add single recipient

**SendView**:
- Display summary
- Generate PDFs for all recipients
- Individual share for each PDF
- Log each send

**LogsView**:
- Display send logs
- Export logs as CSV
- Clear logs

**SettingsView**:
- Display app status
- Show data statistics
- IAP purchase options
- Restore purchases

**PurchaseView**:
- Display available products
- Purchase flow
- Show purchase status

### 5. IAP (In-App Purchases)

**IAPManager.swift**
- Uses StoreKit 2 (modern async/await API)
- Manages two product types:
  1. Full App (one-time unlock)
  2. Pro Features (optional upgrade)

**Purchase Flow**:
```
1. Load products from App Store
2. Display products with prices
3. User initiates purchase
4. StoreKit handles payment
5. Verify transaction
6. Update purchased products
7. Save to storage
```

**Restore Flow**:
```
1. User taps "Restore"
2. Call AppStore.sync()
3. Fetch current entitlements
4. Update purchased products
5. Save to storage
```

**Transaction Listening**:
- Continuous listener for transaction updates
- Handles purchases from other devices
- Automatic verification

### 6. Utilities

**DocumentPicker**: UIViewControllerRepresentable wrapper for UIDocumentPickerViewController
- Supports multiple content types (PDF, CSV)
- Security-scoped resource handling

**ShareSheet**: UIViewControllerRepresentable wrapper for UIActivityViewController
- Share PDFs via system share sheet
- Supports Mail, Messages, AirDrop, etc.

## Data Persistence Strategy

### What's Stored Where

**UserDefaults**:
- Template metadata (JSON)
- Recipients array (JSON)
- Send logs (JSON)
- Pro status (Boolean)

**Documents Directory**:
- Template PDF data
- Generated PDFs

**Temporary Directory**:
- CSV exports (for sharing)

### Data Limits

- UserDefaults: ~1MB practical limit
- Assumed: Max 100 recipients * 1KB each = 100KB ✓
- Assumed: Max 1000 logs * 500 bytes = 500KB ✓
- Template PDF: Stored as Data in UserDefaults (should be <5MB)

### Backup Consideration

- UserDefaults: Backed up to iCloud
- Documents: Backed up to iCloud
- User data is preserved across devices

## Security Considerations

### Data Security
- All data stored locally on device
- No network transmission
- iOS sandbox protection
- Encrypted device backup

### IAP Security
- StoreKit 2 automatic verification
- Receipt validation on device
- No server-side validation needed for local-only app

### PDF Security
- No encryption implemented (future feature)
- PDFs stored in app sandbox
- Not accessible by other apps

## Performance Optimizations

### PDF Processing
- Background thread for PDF operations
- Progress indicators for long operations
- Lazy loading of PDFs

### UI Responsiveness
- Async/await for all heavy operations
- Main thread only for UI updates
- Efficient list rendering with SwiftUI

### Memory Management
- PDFs loaded on demand
- No caching of large PDF data in memory
- Rely on iOS memory management

## Testing Strategy

### Unit Testing (Future)
- Test models for Codable conformance
- Test services in isolation
- Mock storage for predictable tests

### UI Testing (Future)
- Test navigation flows
- Test form validation
- Test IAP flows with StoreKit testing

### Manual Testing
- Import various PDF formats
- Test with large recipient lists
- Test with various CSV formats
- Test IAP in sandbox

## Error Handling

### Strategy
- Graceful degradation
- User-friendly error messages
- Logging to console for debugging
- No crashes on invalid input

### Specific Cases
- Invalid PDF: Show error, don't import
- CSV parsing errors: Skip invalid rows
- Contacts permission denied: Show explanation
- IAP errors: Show error, allow retry

## Future Enhancements

### Phase 2 Features
1. **Multiple Templates**: Store array of templates
2. **PDF Preview**: Preview before sending
3. **Email Integration**: Send directly via email
4. **Cloud Sync**: iCloud sync for multi-device

### Phase 3 Features
1. **Template Library**: Pre-made templates
2. **Analytics**: Dashboard with statistics
3. **PDF Encryption**: Password-protected PDFs
4. **Batch Operations**: Send all at once

### Technical Debt
- Add comprehensive error handling
- Implement unit tests
- Add UI tests
- Optimize large list performance
- Add PDF caching layer

## Dependencies

### System Frameworks
- SwiftUI (UI)
- PDFKit (PDF processing)
- Contacts (Contact access)
- StoreKit (IAP)
- Foundation (Core utilities)

### Third-Party
- None! Pure iOS implementation

## Build Configuration

### Debug
- Swift compiler optimization: None
- Debug symbols: Yes
- Assertions: Enabled

### Release
- Swift compiler optimization: -O
- Debug symbols: No
- Assertions: Disabled
- Bitcode: No (deprecated)

## Localization

### Current
- English only
- All strings hardcoded

### Future
- Localize all user-facing strings
- Support multiple languages
- Use NSLocalizedString

## Accessibility

### Current Support
- Standard SwiftUI accessibility
- VoiceOver compatible
- Dynamic Type support

### Future Improvements
- Custom accessibility labels
- Improved VoiceOver hints
- Testing with real users

## App Store Submission

### Requirements
- Privacy Policy
- Terms of Service
- App Preview video (optional)
- Screenshots (required)
- App Description
- Keywords
- Support URL

### IAP Requirements
- IAP products approved
- Sandbox testing completed
- Restore functionality verified

## Maintenance

### Regular Updates
- iOS version compatibility
- Bug fixes
- Performance improvements
- New features

### Monitoring
- Crash reports (via Xcode)
- User reviews
- Feature requests

---

This architecture provides a solid foundation for a production-ready iOS app with room for future enhancements while maintaining simplicity and offline-first capabilities.
