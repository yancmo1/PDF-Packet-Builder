# PR Check (Review‑Only) — PR #22 — check code changes

Review-only mode: no implementation performed.

### 1) Scope and intent
- Refactors template PDF storage from embedded `Data` into a disk-backed file (`pdfFilePath`) with migration from legacy data.
- Adds/extends messaging/template rendering and mail draft persistence to support mail sending flows.
- Improves mapping UX (hide already-used CSV columns in pickers with an explicit toggle to show them).
- Introduces an “Auto Map” capability (Pro-only in release builds; Dev-only in DEBUG) that suggests mappings based on column/field names.
- Adds PR workflow tooling (VS Code tasks + scripts + templates) and updates sample assets/tests.

### 2) Risk inventory (choose what applies)
- Data integrity / migrations
  - Template migration now depends on file IO; failure paths are largely silent (`try?`) and may leave templates partially usable (template exists but PDF missing).
- Backward compatibility / availability gating
  - StoreKit / mail availability gating must remain correct for iOS 16+ and Simulator.
- UI/UX regression risk
  - Mapping picker filtering can surprise users if the needed column “disappears” (mitigated by the new toggle).
- Error handling & logging (avoid swallowed failures)
  - Storage migration and file writes catch/print errors in some spots, but many failure paths remain quiet.
- Build/CI / target membership / packaging
  - New scripts/templates + Xcode project changes can introduce CI drift if paths/permissions differ.

### 3) Findings summary (High / Medium / Low)
| Severity | Area | Finding |
|---|---|---|
| High | Product rules / UX | “Auto Map” in release builds conflicts with the v1 rule that mapping must be manual (no suggestions / auto-generation). |
| High | Data integrity | Persisting the template PDF location as an **absolute** sandbox path (`pdfFilePath: String`) is likely to break after device restore / reinstall, causing “template exists but PDF missing.” |
| Medium | Migration robustness | Migration/write paths use `try?` and don’t surface failures to the UI; this can create confusing partial states. |
| Low | Code hygiene | Some storage helpers use `[0]` indexing for documents directory; low risk but technically unsafe if the array were empty. |

### 4) Decision required (if applicable)
- Do we want **any** form of mapping suggestions/auto-mapping in v1? If yes, the authority doc rule must be explicitly revised (and likely the product promise adjusted). If no, the Auto Map UI/behavior must be removed from non-DEBUG builds.
- Should templates be portable across restore/reinstall? If yes (strongly recommended), store a **relative** path/filename (or derive from `templateID`) rather than an absolute sandbox path.

### 5) Required changes (blocking)

1) Remove or fully DEBUG-gate “Auto Map” to comply with v1 “manual mapping only”
- Why it matters (impact)
  - The current shipped UI says it “suggests mappings,” which is directly disallowed by the highest-priority rules doc. This is a product/behavior contract issue.
- Exact fix guidance
  - Option A (recommended for v1): remove the release-build “Auto Map” toolbar button entirely, and keep any experimentation behind `#if DEBUG` only.
  - Option B: if product explicitly changes direction, update `.github/copilot-instructions.md` (and `LIVING_PROJECT_DOC.md`) to allow suggestions/auto-map and add explicit UX/undo constraints.
- Anchors
  - `.github/copilot-instructions.md`: “Core Behavior Requirements” → “**Mapping:** always manual; never auto-generate fields or mapping suggestions” (~L27–L35)
  - `PDFPacketBuilder/Views/MapView.swift`: `MapView.body.toolbar` “Auto Map” button + confirm alert (~L170–L220)
  - `PDFPacketBuilder/Views/MapView.swift`: `MapView.autoMap(_:allowWhenNotPro:)` uses `AutoMapper.suggest(...)` (~L360–L410)

2) Make template PDF references portable (avoid absolute sandbox paths)
- Why it matters (impact)
  - Absolute paths typically change across reinstall/restore (container UUID changes). Restoring `UserDefaults` with an old `pdfFilePath` can yield a template record that can’t load its PDF.
- Exact fix guidance
  - Store one of:
    - a relative path (e.g., `Templates/<uuid>.pdf`),
    - or a filename + reconstruct URL under the app’s documents directory,
    - or store nothing and deterministically derive the location from `template.id`.
  - Update `StorageService.saveTemplatePDF` to return the chosen portable identifier, and update `loadTemplatePDF` / migration to resolve it to a URL at runtime.
- Anchors
  - `PDFPacketBuilder/Models/PDFTemplate.swift`: `var pdfFilePath: String?` and custom `Codable` encoding/decoding (~L19–L98)
  - `PDFPacketBuilder/Services/StorageService.swift`: `saveTemplatePDF(data:templateID:)` returns `url.path` and `loadTemplate()` migration persists it (~L20–L120)

### 6) Approval criteria
- [ ] Fastlane unit tests pass.
- [ ] Mapping policy is consistent with `.github/copilot-instructions.md` (either Auto Map removed from release builds or the rule is explicitly revised).
- [ ] Template migration is validated end-to-end:
  - [ ] Existing users with legacy embedded PDF data successfully migrate to disk-backed storage.
  - [ ] Fresh imports save/load correctly.
  - [ ] (Recommended) Restore/reinstall scenario does not break template access.
- [ ] Required manual flow from `.github/copilot-instructions.md` is verified on Simulator/device:
  - Import PDF → Import CSV → manual map → generate → share complete/cancel logging → mail sent/cancel logging → replace template behavior (free) → export logs CSV.

### 7) File‑by‑file notes

- `.gitignore`
  - Looks like routine repo hygiene; no functional app impact.

- `.vscode/pr_check_prompt_template.md`, `.vscode/pr_check_prompt_template_edits.md`, `.vscode/pr_fix_prompt_template.md`
  - Workflow templates; fine. Ensure wording matches current repo rules.

- `.vscode/pr_check_start.sh`, `.vscode/pr_handoff_from_clipboard.sh`, `.vscode/pr_reply_create.sh`
  - Helpful workflow automation. Confirm executable bits are preserved in repo/CI.

- `.vscode/tasks.json`
  - Adds tasks for PR workflow + fastlane; OK.

- `LIVING_PROJECT_DOC.md`
  - Ensure it stays aligned with the v1 “manual mapping only” policy.

- `PDF-Packet-Builder.code-workspace`
  - Workspace plumbing; OK.

- `PDFPacketBuilder.xcodeproj/project.pbxproj`, `PDFPacketBuilder.xcodeproj/xcshareddata/xcschemes/PDFPacketBuilder.xcscheme`
  - Project config changes: verify target membership of new/renamed files and that schemes still build on CI.

- `PDFPacketBuilder/IAP/IAPManager.swift`
  - IAP plumbing; verify Pro gating matches the product ID and entitlement persistence is stable.

- `PDFPacketBuilder/Models/AppState.swift`
  - Central state/migration logic; watch for accidental state divergence with `UserDefaults` + file IO.

- `PDFPacketBuilder/Models/MailDraft.swift`
  - Draft persistence for mail flow; confirm drafts clear only on successful send/share.

- `PDFPacketBuilder/Models/MessageTemplate.swift`
  - Template model; ensure defaults don’t introduce UI copy issues.

- `PDFPacketBuilder/Models/PDFTemplate.swift`
  - Disk-backed template PDF; portability/migration concerns noted above.

- `PDFPacketBuilder/Models/SendLog.swift`
  - Log schema: ensure it supports required retention rules (free vs pro).

- `PDFPacketBuilder/Resources/SampleRecipients.csv`, `PDFPacketBuilder/Resources/SampleTemplate.pdf`
  - Sample assets; ensure these are only used for demo/quick start and not mistaken for user data.

- `PDFPacketBuilder/Services/CSVService.swift`
  - CSV parsing: confirm quoted fields / LF/CRLF / missing values behavior remains correct.

- `PDFPacketBuilder/Services/PDFService.swift`
  - PDF field extraction/fill: ensure only AcroForm text fields are supported in v1.

- `PDFPacketBuilder/Services/StorageService.swift`
  - UserDefaults + file IO + migration; primary risk area.

- `PDFPacketBuilder/Utils/CursorAwareTextFields.swift`
  - UI utility; low risk.

- `PDFPacketBuilder/Utils/MailComposer.swift`
  - Mail availability gating and DEBUG simulator look correct; verify it doesn’t log on cancel.

- `PDFPacketBuilder/Utils/MessageTemplateRenderer.swift`
  - Token rendering: ensure unknown tokens don’t crash and escaping behavior is correct.

- `PDFPacketBuilder/Utils/NameNormalization.swift`, `PDFPacketBuilder/Utils/NameScoring.swift`
  - Heuristics; if kept, ensure it doesn’t violate v1 “no suggestions” policy in release UI.

- `PDFPacketBuilder/Utils/SampleAssets.swift`
  - Sample asset loader; OK.

- `PDFPacketBuilder/Utils/ZipWriter.swift`
  - Zip export; ensure exported logs appear in Files and open cleanly.

- `PDFPacketBuilder/Views/CSVImportPreviewView.swift`, `PDFPacketBuilder/Views/CSVImporterView.swift`
  - CSV import UI; verify import doesn’t crash on malformed lines.

- `PDFPacketBuilder/Views/ContentView.swift`
  - Navigation/flow; ensure state resets don’t break existing flows.

- `PDFPacketBuilder/Views/GenerateView.swift`
  - Logging rules look compliant: share logs only on `completed == true`, mail logs only on `.sent`, mail unavailable shows alert.

- `PDFPacketBuilder/Views/HowToUseView.swift`, `PDFPacketBuilder/Views/QuickStartView.swift`
  - Help UI; verify no marketing-y copy and that paths still match actual screens.

- `PDFPacketBuilder/Views/MapView.swift`
  - Mapping UX improvements are good; Auto Map policy conflict noted above.

- `PDFPacketBuilder/Views/PDFPreviewView.swift`
  - PDF preview refactor; confirm memory usage on large PDFs.

- `PDFPacketBuilder/Views/RecipientsView.swift`
  - Recipient list + selection; ensure free-tier limits are enforced.

- `PDFPacketBuilder/Views/SettingsView.swift`
  - Pro gating + debug toggles; ensure debug-only switches are behind `#if DEBUG`.

- `PDFPacketBuilder/Views/TemplateView.swift`
  - Template import/replace behavior; verify free-tier “replace resets mapping/logs” flow.

- `PDFPacketBuilderTests/CSVServiceTests.swift`, `PDFPacketBuilderTests/MessageTemplateRendererTests.swift`, `PDFPacketBuilderTests/RecipientTests.swift`, `PDFPacketBuilderTests/StorageMigrationTests.swift`
  - Good coverage areas; ensure migration tests also cover path portability if you adopt relative paths.

- `docs/reviews/.gitkeep`, `docs/reviews/PR_REPLY_20251230-2231_pr-22_need-to-pull-and-review.md`, `docs/reviews/PR_REVIEW_2025-12-30_pr-22_please-review.md`
  - Historical artifacts; OK.

- `fastlane/Fastfile`
  - CI lane changes: ensure test lane reliably runs tests (not just build) on Simulator.

- `pr-edits/ENABLE_Portable_PR_Check_SingleFile.md`
  - Docs; OK.

- `scripts/pr-check/*`
  - Workflow automation; ensure these don’t assume GNU coreutils.

- `v1 Audit & Improvements SPEC.md`
  - Spec doc; ensure it matches product rules.

### 8) Concrete suggested edits

A) DEBUG-gate “Auto Map” (keep v1 manual-only)

```diff
--- a/PDFPacketBuilder/Views/MapView.swift
+++ b/PDFPacketBuilder/Views/MapView.swift
@@
-                        ToolbarItem(placement: .navigationBarLeading) {
-                            if iapManager.isProUnlocked {
-                                Button("Auto Map") {
-                                    showingAutoMapConfirm = true
-                                }
-                                .disabled(template.fields.isEmpty || appState.csvImport == nil)
-                            } else {
-#if DEBUG
-                                Button("Auto Map (Dev)") {
-                                    autoMap(template, allowWhenNotPro: true)
-                                }
-                                .disabled(template.fields.isEmpty || appState.csvImport == nil)
-#else
-                                EmptyView()
-#endif
-                            }
-                        }
+                        ToolbarItem(placement: .navigationBarLeading) {
+#if DEBUG
+                            Button("Auto Map (Dev)") {
+                                autoMap(template, allowWhenNotPro: true)
+                            }
+                            .disabled(template.fields.isEmpty || appState.csvImport == nil)
+#else
+                            EmptyView()
+#endif
+                        }
```

B) Store template PDF location portably (relative path or deterministic filename)

```diff
--- a/PDFPacketBuilder/Services/StorageService.swift
+++ b/PDFPacketBuilder/Services/StorageService.swift
@@
-    func saveTemplatePDF(data: Data, templateID: UUID) -> String? {
+    func saveTemplatePDF(data: Data, templateID: UUID) -> String? {
         let filename = "\(templateID.uuidString).pdf"
-        let url = getTemplatesDirectory().appendingPathComponent(filename)
+        let url = getTemplatesDirectory().appendingPathComponent(filename)
         do {
             try data.write(to: url, options: [.atomic])
-            return url.path
+            return "Templates/\(filename)" // relative
         } catch {
             print("Error saving template PDF to disk: \(error)")
             return nil
         }
     }
@@
-    func loadTemplatePDF(from path: String) -> Data? {
-        let url = URL(fileURLWithPath: path)
+    func loadTemplatePDF(from path: String) -> Data? {
+        // Resolve relative path under documents.
+        let url = path.hasPrefix("/")
+            ? URL(fileURLWithPath: path)
+            : getDocumentsDirectory().appendingPathComponent(path)
         return try? Data(contentsOf: url)
     }
```

(You’d also update `PDFTemplate` naming (`pdfFilePath` → `pdfRelativePath`) and migration to write/read the new format.)

### 9) Most likely future bugs (1–3)

1) “My template is there but it won’t open / fields are empty” after restore/reinstall
- Symptom in production
  - Template record loads, but PDF preview/generation fails; user sees missing PDF errors.
- Root cause hypothesis
  - `pdfFilePath` stored as absolute sandbox path becomes invalid after container path changes.
- Guardrails
  - Store relative paths; add a migration to repair absolute paths; add a test simulating a changed documents directory prefix.

2) Silent migration/write failures create partial states
- Symptom in production
  - After updating, templates/CSV imports intermittently “disappear” with no user-visible reason.
- Root cause hypothesis
  - `try?` directory creation or file IO failures are ignored; app continues with nil data.
- Guardrails
  - Surface a one-time alert/toast when migration fails; add logging with enough context to debug.

3) Auto-mapping creates user trust issues (wrong mappings)
- Symptom in production
  - Users generate PDFs with swapped fields (e.g., last name in first name).
- Root cause hypothesis
  - Name-scoring heuristics are imperfect, especially with ambiguous headers.
- Guardrails
  - Keep v1 manual-only; if reintroduced later, make it “suggest only” (no auto-apply), show confidence, and require explicit user confirmation per field.

### 10) Copy/paste PR reply (final block)

**Decision:** Request changes (blocking)

**Risk:** High

**Required actions:**
- Remove or DEBUG-gate the release-build “Auto Map” UI/behavior to comply with v1 manual mapping rules.
- Make template PDF storage portable by avoiding absolute sandbox paths (store relative path/filename or derive deterministically).
- Add/extend migration tests to cover the new portable path format and failure handling.

**Verification:**
- ✅ Fastlane tests: `Executed 44 tests, with 0 failures`.
- Please still manually verify the v1 end-to-end flow from `.github/copilot-instructions.md` (import → map → generate → share/mail logging → replace template → export logs).
