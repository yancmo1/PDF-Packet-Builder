# PR Review — PR #22 — Please review

**Date:** 2025-12-30  
**Repo:** yancmo1/PDF-Packet-Builder  
**PR:** #22  
**Branch (local):** `feature/v1-storage-refactor-CO-4.5`  

## Scope and intent

From the diff against `origin/main`, this PR bundles several workstreams:

1) **Template storage refactor + migration**
- `PDFTemplate` moves from embedded `pdfData` to a disk-backed `pdfFilePath` with migration support.
- `StorageService` writes template PDFs under `Documents/Templates/` and migrates legacy embedded data on load.

2) **Messaging + export enhancements**
- Adds `MessageTemplate` model, token rendering (`MessageTemplateRenderer`), message editing UI in `GenerateView`, and per-recipient `Message.txt` generation.
- Adds “Export Folder” and zips the export via a custom `ZipWriter`.

3) **Onboarding/sample content**
- Adds `QuickStartView`, `HowToUseView`, and bundled sample PDF/CSV + “Load Sample …” actions.

4) **Quality-of-life / reliability**
- Normalizes CSV line endings.
- Reworks `PDFPreviewView` into a `UIViewControllerRepresentable` to reduce blank-PDF behavior.

5) **Tooling / docs / Fastlane**
- Adds portable PR-check workflow docs.
- Adds TestFlight changelog support in `fastlane/Fastfile` and ignores the changelog file.

Net: this is significantly larger than “storage refactor” alone.

## Findings summary (High / Medium / Low)

### High
- **Violates v1 rule: “Mapping always manual; never auto-generate fields or mapping suggestions.”**
  - `MapView` calls `applyAutoMappingIfNeeded` and uses `AutoMapper.suggest(...)` to auto-populate mappings.
  - This conflicts directly with `.github/copilot-instructions.md` (highest authority in this repo after system).

- **Shipping code uses `try!` force unwrap** in `MessageTemplateRenderer`.
  - Repo guidance explicitly says: “No force unwraps (`!`) without optional binding.”

- **Bundled sample CSV includes a real email address** (`yancmo@gmail.com`).
  - This is risky for a public repo and for demo/testing. Use `example.com` addresses.

### Medium
- **Scope creep / reviewability**: storage refactor + onboarding + message templates + zip export + fastlane changelog + docs in one PR makes regression risk and review time higher.
- **Testing isolation**: new unit tests exist, but `StorageMigrationTests` appears to instantiate `StorageService()` which uses `UserDefaults.standard` and the real filesystem. This can cause flaky tests and cross-test interference.
- **Disk path strategy**: `pdfFilePath` stores an absolute path. Storing a *relative* path (or filename) is more robust across container path changes.

### Low
- **Performance nit**: `PDFTemplate.pdfData` reads from disk each access (fine for v1, but worth noting if previews re-render frequently).
- **ZipWriter is “store only” (no compression)**: acceptable, but exported ZIPs will be larger than necessary.

## Decision required (if applicable)

1) **Do we want this PR to include Message Template + onboarding + export ZIP + fastlane changelog + docs?**
   - If not, I recommend splitting:
     - PR A: storage refactor + migration + tests
     - PR B: message template + export bundle
     - PR C: quick start + sample assets
     - PR D: fastlane changelog + docs tooling

2) **Mapping policy decision**
   - Authority doc says “manual only; no mapping suggestions.”
   - Current `MapView` behavior contradicts that.

## Required changes

1) **Remove all auto-mapping / suggestion behavior.**
   - `MapView` must not apply suggestions automatically or via “smart” logic.
   - If the intent is to keep the code for a future version, it should be removed from v1 or completely gated behind a future feature flag that is *off and not present in UI*. However, the authority doc currently says “never,” so simplest is to remove.

2) **Remove `try!` in shipping code** (`MessageTemplateRenderer`).

3) **Replace real emails in `SampleRecipients.csv` with `example.com`**.

4) **Align docs with the manual-mapping rule**
   - `LIVING_PROJECT_DOC.md` currently documents auto-suggestions in MapView; this conflicts with the v1 rule.

## Approval criteria

I would approve once all of these are true:

- No auto-mapping/suggestions are performed anywhere (including `MapView`).
- No force unwraps in shipping code introduced by this PR (specifically remove `try!`).
- Sample assets contain no real personal data.
- Manual flow still passes the required test path from `.github/copilot-instructions.md`:
  1) Import fillable PDF
  2) Import CSV
  3) Map CSV columns to PDF fields (manual)
  4) Generate 1:1 PDFs to Files
  5) Share complete → log appears
  6) Share cancel → no log
  7) Mail sent → log appears
  8) Mail cancel → no log
  9) Replace template → mapping/logs reset (free only)
  10) Export logs → CSV opens cleanly

## File-by-file notes

Changed files in this PR (per `git diff --name-only origin/main...HEAD`):

- `.gitignore`
  - Adds ignores for `prd-specs-changes/`, `fastlane/testflight_changelog.txt`, and `checkpoint.diff`. Good hygiene.

- `LIVING_PROJECT_DOC.md`
  - Adds “Smart Mapping Heuristics (Future)” placeholder and Message Template documentation.
  - **Needs to remove/adjust any statements implying auto-mapping is active/allowed in v1** (conflicts with v1 rule).

- `PDFPacketBuilder/Models/PDFTemplate.swift`
  - Good direction: disk-backed template PDF with migration.
  - Consider storing *relative* path (`Templates/<uuid>.pdf`) instead of absolute.

- `PDFPacketBuilder/Services/StorageService.swift`
  - Moves template PDF storage to disk and performs migration on load.
  - Good: avoids re-encoding large blobs to `UserDefaults`.
  - Consider Application Support instead of Documents if you don’t want these files visible via device file sharing (not a blocker).

- `PDFPacketBuilder/Models/AppState.swift`
  - Renames email/name column selections and adds sender name/email persistence.

- `PDFPacketBuilder/Models/MessageTemplate.swift`
  - Straightforward and sane v1 model.

- `PDFPacketBuilder/Utils/MessageTemplateRenderer.swift`
  - Logic is reasonable.
  - **Must remove `try!`**.

- `PDFPacketBuilder/Views/GenerateView.swift`
  - Major expansion: message template editing, token insertion, preview, export folder+zip, preview sheet, mail subject/body.
  - Logging behavior remains correct (share `completed == true`, mail `.sent`).
  - Note: file is now very large (1350 LOC) and should likely be split later.

- `PDFPacketBuilder/Views/MapView.swift`
  - **Blocking:** auto mapping is applied on appear and on CSV change.

- `PDFPacketBuilder/Utils/ZipWriter.swift`
  - Custom ZIP writer uses store-only entries and a data descriptor.
  - Looks careful about ZIP64 overflow. Nice.

- `PDFPacketBuilder/Resources/SampleRecipients.csv`
  - **Contains real email addresses** → change to `example.com`.

- `PDFPacketBuilder/Resources/SampleTemplate.pdf`
  - Bundled sample PDF. OK.

- `PDFPacketBuilder/Utils/SampleAssets.swift`
  - Simple loader; fine.

- `PDFPacketBuilder/Utils/CursorAwareTextFields.swift`
  - Useful for token insertion.

- `PDFPacketBuilder/Utils/MailComposer.swift`
  - Adds body support + debug mail simulator. Debug-only gate looks correct.

- `PDFPacketBuilder/Views/SettingsView.swift`
  - Adds Sender settings and Help entry points.

- `PDFPacketBuilder/Views/TemplateView.swift`, `RecipientsView.swift`
  - Adds “Load Sample …” actions (good for first-run success).

- `PDFPacketBuilder/Services/CSVService.swift`
  - Normalizes line endings (good; required by v1 rules).

- `PDFPacketBuilder/Views/PDFPreviewView.swift`
  - UIViewController wrapper + delayed scaling; addresses common PDFKit blank-render issues.

- `PDFPacketBuilderTests/*`
  - Adds unit tests: good direction.
  - Recommend injecting storage dependencies for stronger isolation.

- `docs/ENABLE_Portable_PR_Check_Prompt.md`, `docs/Portable_PR_Check_Workflow_Spec.md`
  - Helpful internal tooling docs.

- `fastlane/Fastfile`
  - Adds auto changelog generation and writes a local changelog file (gitignored). Reasonable.

- `v1 Audit & Improvements SPEC.md`
  - Large spec doc added/edited.

## Concrete suggested edits

### 1) Remove auto-mapping/suggestions from `MapView.swift` (required)

```diff
diff --git a/PDFPacketBuilder/Views/MapView.swift b/PDFPacketBuilder/Views/MapView.swift
index 0000000..0000000 100644
--- a/PDFPacketBuilder/Views/MapView.swift
+++ b/PDFPacketBuilder/Views/MapView.swift
@@
-                    .onAppear {
-                        fieldMappings = template.fieldMappings
-                        applyAutoMappingIfNeeded(template: template)
-                    }
-                    .onChange(of: appState.csvImport?.reference.localPath ?? "") { _ in
-                        applyAutoMappingIfNeeded(template: template)
-                    }
+                    .onAppear {
+                        fieldMappings = template.fieldMappings
+                    }
+                    .onChange(of: appState.csvImport?.reference.localPath ?? "") { _ in
+                        // v1 rule: mapping is always manual; do not auto-suggest.
+                    }
@@
-    private func applyAutoMappingIfNeeded(template: PDFTemplate) {
-        guard appState.csvImport != nil else { return }
-
-        let csvOptions = csvHeaderOptions()
-        let allCandidates = (computedOptions + builtInOptions + csvOptions)
-
-        var updated = fieldMappings
-        for field in template.fields {
-            let existing = updated[field.name] ?? ""
-            guard existing.isEmpty else { continue }
-
-            let normalizedPDF = field.normalized ?? NormalizedName.from(field.name)
-            if let suggestion = AutoMapper.suggest(pdfField: normalizedPDF, candidates: allCandidates) {
-                updated[field.name] = suggestion
-            }
-        }
-
-        // Only mutate state if something changed (prevents unnecessary UI churn).
-        if updated != fieldMappings {
-            fieldMappings = updated
-        }
-    }
+    // Intentionally no auto-mapping in v1.
```

If `AutoMapper`/`AutoMapping.swift` exists, it should also be removed from the build (or left unused) to prevent accidental future reintroduction.

### 2) Remove `try!` in `MessageTemplateRenderer.swift` (required)

```diff
diff --git a/PDFPacketBuilder/Utils/MessageTemplateRenderer.swift b/PDFPacketBuilder/Utils/MessageTemplateRenderer.swift
index 0000000..0000000 100644
--- a/PDFPacketBuilder/Utils/MessageTemplateRenderer.swift
+++ b/PDFPacketBuilder/Utils/MessageTemplateRenderer.swift
@@
-    private static let tokenRegex: NSRegularExpression = {
+    private static let tokenRegex: NSRegularExpression? = {
         let pattern = #"\{\{\s*([a-z0-9_]+)\s*\}\}"#
-        return try! NSRegularExpression(pattern: pattern, options: [])
+        return try? NSRegularExpression(pattern: pattern, options: [])
     }()
@@
-        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
+        guard let tokenRegex else { return [] }
+        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
@@
-        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
+        guard let tokenRegex else { return text }
+        let matches = tokenRegex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
```

### 3) Sanitize sample data in `SampleRecipients.csv` (required)

```diff
diff --git a/PDFPacketBuilder/Resources/SampleRecipients.csv b/PDFPacketBuilder/Resources/SampleRecipients.csv
index 0000000..0000000 100644
--- a/PDFPacketBuilder/Resources/SampleRecipients.csv
+++ b/PDFPacketBuilder/Resources/SampleRecipients.csv
@@
-StudentName,CoachName,TeamName,Date,ParentName,Email
-Alex Johnson,Coach Bob,Tigers,3/1/25,Mary Johnson,yancmo@gmail.com
+StudentName,CoachName,TeamName,Date,ParentName,Email
+Alex Johnson,Coach Bob,Tigers,3/1/25,Mary Johnson,parent1@example.com
@@
-Emma Rodriguez,Coach Bob,Tigers,3/1/25,Carlos Rodriguez,yancmo@gmail.com
+Emma Rodriguez,Coach Bob,Tigers,3/1/25,Carlos Rodriguez,parent2@example.com
@@
-... (repeat for all rows)
+... (repeat for all rows)
```

### 4) Align docs with v1 manual mapping rule (required)

In `LIVING_PROJECT_DOC.md`, remove/adjust any language that claims:
- “the app may apply conservative auto-suggestions”

and replace with:
- “Mapping is always manual in v1; no auto-suggestions.”

## Copy/paste PR reply

**Status:** Request changes

Thanks for the big push—this PR adds a lot of real value (disk-backed template storage + migration, message templates, export bundle/zip, onboarding/sample assets, and better PDF preview reliability).

However, I need a couple of v1 policy fixes before approval:

- **Required:** Mapping must remain strictly manual per `.github/copilot-instructions.md`. `MapView` currently auto-suggests mappings via `applyAutoMappingIfNeeded`/`AutoMapper`. Please remove all auto-mapping/suggestion behavior.
- **Required:** Remove the `try!` force unwrap in `MessageTemplateRenderer` (repo rule: no force unwraps in shipping code).
- **Required:** Replace real emails in `SampleRecipients.csv` with `example.com` addresses.
- **Required:** Update `LIVING_PROJECT_DOC.md` to remove/align any mention of auto-suggested mapping.

Optional (non-blocking): consider splitting this PR (storage refactor vs message templates/export vs onboarding vs fastlane/docs) to make review/regression risk lower.
