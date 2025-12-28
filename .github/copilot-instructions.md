# GitHub Copilot Instructions for PDF Packet Builder

## Overview

This document provides instructions for GitHub Copilot when working on the PDF Packet Builder iOS application. Always consult and update the project documentation as you work.

---

## Primary Reference: PROJECT.md

**IMPORTANT:** Before starting any work, always review the `PROJECT.md` file in the root directory. This is the living documentation that contains:

- Complete project overview and architecture
- All current features with implementation details
- In-App Purchase configuration
- App Store Connect details
- Build and deployment procedures
- Future features roadmap
- Technical conventions and patterns
- Troubleshooting guides

**Location:** `/PROJECT.md`

---

## Working Guidelines

### 1. Documentation-First Approach

**Before making code changes:**
1. Read relevant sections of `PROJECT.md`
2. Understand the existing architecture and patterns
3. Identify which components will be affected
4. Check if similar functionality already exists

**After making code changes:**
1. Update `PROJECT.md` to reflect changes
2. Update the "Last Updated" date at the top
3. Add to Future Features if incomplete
4. Document any new troubleshooting steps
5. Update architecture diagrams if structure changed

### 2. Feature Development

**When adding a new feature:**

1. **Plan:**
   - Check "Future Features" section in `PROJECT.md`
   - Identify priority and dependencies
   - Review similar existing features
   - Plan minimal changes approach

2. **Implement:**
   - Follow existing code patterns (see Technical Conventions in `PROJECT.md`)
   - Maintain architectural consistency
   - Keep services separate from views
   - Use `AppState` for shared state
   - Add to appropriate directory (Views/, Services/, Models/, etc.)

3. **Test:**
   - Add to manual testing checklist in `PROJECT.md`
   - Test free tier limits if applicable
   - Test IAP integration if feature affects monetization
   - Verify on physical device when possible

4. **Document:**
   - Add feature to "Current Features" section in `PROJECT.md`
   - Document implementation details
   - Note any limitations or known issues
   - Update troubleshooting section if needed
   - Move from "Future Features" to "Current Features"

### 3. Bug Fixes

**When fixing bugs:**

1. **Investigate:**
   - Check "Known Limitations" in `PROJECT.md`
   - Review "Troubleshooting" section
   - Understand root cause before fixing

2. **Fix:**
   - Make minimal, surgical changes
   - Follow existing code patterns
   - Don't introduce breaking changes
   - Maintain backward compatibility

3. **Document:**
   - Update troubleshooting section if applicable
   - Remove from "Known Limitations" if resolved
   - Document the fix in commit message
   - Update `PROJECT.md` if behavior changed

### 4. Architecture Changes

**When modifying architecture:**

1. **Review Current Architecture:**
   - Understand existing structure (see Architecture section in `PROJECT.md`)
   - Identify all affected components
   - Consider impact on state management

2. **Implement Changes:**
   - Maintain separation of concerns
   - Keep SwiftUI best practices
   - Update all affected components
   - Maintain backward compatibility where possible

3. **Update Documentation:**
   - Update "Architecture" section in `PROJECT.md`
   - Update file organization diagram
   - Document new patterns or conventions
   - Update "Technical Conventions" if patterns changed

### 5. Monetization & IAP Changes

**When modifying In-App Purchase logic:**

⚠️ **CRITICAL:** IAP changes are sensitive and affect revenue

1. **Before Changes:**
   - Review "Monetization & In-App Purchases" section in `PROJECT.md`
   - Understand current product configuration
   - Check App Store Connect requirements
   - Test plan must be thorough

2. **Implementation:**
   - Never change product IDs without migration plan
   - Maintain `IAPManager` patterns
   - Update limit enforcement in `AppState`
   - Test extensively with StoreKit Configuration

3. **Documentation:**
   - Update monetization section in `PROJECT.md`
   - Document any new products or tiers
   - Update free tier limits documentation
   - Add to release checklist

### 6. Deployment & Release

**When preparing for release:**

1. **Pre-Release:**
   - Follow "Release Checklist" in `PROJECT.md`
   - Verify all tests pass
   - Test IAP thoroughly
   - Update version numbers

2. **Fastlane:**
   - Use documented lanes (see "Build & Deployment" in `PROJECT.md`)
   - Verify authentication configured
   - Check build settings match documentation

3. **App Store Connect:**
   - Follow App Store guidelines in `PROJECT.md`
   - Update metadata if needed
   - Verify screenshots current
   - Check privacy policy up to date

4. **Post-Release:**
   - Update `PROJECT.md` with version number
   - Document any release issues
   - Add to troubleshooting if problems found

---

## Code Conventions (Quick Reference)

See full details in `PROJECT.md` > Technical Conventions

### Swift Style

- **Views:** `PascalCaseView` (e.g., `TemplateView`)
- **Services:** `PascalCaseService` (e.g., `PDFService`)
- **Models:** `PascalCase` (e.g., `Recipient`)
- **Properties:** `camelCase`
- **Methods:** `camelCase()`

### File Organization

```
PDFPacketBuilder/
├── Views/          # SwiftUI views
├── Models/         # Data models
├── Services/       # Business logic
├── Utils/          # UI helpers
├── IAP/            # In-App Purchase
└── Resources/      # Assets & config
```

### State Management

- Use `@StateObject` for view-owned objects
- Use `@EnvironmentObject` for `AppState` and `IAPManager`
- Use `@Published` in ObservableObjects
- All app data flows through `AppState`

### SwiftUI Patterns

- Compose small, focused views
- Extract reusable components
- Use `async/await` for async operations
- Update UI on `@MainActor`

### Error Handling

- Return optionals for operations that can fail
- Show user-friendly alerts for critical errors
- Log errors for debugging
- Validate inputs before processing

---

## Common Tasks

### Adding a New View

1. Create file in `PDFPacketBuilder/Views/`
2. Import SwiftUI
3. Use `@EnvironmentObject` for `appState` and `iapManager`
4. Follow existing view patterns
5. Add preview provider
6. Document in `PROJECT.md` > Current Features

### Adding a New Service

1. Create file in `PDFPacketBuilder/Services/`
2. Make it a class (not struct)
3. Keep it focused on single responsibility
4. No UI code in services
5. Document in `PROJECT.md` > Architecture > Services

### Adding a New Model

1. Create file in `PDFPacketBuilder/Models/`
2. Make it `Codable` for persistence
3. Use `struct` unless inheritance needed
4. Add to `StorageService` if needs persistence
5. Document in `PROJECT.md` > Architecture

### Modifying Free Tier Limits

1. Update constants in `AppState`:
   ```swift
   static let freeMaxTemplates = 1
   static let freeMaxRecipients = 10
   static let freeLogRetentionDays = 7
   ```
2. Update enforcement logic
3. Update UI displays (SettingsView)
4. Update `PROJECT.md` > Monetization section
5. Test thoroughly

### Adding Fastlane Lane

1. Edit `fastlane/Fastfile`
2. Follow existing lane patterns
3. Use `maybe_setup_api_key` for auth
4. Add to `.vscode/tasks.json` if needed
5. Document in `PROJECT.md` > Build & Deployment

---

## Testing Reminders

### Before Every Commit

- [ ] Code compiles without errors
- [ ] No force-unwraps added (use optional binding)
- [ ] SwiftUI previews work
- [ ] Existing functionality not broken

### Before Every PR

- [ ] Manual testing checklist completed (see `PROJECT.md`)
- [ ] IAP tested if relevant
- [ ] Free tier limits tested if relevant
- [ ] Documentation updated in `PROJECT.md`
- [ ] Commit messages descriptive

### Before Every Release

- [ ] Full "Release Checklist" in `PROJECT.md` completed
- [ ] Version numbers updated
- [ ] TestFlight tested
- [ ] IAP working in production environment

---

## Key Files Reference

Quick reference to important files:

| File | Purpose |
|------|---------|
| `PROJECT.md` | **Living documentation** - Always check first |
| `README.md` | User-facing overview and quick start |
| `IMPLEMENTATION_NOTES.md` | Historical implementation notes |
| `FASTLANE_GUIDE.md` | Detailed Fastlane setup guide |
| `PDFPacketBuilderApp.swift` | App entry point |
| `Models/AppState.swift` | Central app state management |
| `IAP/IAPManager.swift` | In-App Purchase logic |
| `Views/ContentView.swift` | Main tab container |
| `Services/*.swift` | Business logic services |
| `fastlane/Fastfile` | Build automation lanes |
| `.vscode/tasks.json` | VS Code task definitions |

---

## Decision Matrix

Use this to decide where to make changes:

| What You Want To Do | Where To Make Changes |
|---------------------|----------------------|
| Change UI layout | `Views/*.swift` |
| Add business logic | `Services/*.swift` |
| Add data model | `Models/*.swift` |
| Change persistence | `Services/StorageService.swift` |
| Modify PDF handling | `Services/PDFService.swift` |
| Change CSV parsing | `Services/CSVService.swift` |
| Modify IAP logic | `IAP/IAPManager.swift` |
| Change free limits | `Models/AppState.swift` (constants) |
| Add Fastlane lane | `fastlane/Fastfile` |
| Change app metadata | `PDFPacketBuilder/Resources/Info.plist` |
| Add UI helper | `Utils/*.swift` |

---

## Documentation Maintenance

### Required Updates to PROJECT.md

**Always update when:**
- Adding or removing features
- Changing architecture
- Modifying IAP configuration
- Changing deployment process
- Adding dependencies
- Discovering bugs or limitations
- Finding solutions to issues

**Update Process:**
1. Make code changes
2. Open `PROJECT.md`
3. Update relevant sections
4. Change "Last Updated" date
5. Commit documentation with code changes
6. Keep documentation in sync with code

### PROJECT.md Structure

If you need to update `PROJECT.md`, follow this structure:

1. **Table of Contents** - Add new sections here
2. **Project Overview** - High-level changes only
3. **Current Features** - Add new features, update existing
4. **Architecture** - Update diagrams and structure info
5. **Monetization & In-App Purchases** - IAP changes
6. **App Store Connect** - Store listing updates
7. **Build & Deployment** - Process changes
8. **Testing** - Add test cases and procedures
9. **Technical Conventions** - New patterns or standards
10. **Future Features** - Add ideas, move completed to Current Features
11. **Troubleshooting** - Add new issues and solutions

---

## When in Doubt

1. **Check `PROJECT.md` first** - Most answers are there
2. **Follow existing patterns** - Consistency is key
3. **Ask before breaking changes** - Discuss with team/user
4. **Test thoroughly** - Especially IAP and limits
5. **Document everything** - Future you will thank you
6. **Keep it simple** - Don't over-engineer
7. **User experience first** - Make it intuitive

---

## Anti-Patterns to Avoid

❌ **Don't:**
- Make changes without consulting `PROJECT.md`
- Add dependencies without careful consideration
- Change IAP product IDs without migration plan
- Break existing functionality
- Add complex abstractions prematurely
- Skip testing IAP changes
- Forget to update documentation
- Hardcode values that should be configurable
- Ignore free tier limits enforcement
- Put business logic in views

✅ **Do:**
- Read documentation before coding
- Follow existing code patterns
- Test on physical devices
- Update `PROJECT.md` with code changes
- Keep views thin, services focused
- Validate user inputs
- Handle errors gracefully
- Write clear commit messages
- Maintain separation of concerns
- Think about edge cases

---

## Emergency Procedures

### Critical IAP Bug

1. **Immediate:**
   - Document exact issue
   - Test with StoreKit Configuration
   - Check transaction logs

2. **Fix:**
   - Review IAP section in `PROJECT.md`
   - Make minimal fix
   - Test extensively
   - Fast-track TestFlight

3. **Deploy:**
   - Emergency release
   - Monitor crash reports
   - Update troubleshooting in `PROJECT.md`

### App Store Rejection

1. **Review:**
   - Read rejection reason carefully
   - Check App Store guidelines
   - Review relevant sections in `PROJECT.md`

2. **Fix:**
   - Address specific issues
   - Update metadata if needed
   - Resubmit with notes

3. **Document:**
   - Add to troubleshooting
   - Update release checklist
   - Prevent future issues

---

*Remember: `PROJECT.md` is the single source of truth. Keep it updated and always consult it when working on this project.*
