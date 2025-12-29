# PDF Packet Builder - Living Project Documentation

**Last Updated:** 2025-12-29  
**Version:** 1.0  
**Bundle ID:** `com.yancmo.pdfpacketbuilder`  
**Team ID:** `9PHS626XUN`

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Current Features](#current-features)
3. [Architecture](#architecture)
4. [Monetization & In-App Purchases](#monetization--in-app-purchases)
5. [App Store Connect](#app-store-connect)
6. [Build & Deployment](#build--deployment)
7. [Testing](#testing)
8. [Technical Conventions](#technical-conventions)
9. [Future Features](#future-features)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

### Purpose
PDF Packet Builder is an iOS application that automates the process of filling PDF forms with recipient data. Users can import a fillable PDF template, load recipient data from CSV files or contacts, map data fields to PDF form fields, and generate personalized PDFs for each recipient.

### Target Platform
- **Platform:** iOS 16.0+
- **Development Tool:** Xcode 15.0+
- **Language:** Swift + SwiftUI
- **Framework:** StoreKit 2 for In-App Purchases

### Use Cases
- Bulk generation of personalized documents (certificates, letters, forms)
- Mail merge for PDF forms
- Batch processing of fillable PDFs with contact data
- Automated document generation workflows

---

## Current Features

### 1. Template Management (TemplateView)
**Purpose:** Import and manage fillable PDF templates

**Implementation:**
- File location: `PDFPacketBuilder/Views/TemplateView.swift`
- Uses `PDFService` to extract AcroForm fields from PDFs
- Supports `DocumentPicker` for file selection
- Imports via Files providers (e.g., OneDrive/iCloud) by copying to a local sandbox URL for reliable access
- Displays PDF preview using `PDFKit`
- Shows list of detected form fields
- Free tier: 1 template maximum
- Pro: Unlimited templates

**Technical Details:**
- PDF field extraction via `PDFKit.PDFDocument`
- Fields stored in `PDFTemplate` model with `PDFField` array
- Template persisted to disk via `StorageService`
- Supports text fields and checkboxes from AcroForm
- Template name comes from the imported PDF filename (no UUID prefixes)

### 2. Recipients Management (RecipientsView)
**Purpose:** Import and manage recipient data

**Implementation:**
- File location: `PDFPacketBuilder/Views/RecipientsView.swift`
- Three import methods:
  1. **CSV Import** - `CSVImporterView` with field mapping
  2. **Contacts Import** - `ContactsPickerView` with system contacts integration
  3. **Manual Entry** - `ManualRecipientView` for individual recipients
- Deletion UX:
   - Swipe reveals a Delete button (no full-swipe instant delete)
   - Edit mode supports batch select + batch delete
- Free tier: 10 recipients per batch maximum
- Pro: Unlimited recipients

**CSV Import Flow:**
1. User selects a CSV file (either from **Recipients** tab or **Map** tab)
2. CSV is copied into the app sandbox for reliable access (`StorageService.importCSVToDocuments`)
3. `CSVService.parsePreview()` extracts headers + sample rows for display
4. `CSVService.parseCSV()` parses the full file into `[Recipient]`
5. A `CSVImportSnapshot` is saved with:
   - file reference
   - headers
   - normalized headers (for conservative mapping)
6. Recipients are loaded into `AppState` immediately:
   - Manual/Contacts recipients are preserved
   - Previously CSV-imported recipients are replaced (prevents duplicates)
7. If exactly one email-like column is detected from headers, it becomes the default for "Email column".
   - Otherwise, the app defaults to "Use Recipient Email" and shows an informational alert.

**Technical Details:**
- CSV parsing supports quoted fields, escaped quotes
- Contact access requires `NSContactsUsageDescription` in Info.plist
- Recipients stored as array in `AppState`
- Persisted via `StorageService` using `UserDefaults`
- Contacts picker supports searching (name/email/phone) and keeps an always-visible Add button while searching

### 3. Field Mapping (MapView)
**Purpose:** Map CSV columns or contact fields to PDF form fields

**Implementation:**
- File location: `PDFPacketBuilder/Views/MapView.swift`
- Visual interface showing:
  - Available PDF fields from template
  - Available data columns from recipients
  - Current mappings
- Picker-based mapping UI (manual review/editing)
- Mappings stored in template configuration

**Behavior Notes / Good to Know:**
- Mapping is disabled until a CSV is selected (prevents mapping to stale/unknown headers).
- When a CSV is selected, the app may apply conservative auto-suggestions **only for unmapped fields**.
   - Auto-suggestions only apply when there is a single high-confidence match.
   - Ambiguous fields remain unmapped.
- Computed mapping options are available in the picker:
   - Initials
   - Today (MM-DD-YY)
   - Blank
- The same source (built-in, computed, or CSV header) can be used for multiple PDF fields.
- "Email column" selection controls which value is used to prefill Mail recipients in Generate.

**Technical Details:**
- Mapping stored in `PDFTemplate.fieldMappings` dictionary
- Key: PDF field name, Value: data column name
- Used during PDF generation to fill correct fields

#### Smart Mapping Heuristics (Future)
This section is a placeholder for future work to keep mapping logic documented in one place.

- Candidate sources: PDF field name tokens, CSV header tokens, built-in fields, computed fields
- Constraints: never auto-apply changes that require user intent; only suggest when high confidence
- Safety rules: never overwrite an existing user mapping; always keep mapping editable
- Telemetry: none (offline-first)

### 4. PDF Generation (GenerateView)
**Purpose:** Generate personalized PDFs for selected recipients

**Implementation:**
- File location: `PDFPacketBuilder/Views/GenerateView.swift`
- User selects which recipients to include for the current generation
- Generates one PDF per recipient
- Provides per-recipient actions:
   - Share (iOS share sheet)
   - Mail (in-app mail composer)
- Optional Message Template:
   - User-authored Subject + Body (plain text)
   - Merge tokens:
     - System tokens (e.g., `{{recipient_name}}`, `{{date}}`, `{{sender_name}}`)
     - CSV tokens are generated from CSV headers (normalized to lower_snake_case)
   - Preview rendered subject/body for a chosen recipient
   - Batch Export Folder writes per-recipient `Packet.pdf` + `Message.txt` (+ `Summary.csv`)
- Logs sends only after confirmed delivery actions (share completed, mail sent)

**Generation Process:**
1. Validates template and recipients exist
2. User selects recipients for this batch
3. Checks free tier limits (10 selected recipients max)
4. For each selected recipient:
   - Clones template PDF
   - Applies field mappings
   - Fills PDF fields via `PDFService.generatePersonalizedPDF()`
   - Names file: `{TemplateName}_{FullName}_{RecipientIDPrefix}.pdf` (sanitized + unique)
5. User shares/mails PDFs one at a time
6. Logs to `SendLog` only when:
   - Share sheet `completed == true`, or
   - Mail composer result is `.sent`

**UX Enhancements:**
- Recipient list can be shown/hidden to reduce clutter; it auto-collapses after tapping "Generate PDFs".
- Each generated item shows a Sent/Unsent status chip derived from `SendLog` (no duplicate state).
- Filter: All / Unsent / Sent
- Progress label: Sent X / Y
- Mail "To:" prefills from the selected "Email column" (if set); if missing, the app warns and opens Mail with an empty To field.

**Technical Details:**
- Uses `PDFKit.PDFDocument` for field filling
- Filename sanitization to prevent invalid characters
- Generation happens on a background queue (UI remains responsive)
- Share sheet via `UIActivityViewController` wrapper
- Mail via `MFMailComposeViewController` wrapper

### 5. History & Logs (LogsView)
**Purpose:** Track send/share history (confirmed delivery actions only)

**Implementation:**
- File location: `PDFPacketBuilder/Views/LogsView.swift`
- Displays chronological list of send/share actions
- Shows: recipient name, template name, date, method
- Free tier: 7-day log retention
- Pro: Unlimited log retention
- Export logs to CSV

**Technical Details:**
- Logs stored in `SendLog` model
- Persisted via `StorageService` in `UserDefaults`
- Automatic cleanup via `AppState.cleanOldLogs()` for free users
- CSV export via `AppState.exportLogsAsCSV()`

### 6. Settings & IAP (SettingsView, PurchaseView)
**Purpose:** App settings and purchase management

**Implementation:**
- File locations:
  - `PDFPacketBuilder/Views/SettingsView.swift`
  - `PDFPacketBuilder/Views/PurchaseView.swift`
- Displays current tier (Free/Pro)
- Shows free tier limits
- Purchase or restore "Unlock Pro"
- App version and bundle ID display

**Technical Details:**
- IAP managed by `IAPManager` using StoreKit 2
- Real-time purchase status updates
- Restore purchases via `AppStore.sync()`
- Pro status persisted separately from transaction verification

**Debug Testing:**
- Debug builds include a Settings toggle to *simulate Free tier* for testing, even when the Apple ID owns Pro.
- This does not change real App Store entitlements and is excluded from production builds.

---

## Architecture

### App Structure

```
PDFPacketBuilder/
├── PDFPacketBuilderApp.swift          # App entry point
├── Models/                             # Data models
│   ├── AppState.swift                 # Central app state
│   ├── Recipient.swift                # Recipient data model
│   ├── PDFTemplate.swift              # Template + fields model
│   ├── SendLog.swift                  # Generation log model
│   └── CSVImportSnapshot.swift        # CSV import state
├── Views/                              # SwiftUI views (6 tabs)
│   ├── ContentView.swift              # Main tab container
│   ├── TemplateView.swift             # Tab 1: Template
│   ├── RecipientsView.swift           # Tab 2: Recipients
│   ├── MapView.swift                  # Tab 3: Field mapping
│   ├── GenerateView.swift             # Tab 4: Generation
│   ├── LogsView.swift                 # Tab 5: History
│   ├── SettingsView.swift             # Tab 6: Settings
│   ├── PurchaseView.swift             # IAP paywall
│   ├── CSVImporterView.swift          # CSV import UI
│   ├── CSVImportPreviewView.swift     # CSV preview
│   ├── FieldMappingView.swift         # Legacy mapping view (not primary flow)
│   ├── ContactsPickerView.swift       # Contact picker
│   ├── ManualRecipientView.swift      # Manual entry form
│   └── PDFPreviewView.swift           # PDF preview
├── Services/                           # Business logic
│   ├── PDFService.swift               # PDF operations
│   ├── CSVService.swift               # CSV parsing
│   ├── ContactsService.swift          # Contact access
│   └── StorageService.swift           # Persistence
├── Utils/                              # UI helpers
│   ├── DocumentPicker.swift           # File picker wrapper
│   ├── ShareSheet.swift               # Share sheet wrapper
│   └── MailComposer.swift             # Email composer wrapper
├── IAP/                                # In-App Purchase
│   └── IAPManager.swift               # StoreKit 2 manager
└── Resources/                          # Assets & config
    ├── Info.plist                     # App configuration
    └── Assets.xcassets/               # Images & icons
```

### State Management

**Central State:** `AppState` (ObservableObject)
- Single source of truth for app data
- Published properties trigger UI updates
- Persistence via `StorageService`

**Key Published Properties:**
- `pdfTemplate: PDFTemplate?` - Current template
- `recipients: [Recipient]` - Current recipient list
- `sendLogs: [SendLog]` - Generation history
- `isProUnlocked: Bool` - Pro status
- `csvImport: CSVImportSnapshot?` - CSV import state
- `csvEmailColumn: String?` - Optional CSV header used to prefill Mail recipients

**Environment Objects:**
- `@EnvironmentObject var appState: AppState` - Shared across all views
- `@EnvironmentObject var iapManager: IAPManager` - IAP state

### Data Persistence

**Method:** `UserDefaults` + JSON encoding
**Location:** `StorageService.swift`

**Persisted Data:**
- Template (as JSON)
- Recipients (as JSON array)
- Logs (as JSON array)
- Pro status (Bool)
- CSV import snapshot (as JSON)
- CSV email column selection (String?)

**Storage Keys:**
```swift
"pdfTemplate"
"recipients"
"sendLogs"
"isProUnlocked"
"csvImport"
"csvEmailColumn"
```

### Services

#### PDFService
- **Purpose:** PDF manipulation
- **Key Methods:**
  - `extractFields(from: Data) -> [PDFField]` - Extract form fields
  - `generatePersonalizedPDF(template:recipient:) -> Data?` - Fill PDF

#### CSVService
- **Purpose:** CSV file parsing
- **Key Methods:**
   - `parseCSV(data: String) -> [Recipient]` - Parse CSV into recipients
   - `parsePreview(data: String, maxRows: Int) -> CSVPreview` - Headers + sample rows preview
- **Features:** Handles quoted fields, escaped quotes, commas, mixed LF/CRLF, missing values (best-effort)

#### ContactsService
- **Purpose:** System contacts access
- **Key Methods:**
   - `requestAccessIfNeeded() async -> Bool` - Request permission only when appropriate
  - `fetchContacts() -> [CNContact]` - Retrieve contacts
- **Permissions:** Requires `NSContactsUsageDescription`

#### StorageService
- **Purpose:** Data persistence
- **Methods:** Save/load for each data type
- **Implementation:** JSON encoding to `UserDefaults`

---

## Monetization & In-App Purchases

### Product Configuration

**Single Product Model:** "Unlock Pro" (Non-Consumable)
- **Product ID:** `com.yancmo.pdfpacketbuilder.pro.unlock`
- **Type:** Non-consumable (one-time purchase)
- **Price:** Set in App Store Connect (pricing tier)

### Free Tier Limits

Defined in `AppState`:
```swift
static let freeMaxTemplates = 1
static let freeMaxRecipients = 10
static let freeLogRetentionDays = 7
```

**Free Features:**
- 1 template maximum
- 10 recipients per batch
- 7-day log retention
- All core functionality available

**Pro Features (Unlocked):**
- Unlimited templates
- Unlimited recipients per batch
- Unlimited log retention
- No feature restrictions

### Implementation Details

**Framework:** StoreKit 2 (modern async/await API)
**File:** `PDFPacketBuilder/IAP/IAPManager.swift`

**Key Components:**
1. **Product Loading:**
   ```swift
   Product.products(for: [proProductID])
   ```

2. **Purchase Flow:**
   ```swift
   product.purchase() -> Product.PurchaseResult
   ```

3. **Transaction Verification:**
   - Automatic verification via `Transaction.currentEntitlements`
   - Listens for updates via `Transaction.updates`

4. **Restore Purchases:**
   ```swift
   AppStore.sync()
   ```

**Pro Status:**
- Computed property: `iapManager.isProUnlocked`
- Updates `appState.isProUnlocked` via `onChange` modifier
- Persisted separately via `StorageService`

**Limit Enforcement:**
- Template limits checked in `TemplateView`
- Recipient limits checked in `GenerateView`
- Log retention enforced in `AppState.cleanOldLogs()`

### StoreKit Configuration

**Testing:**
- Use StoreKit Configuration file (`.storekit`) for Xcode testing
- Or test with TestFlight builds
- Sandbox testing not recommended (unreliable)

**App Store Connect Setup Required:**
1. Create In-App Purchase in App Store Connect
2. Product ID must match: `com.yancmo.pdfpacketbuilder.pro.unlock`
3. Set pricing tier
4. Add localizations (name, description)
5. Submit product for review with first app version
6. Product must be "Ready to Submit" status

---

## App Store Connect

### App Information

**App Name:** PDF Packet Builder  
**Bundle ID:** `com.yancmo.pdfpacketbuilder`  
**SKU:** (Set in App Store Connect)  
**Category:** Business or Productivity (recommended)

### App Store Listing (Recommendations)

**Subtitle:** "Bulk PDF Form Filler"

**Description Template:**
```
Automate PDF form filling with bulk recipient data.

KEY FEATURES:
• Import fillable PDF templates
• Load recipients from CSV or Contacts
• Map data fields to PDF forms
• Generate personalized PDFs in bulk
• Track generation history

PERFECT FOR:
• Certificates and awards
• Personalized letters
• Bulk form processing
• Mail merge for PDFs

FREE TIER:
• 1 template
• 10 recipients per batch
• 7-day history

UNLOCK PRO:
• Unlimited templates
• Unlimited recipients
• Unlimited history
```

**Keywords:** (100 characters max)
```
PDF,form,bulk,merge,generator,template,certificate,personalized,automation,documents
```

**Privacy Policy:** Required (host on GitHub Pages or external site)

**Support URL:** GitHub repo or external site

### Privacy & Permissions

**Permissions Used:**
1. **Contacts Access** (optional)
   - Purpose: "Access contacts to select recipients for PDF generation"
   - Usage description in `Info.plist`: `NSContactsUsageDescription`
   - User can decline and use CSV/manual entry instead

2. **File Access** (implicit)
   - Document picker for PDF and CSV files
   - Share sheet for exporting PDFs

**Data Collection:**
- App does NOT collect or transmit user data
- All data stored locally on device
- No analytics or tracking
- Privacy policy should reflect "No Data Collected"

### Screenshots & Previews

**Required Sizes:**
- iPhone 6.7" (1290 x 2796) - iPhone 14 Pro Max
- iPhone 6.5" (1242 x 2688) - iPhone 11 Pro Max
- iPad Pro 12.9" (2048 x 2732)

**Recommended Screens to Capture:**
1. Template view showing imported PDF
2. Recipients view with sample data
3. Field mapping interface
4. Generated PDFs ready to share
5. Settings showing Pro features

---

## Build & Deployment

### Local Development

**Prerequisites:**
- macOS with Xcode 15.0+
- Apple Developer account (for device testing)
- Ruby environment (for Fastlane)

**Setup Steps:**
1. Clone repository
   ```bash
   git clone https://github.com/yancmo1/PDF-Packet-Builder.git
   cd PDF-Packet-Builder
   ```

2. Install Fastlane dependencies
   ```bash
   bundle install
   ```

3. Open in Xcode
   ```bash
   open PDFPacketBuilder.xcodeproj
   ```

4. Configure signing
   - Select project in navigator
   - Select target > Signing & Capabilities
   - Choose your Team
   - Xcode will automatically provision

5. Build and run
   - Select iOS Simulator or device
   - Cmd+R to build and run

### Fastlane Automation

**Configuration Files:**
- `fastlane/Fastfile` - Lane definitions
- `fastlane/Appfile` - App identifier and team ID
- `Gemfile` - Ruby dependencies

**Available Lanes:**

1. **Tests:**
   ```bash
   bundle exec fastlane tests
   ```
   Runs unit/UI tests via `scan` when a Test action is configured.
   If the scheme has no tests configured, the lane falls back to a clean build to keep CI green.

2. **Beta (TestFlight):**
   ```bash
   bundle exec fastlane beta
   ```
   Builds and uploads to TestFlight

3. **Beta with Processing Wait:**
   ```bash
   WAIT_FOR_PROCESSING=1 bundle exec fastlane beta
   ```
   Waits for Apple to process build

4. **TestFlight Status:**
   ```bash
   bundle exec fastlane tf_status
   ```
   Shows latest TestFlight build number

5. **Upload Metadata:**
   ```bash
   bundle exec fastlane upload_metadata
   ```
   Uploads App Store metadata/screenshots

6. **Submit for Review:**
   ```bash
   bundle exec fastlane release
   ```
   Submits latest build for App Store review

7. **Full Release:**
   ```bash
   bundle exec fastlane release_full
   ```
   Uploads metadata and submits for review

### Authentication

**Preferred: App Store Connect API Key**

1. Create API key in App Store Connect:
   - Users and Access > Keys > App Store Connect API

2. Download `.p8` key file

3. Store outside repo:
   ```bash
   mkdir -p ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
   chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
   ```

4. Set environment variables:
   ```bash
   export ASC_KEY_ID="ABC123DEFG"
   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_ABC123DEFG.p8"
   ```

5. Use with direnv (optional):
   ```bash
   cp .envrc.example .envrc
   # Edit .envrc with your values
   direnv allow
   ```

**Fallback: Apple ID Authentication**

Set these if not using API key:
```bash
export FASTLANE_USER="your@email.com"
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

### VS Code Tasks

Pre-configured tasks in `.vscode/tasks.json`:
- Run via `Cmd+Shift+P` > "Tasks: Run Task"

**Available Tasks:**
- Fastlane: Beta Upload
- Fastlane: TestFlight Status
- Fastlane: Tests
- Fastlane: Upload Metadata & Screenshots
- Fastlane: Submit for App Store Review
- Fastlane: Full App Store Submission

### Build Settings

**Key Settings in Xcode:**
- **Display Name:** PDF Packet Builder
- **Bundle Identifier:** com.yancmo.pdfpacketbuilder
- **Version:** 1.0 (CFBundleShortVersionString)
- **Build Number:** 1 (CFBundleVersion)
- **Deployment Target:** iOS 16.0
- **Team ID:** 9PHS626XUN

**Capabilities Required:**
- In-App Purchase
- Associated Domains (for Universal Links, if added later)

**Entitlements:**
- In-App Purchase: `com.apple.developer.in-app-payments`

### Version Management

**Semantic Versioning:** `MAJOR.MINOR.PATCH`
- **MAJOR:** Breaking changes or major features
- **MINOR:** New features, backward compatible
- **PATCH:** Bug fixes

**Build Number Strategy:**
- Auto-increment for each TestFlight build
- Can use `agvtool` or manual increment
- Fastlane can auto-increment via `increment_build_number`

### Release Checklist

**Before Each Release:**
1. [ ] Update version number in Xcode
2. [ ] Update CHANGELOG (if exists)
3. [ ] Run tests: `bundle exec fastlane tests`
4. [ ] Test on physical device
5. [ ] Verify IAP works (sandbox or TestFlight)
6. [ ] Update App Store metadata (if needed)
7. [ ] Upload to TestFlight: `bundle exec fastlane beta`
8. [ ] Test TestFlight build
9. [ ] Submit for review: `bundle exec fastlane release`
10. [ ] Monitor App Store review status

---

## Testing

### Current Test Coverage

**Status:** Minimal/No automated tests currently implemented

**Test Infrastructure:**
- Project supports `XCTest` framework
- Can add unit tests in `PDFPacketBuilderTests` target
- Can add UI tests in `PDFPacketBuilderUITests` target

### Manual Testing Checklist

**Template Tab:**
- [ ] Import PDF with form fields
- [ ] Preview displays correctly
- [ ] Fields list shows all detected fields
- [ ] Free tier: Cannot add 2nd template
- [ ] Remove template works
- [ ] Replace template works

**Recipients Tab:**
- [ ] Import CSV file
- [ ] CSV preview shows correct data
- [ ] Recipients list populates from CSV (and CSV re-import replaces prior CSV recipients)
- [ ] Import from Contacts (grant permission)
- [ ] Search contacts and add while searching (persistent Add button)
- [ ] Manual recipient entry works
- [ ] Edit/delete recipients (swipe reveals Delete; Edit supports batch delete)
- [ ] Free tier: Cannot add >10 recipients

**Map Tab:**
- [ ] Shows template fields
- [ ] Mapping disabled until a CSV is selected
- [ ] Shows available CSV columns once a CSV is selected
- [ ] Field mapping UI functional (picker)
- [ ] Computed mapping options available (Initials/Today/Blank)
- [ ] Email column defaults correctly (auto-detected when possible)
- [ ] Mappings persist

**Generate Tab:**
- [ ] Generate button enabled when ready
- [ ] PDFs generate correctly
- [ ] Can select subset of recipients for generation
- [ ] Recipient list can be Show/Hidden; auto-collapses after Generate
- [ ] All mapped fields filled
- [ ] Filename format correct (includes recipient ID suffix; sanitized)
- [ ] Sent/Unsent status chips show correctly
- [ ] Filter All/Unsent/Sent works
- [ ] Sent X / Y progress updates after logging
- [ ] Share sheet displays
- [ ] Can save/share generated PDFs
- [ ] Settings: Sender name/email can be entered and persists across relaunch
- [ ] Message Template: subject/body can be entered and persists across relaunch
- [ ] Message Template: preview shows per-recipient rendering with merge tokens
- [ ] Message Template: unknown tokens are warned (and preserved in output)
- [ ] Export Folder: creates one subfolder per recipient with `Packet.pdf`
- [ ] Export Folder: when template enabled, writes `Message.txt` per recipient
- [ ] Export Folder: writes `Summary.csv` at export root (best-effort)
- [ ] Share 1 PDF → complete → log appears
- [ ] Share 1 PDF → cancel → no log
- [ ] Mail 1 PDF → send → log appears
- [ ] Mail 1 PDF → cancel → no log
- [ ] Mail with missing email → warning shown → Mail opens with empty To
- [ ] Free tier: Cannot generate with >10 selected recipients

**Logs Tab:**
- [ ] Shows generation history
- [ ] Displays correct information
- [ ] Export to CSV works
- [ ] Free tier: Old logs deleted after 7 days

**Settings Tab:**
- [ ] Shows current tier (Free/Pro)
- [ ] Shows limit information
- [ ] Purchase Pro button works
- [ ] Restore purchases works
- [ ] App info displays correctly

**IAP Testing:**
- [ ] Product loads from App Store Connect
- [ ] Purchase flow completes
- [ ] Receipt validated
- [ ] Pro status updates immediately
- [ ] Limits removed after purchase
- [ ] Restore purchases works
- [ ] Purchase persists across app restarts

### Testing StoreKit

**Method 1: StoreKit Configuration File (Recommended)**
1. Create `.storekit` file in Xcode
2. Add product with matching ID
3. Run in simulator
4. Use test accounts

**Method 2: TestFlight**
1. Upload build to TestFlight
2. Product must exist in App Store Connect
3. Use sandbox tester account
4. More realistic testing environment

**Method 3: Production**
- Real purchases (use promo codes for free testing)

---

## Technical Conventions

### Code Style

**Language:** Swift 5.9+
**UI Framework:** SwiftUI

**Naming Conventions:**
- Views: PascalCase suffixed with `View` (e.g., `TemplateView`)
- Services: PascalCase suffixed with `Service` (e.g., `PDFService`)
- Models: PascalCase (e.g., `Recipient`, `PDFTemplate`)
- Properties: camelCase (e.g., `pdfTemplate`, `isProUnlocked`)
- Methods: camelCase (e.g., `loadProducts()`, `generatePDF()`)

**File Organization:**
- One view per file
- Views in `Views/` directory
- Services in `Services/` directory
- Models in `Models/` directory
- Utils in `Utils/` directory

**Comments:**
- Minimal file headers (name and app only)
- Add comments for complex logic
- Use `// MARK:` for section organization

### SwiftUI Patterns

**State Management:**
- `@StateObject` for view-owned objects
- `@EnvironmentObject` for shared app state
- `@Published` for observable properties
- `@State` for view-local state

**View Composition:**
- Extract reusable components
- Keep views focused and single-purpose
- Use `ViewBuilder` for conditional content

**Async Operations:**
- Use `async/await` for asynchronous work
- Wrap in `Task { }` blocks
- Update UI on `@MainActor`

### Error Handling

**Current Approach:**
- Optional returns for operations that can fail
- Print statements for debugging
- User-facing alerts for critical errors

**Best Practices:**
- Validate inputs before processing
- Provide user-friendly error messages
- Log errors for debugging
- Graceful degradation when possible

### Dependencies

**External:**
- None (uses only iOS SDK frameworks)
- Xcode-managed project (no `Package.swift` / SwiftPM manifest in this repo)

**iOS Frameworks:**
- SwiftUI (UI)
- PDFKit (PDF manipulation)
- StoreKit (IAP)
- Contacts (contact access)
- UIKit (bridges for share sheet, document picker)

### Persistence Strategy

**Current:** `UserDefaults` + JSON encoding
- Suitable for small data sets
- Simple implementation
- No external dependencies

**Future Consideration:**
- Core Data or SwiftData for larger data sets
- File-based storage for PDFs
- iCloud sync (if multi-device support needed)

### Security

**Sensitive Data:**
- No sensitive data stored
- No custom network communication in app code (offline-first)
- StoreKit/App Store interactions are handled by Apple frameworks (standard transport security)
- All processing local

**IAP Security:**
- Transaction verification via StoreKit 2
- Automatic receipt validation
- Secure entitlement checking

### Accessibility

**Current Status:**
- SwiftUI default accessibility
- System fonts and dynamic type
- Standard UI controls

**Future Improvements:**
- VoiceOver labels for custom controls
- Accessibility hints
- Support for larger text sizes

---

## Future Features

### Planned Features

#### Priority 1: Near-Term

1. **Enhanced CSV Column Selection**
   - **Description:** UI to select which CSV column to use for recipient Email (Mail prefill)
   - **Current State:** Implemented for Email only (auto-detects a single email-like header when possible)
   - **Next:** Optional UI to map First/Last name columns when headers don’t match defaults

2. **Custom Filename Format**
   - **Description:** User-configurable filename format with variables
   - **Format:** `{TemplateName}_{Last}_{First}_{YYYY-MM-DD}.pdf`
   - **Current State:** Fixed format `{Template}_{FullName}_{RecipientIDPrefix}.pdf` (sanitized + unique)
   - **Implementation:** Settings option + `DateFormatter` usage
   - **Files to Modify:** `GenerateView.swift`, `SettingsView.swift`, `AppState.swift`

3. **Batch Generation Progress**
   - **Description:** Progress bar during PDF generation
   - **Current State:** Generation runs on a background queue and shows a spinner overlay; no per-recipient progress yet
   - **Implementation:** Background task with progress updates
   - **Files to Modify:** `GenerateView.swift`, `PDFService.swift`

4. **Batch Share / Export Flow**
   - **Description:** Offer a single action to share/export multiple generated PDFs at once (ZIP or multi-select)
   - **Current State:** Share/Mail is per-recipient
   - **Implementation:** Multi-selection + export packaging (ZIP)
   - **Files to Modify:** `GenerateView.swift`, new `ExportService.swift`

#### Priority 2: Medium-Term

5. **PDF Field Type Support**
   - **Description:** Support for more field types (dropdowns, radio buttons)
   - **Current State:** Text fields and checkboxes only
   - **Implementation:** Expand `PDFService.determineFieldType()`
   - **Files to Modify:** `PDFService.swift`, `PDFField` model

6. **Template Management**
   - **Description:** Multiple template storage and selection
   - **Current State:** Pro tier allows but UI limited
   - **Implementation:** Template library view
   - **New Files:** `TemplateLibraryView.swift`

7. **Advanced Mapping**
   - **Description:** Formulas, conditional logic, data transformation
   - **Current State:** Supports direct mapping plus limited computed values (Initials/Today/Blank) and conservative auto-suggestions
   - **Implementation:** Expression evaluator
   - **Files to Modify:** `MapView.swift`, new `MappingEngine.swift`

8. **Export Options**
   - **Description:** Export as single merged PDF or ZIP archive
   - **Current State:** Individual PDFs via share sheet
   - **Implementation:** PDF merging, ZIP creation
   - **Files to Modify:** `GenerateView.swift`, new `ExportService.swift`

#### Priority 3: Long-Term

9. **iCloud Sync**
   - **Description:** Sync templates and recipients across devices
   - **Current State:** Device-local storage only
   - **Implementation:** CloudKit integration
   - **Files to Modify:** `StorageService.swift`, enable iCloud capability

10. **Shortcuts Integration**
    - **Description:** Siri Shortcuts for automation
    - **Current State:** No shortcuts support
    - **Implementation:** App Intents framework
    - **New Files:** Intents extension

11. **Recurring Generations**
    - **Description:** Schedule automatic PDF generation
    - **Current State:** Manual generation only
    - **Implementation:** Background tasks, notifications
    - **New Files:** Scheduling service

12. **Advanced Analytics**
    - **Description:** Generation statistics, usage insights
    - **Current State:** Basic log history
    - **Implementation:** Charts, aggregation
    - **New Files:** `AnalyticsView.swift`

### Feature Requests Tracking

**Process:**
1. User submits via GitHub Issues
2. Label as `enhancement`
3. Prioritize in roadmap
4. Add to this section with status

**Current Requests:**
- (None at this time)

### Known Limitations

1. **PDF Compatibility:**
   - Only supports AcroForm PDFs (not XFA forms)
   - Some PDFs may have undetectable fields

2. **Performance:**
   - Large batches (>100 recipients) may cause UI lag
   - PDF generation is backgrounded, but very large batches may still be slow due to PDF work and file I/O

3. **CSV Parsing:**
   - Limited encoding support (UTF-8 primarily)
   - No Excel (.xlsx) support

4. **Contacts Integration:**
   - Requires explicit permission
   - No sync with changes to system contacts

---

## Troubleshooting

### Common Issues

#### Issue: "No products returned" in IAP

**Cause:** Product not configured in App Store Connect or build not eligible

**Solutions:**
1. Verify product ID matches exactly: `com.yancmo.pdfpacketbuilder.pro.unlock`
2. Ensure product status is "Ready to Submit" in App Store Connect
3. Test with TestFlight build (not simulator with production)
4. Wait 24-48 hours after creating product
5. Check App Store Connect agreements are signed

#### Issue: PDF fields not detected

**Cause:** PDF doesn't have AcroForm fields or uses XFA forms

**Solutions:**
1. Verify PDF has fillable fields (open in Preview/Acrobat)
2. Re-create PDF with AcroForm fields (not XFA)
3. Use Adobe Acrobat to add form fields
4. Test with sample fillable PDF first

#### Issue: CSV import fails

**Cause:** Encoding issues or malformed CSV

**Solutions:**
1. Save CSV as UTF-8 encoding
2. Ensure proper quoting for fields with commas
3. Check for consistent number of columns per row
4. Test with simple CSV first

#### Issue: Import fails from OneDrive/iCloud (“Access to the selected file was denied”)

**Cause:** Some Files providers require security-scoped access and coordinated reads, and can temporarily deny access if the file is not fully downloaded.

**Solutions:**
1. In the Files app, ensure the file is downloaded locally (e.g., “Download Now”)
2. As a quick sanity check, import a copy stored in “On My iPhone”
3. Re-open the picker and re-select the file (providers can time out)

#### Issue: TestFlight upload fails

**Cause:** Signing or authentication issues

**Solutions:**
1. Verify API key environment variables set correctly
2. Check `.p8` file exists at `ASC_KEY_PATH`
3. Ensure certificates and profiles valid
4. Try Apple ID auth as fallback
5. Check Fastlane logs for specific error

#### Issue: Builds in Xcode, but Fastlane/CLI build fails

**Cause:** A Swift file was added in the editor but not included in the Xcode target (Target Membership / project.pbxproj).

**Solutions:**
1. In Xcode: select the file → File Inspector → ensure the app target is checked
2. Commit the updated `project.pbxproj`
3. If you intentionally avoid adding new files, prefer placing small shared helpers into an existing compiled file that’s already in-target

#### Issue: App Store Connect asks for Export Compliance (encryption)

**Cause:** App Store Connect can't infer export compliance from the build metadata, or the setting isn't declared in the app.

**Solution (typical for apps using only exempt encryption / Apple system frameworks):**
1. Ensure `Info.plist` includes:
   - `ITSAppUsesNonExemptEncryption` = `false`
2. Only change this if you add **non-exempt** encryption (custom crypto, proprietary protocols, etc.)

#### Issue: App crashes on launch

**Cause:** Various possibilities

**Solutions:**
1. Check crash logs in Xcode Organizer
2. Verify Info.plist configuration
3. Test on clean simulator/device
4. Check for nil force-unwraps
5. Validate StoreKit configuration

### Debug Strategies

**Xcode Debugging:**
1. Breakpoints in key methods
2. Print statements for data flow
3. View hierarchy debugging
4. Memory graph debugging

**Fastlane Debugging:**
1. Run with verbose flag: `bundle exec fastlane beta --verbose`
2. Check `fastlane/report.xml`
3. Verify environment variables: `env | grep ASC`
4. Test lanes individually

**IAP Debugging:**
1. Use StoreKit configuration file for local testing
2. Check transaction logs in Xcode console
3. Verify product ID spelling
4. Test restore purchases separately

### Support Resources

**Documentation:**
- Apple Developer Documentation: https://developer.apple.com/documentation/
- SwiftUI Tutorials: https://developer.apple.com/tutorials/swiftui
- StoreKit 2 Guide: https://developer.apple.com/documentation/storekit
- Fastlane Docs: https://docs.fastlane.tools/

**Community:**
- Stack Overflow: Tag questions with `ios`, `swiftui`, `storekit`
- Apple Developer Forums: https://developer.apple.com/forums/

**Project Specific:**
- GitHub Issues: https://github.com/yancmo1/PDF-Packet-Builder/issues
- README: `/README.md`
- Implementation Notes: `/IMPLEMENTATION_NOTES.md`

---

## Maintenance Notes

### Document Updates

**When to Update This Document:**
1. New features added
2. Architecture changes
3. New dependencies
4. Deployment process changes
5. IAP configuration changes
6. App Store Connect updates
7. Known issues discovered
8. Troubleshooting solutions found

**Update Process:**
1. Edit `LIVING_PROJECT_DOC.md`
2. Update "Last Updated" date at top
3. Commit with descriptive message
4. Keep changes in sync with code

### Document Ownership

**Primary Maintainer:** Project lead or designated developer
**Review Frequency:** After each major feature or release
**Version Control:** Track changes via Git

---

*This is a living document. Keep it updated as the project evolves.*
