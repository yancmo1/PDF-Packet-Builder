# PDF Packet Sender - App Flow Diagram

## Main Navigation Structure

```
┌─────────────────────────────────────────────────────────┐
│                    PDF Packet Sender                     │
│                      (TabView)                           │
└─────────────────────────────────────────────────────────┘
                            │
      ┌─────────────────────┼─────────────────────┐
      │                     │                     │
      ▼                     ▼                     ▼
┌──────────┐         ┌──────────┐         ┌──────────┐
│ Template │         │Recipients│         │   Send   │
│   Tab    │         │   Tab    │         │   Tab    │
└──────────┘         └──────────┘         └──────────┘
      │                     │                     │
      ▼                     ▼                     ▼
┌──────────┐         ┌──────────┐         ┌──────────┐
│   Logs   │         │ Settings │         
│   Tab    │         │   Tab    │         
└──────────┘         └──────────┘         
```

## Feature Flow Diagrams

### 1. PDF Template Import & Mapping

```
Start
  │
  ├─> Import PDF Template
  │     ├─> Select PDF file
  │     ├─> Extract form fields (PDFKit)
  │     └─> Save template
  │
  └─> Map Fields
        ├─> View detected fields
        ├─> Select recipient property for each field
        │   (FirstName, LastName, Email, etc.)
        └─> Save mappings
```

### 2. Add Recipients (3 Sources)

```
Add Recipients
  │
  ├─> From Contacts
  │     ├─> Request permission
  │     ├─> Fetch contacts with emails
  │     ├─> Multi-select
  │     └─> Import
  │
  ├─> From CSV
  │     ├─> Select CSV file
  │     ├─> Parse CSV
  │     ├─> Preview recipients
  │     └─> Import
  │
  └─> Manual Entry
        ├─> Fill form
        └─> Add recipient
```

### 3. Generate & Send PDFs

```
Send Flow
  │
  ├─> Generate PDFs
  │     ├─> For each recipient:
  │     │     ├─> Copy template
  │     │     ├─> Fill fields from mapping
  │     │     └─> Create personalized PDF
  │     └─> Display list
  │
  └─> Share PDF (per recipient)
        ├─> Save to Documents
        ├─> Show share sheet
        │     ├─> Mail
        │     ├─> Messages
        │     ├─> AirDrop
        │     └─> Other apps
        └─> Log send action
```

### 4. View & Export Logs

```
Logs
  │
  ├─> View Logs
  │     ├─> List all sends
  │     │     ├─> Recipient name
  │     │     ├─> Email
  │     │     ├─> Timestamp
  │     │     └─> Status
  │     └─> Delete logs
  │
  └─> Export Logs
        ├─> Generate CSV
        └─> Share via share sheet
```

### 5. In-App Purchases

```
IAP Flow
  │
  ├─> View Products
  │     ├─> Load from App Store
  │     ├─> Full App
  │     └─> Pro Features
  │
  ├─> Purchase
  │     ├─> Initiate purchase
  │     ├─> App Store handles payment
  │     ├─> Verify transaction
  │     ├─> Update entitlements
  │     └─> Save status locally
  │
  └─> Restore Purchases
        ├─> Sync with App Store
        └─> Update local status
```

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Views Layer                         │
│  (ContentView, TemplateView, RecipientsView, etc.)      │
└──────────────────────┬──────────────────────────────────┘
                       │ @EnvironmentObject
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   AppState (Observable)                  │
│  • pdfTemplate    • recipients    • sendLogs            │
└──────────────────────┬──────────────────────────────────┘
                       │ Coordinates
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   Services Layer                         │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐       │
│  │Storage │  │  PDF   │  │Contacts│  │  CSV   │       │
│  │Service │  │Service │  │Service │  │Service │       │
│  └────────┘  └────────┘  └────────┘  └────────┘       │
└──────────────────────┬──────────────────────────────────┘
                       │ Integrates with
                       ▼
┌─────────────────────────────────────────────────────────┐
│                iOS System Frameworks                     │
│  • UserDefaults  • PDFKit  • Contacts  • StoreKit      │
└─────────────────────────────────────────────────────────┘
```

## State Management Flow

```
User Action (e.g., "Import PDF")
         │
         ▼
    View captures event
         │
         ▼
    Call AppState method
    appState.saveTemplate(template)
         │
         ▼
    AppState updates @Published property
    self.pdfTemplate = template
         │
         ├─> Call StorageService
         │   storageService.saveTemplate(template)
         │           │
         │           ▼
         │   Save to UserDefaults
         │
         └─> SwiftUI detects change
                     │
                     ▼
             View re-renders
```

## File Organization Map

```
PDFPacketSender/
│
├── PDFPacketSenderApp.swift          [App Entry]
│   └── ContentView.swift             [Main Navigation]
│
├── Models/                            [Data Models]
│   ├── AppState.swift                [Central State]
│   ├── PDFTemplate.swift             [Template Model]
│   ├── Recipient.swift               [Recipient Model]
│   └── SendLog.swift                 [Log Model]
│
├── Views/                             [UI Components]
│   ├── TemplateView.swift            [PDF Import]
│   ├── FieldMappingView.swift        [Field Mapping]
│   ├── RecipientsView.swift          [Recipients List]
│   ├── ContactsPickerView.swift      [Contacts Import]
│   ├── CSVImporterView.swift         [CSV Import]
│   ├── ManualRecipientView.swift     [Manual Add]
│   ├── SendView.swift                [PDF Generation]
│   ├── LogsView.swift                [Send Logs]
│   ├── SettingsView.swift            [Settings]
│   └── PurchaseView.swift            [IAP]
│
├── Services/                          [Business Logic]
│   ├── StorageService.swift          [Data Persistence]
│   ├── PDFService.swift              [PDF Processing]
│   ├── ContactsService.swift         [Contacts Access]
│   └── CSVService.swift              [CSV Parsing]
│
├── IAP/                               [Payments]
│   └── IAPManager.swift              [StoreKit 2]
│
├── Utils/                             [Helpers]
│   ├── DocumentPicker.swift          [File Picker]
│   └── ShareSheet.swift              [Share Sheet]
│
└── Resources/                         [Assets & Config]
    ├── Info.plist                    [App Config]
    ├── Assets.xcassets/              [Images, Icons]
    └── PDFPacketSender.entitlements  [Capabilities]
```

## Key Interaction Patterns

### Pattern 1: Import & Process
```
User Action → Service Process → Update State → Save to Storage → UI Update
```

### Pattern 2: Generate & Share
```
Template + Recipients → PDF Service → Generated PDFs → Share Sheet → Log
```

### Pattern 3: IAP Flow
```
View Products → Purchase → Verify → Update State → Save Local → UI Update
```

## Technology Integration Points

```
┌──────────────┐
│    SwiftUI   │ ← Modern declarative UI
└──────┬───────┘
       │
       ├─> PDFKit ← PDF manipulation
       │
       ├─> Contacts ← Address book access
       │
       ├─> StoreKit 2 ← In-app purchases
       │
       └─> Foundation ← Core utilities
           ├─> UserDefaults (storage)
           ├─> FileManager (documents)
           └─> Codable (serialization)
```

## Offline-First Architecture

```
All Operations Local
        │
        ├─> UserDefaults
        │   ├─> Template metadata
        │   ├─> Recipients list
        │   ├─> Send logs
        │   └─> Pro status
        │
        └─> Documents Directory
            ├─> Template PDF
            └─> Generated PDFs

No Network Required ✓
(Except IAP with App Store)
```

## Summary

This app follows a clean, layered architecture:

1. **Views** handle UI and user interaction
2. **AppState** manages application state
3. **Services** implement business logic
4. **Storage** persists data locally
5. **iOS Frameworks** provide system integration

All data flows through AppState, ensuring consistency and making the app easy to debug and extend.

---

For detailed technical information, see ARCHITECTURE.md
For development guidance, see DEVELOPER_GUIDE.md
