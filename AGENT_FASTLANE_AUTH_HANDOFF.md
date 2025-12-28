# Fastlane Auth + VS Code Tasks — Agent Handoff (Standard Pattern)

**Audience:** coding agent working in a *different* iOS workspace.

**Goal:** replicate the StrideLog-style Fastlane setup:
- Use **App Store Connect API key** for TestFlight + ASC API queries.
- Use **Apple ID auth** (app-specific password / session) for `deliver` by default.
- Standardize the processing-wait flag to **`WAIT_FOR_PROCESSING=1`** (no app prefix).

This doc is written as implementation instructions. Follow it literally unless the “Questions to verify” section indicates you must stop and ask the user.

---

## 0) What StrideLog does (reference behavior)

StrideLog’s `fastlane/Fastfile` pattern:

1) **TestFlight / ASC API:**
- `maybe_setup_api_key` checks for `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.
- If present, it calls `app_store_connect_api_key(...)`.
- Used for:
  - `upload_to_testflight`
  - `latest_testflight_build_number`
  - `list_testflight_builds`

2) **Deliver (metadata/review submission):**
- Default behavior is Apple ID auth (to avoid API key permission issues).
- Optional override: set `DELIVER_USE_API_KEY=1` to force API key auth for deliver.

3) **Processing wait:**
- In StrideLog repo, wait was app-prefixed.
- **For the new repo, standardize to `WAIT_FOR_PROCESSING=1`.**

---

## 1) Environment variable contract (new repo)

### 1.1 App Store Connect API key (preferred for TestFlight)
The repo must support these env vars:

- `ASC_KEY_ID` (e.g. `ABC123DEFG`)
- `ASC_ISSUER_ID` (UUID)
- `ASC_KEY_PATH` (absolute path to `.p8`)

**Rule:** the `.p8` file must live **outside** the repo.

Recommended location:
- `$HOME/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`

Permissions:
- `chmod 600 "$ASC_KEY_PATH"`

### 1.2 Apple ID auth (default for deliver)
For deliver actions (metadata / submission), default to Apple ID auth.

Support env vars:
- `FASTLANE_USER`
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`

Optional:
- `FASTLANE_SESSION` (only if the user prefers session auth)

### 1.3 Standard wait flag
Standardize this across repos:
- `WAIT_FOR_PROCESSING=1`

This should control `skip_waiting_for_build_processing` in `upload_to_testflight`.

---

## 2) Required files to add in the new repo

### 2.1 `.envrc.example` (commit)
Create a committed `.envrc.example` that is safe.

It may include `ASC_KEY_ID` and `ASC_ISSUER_ID` *if the user is OK with committing those identifiers*.

It must include an `ASC_KEY_PATH` template like:
- `export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"`

Also include (commented out):
- `# export WAIT_FOR_PROCESSING="1"`
- `# export DELIVER_USE_API_KEY="1"`

### 2.2 `.envrc` (local only)
User creates `.envrc` locally from the example and runs `direnv allow`.

### 2.3 `.vscode/tasks.json`
Add VS Code tasks that run Fastlane via Bundler, prefixed with direnv:
- `eval "$(direnv export zsh)" && bundle exec fastlane <lane>`

**Critical:** update “wait” tasks to use `WAIT_FOR_PROCESSING=1`.

---

## 3) Fastfile requirements (new repo)

### 3.1 Provide `maybe_setup_api_key`
Implement a private lane that:
- reads `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`
- calls `app_store_connect_api_key(...)` when present
- otherwise logs that Apple ID auth will be used

### 3.2 Provide `maybe_setup_api_key_for_deliver`
Implement:
- default: Apple ID auth
- if `DELIVER_USE_API_KEY == "1"` then call `maybe_setup_api_key`

### 3.3 Implement `beta` processing wait using `WAIT_FOR_PROCESSING`
In the `beta` lane:
- determine `wait_processing = ENV['WAIT_FOR_PROCESSING'] == '1'`
- call:
  - `upload_to_testflight(skip_waiting_for_build_processing: !wait_processing, ...)`

### 3.4 Lane naming
Prefer consistent lanes across repos:
- `tests`
- `beta`
- `tf_status`
- `tf_list_all`
- `upload_metadata`
- `release`
- `release_full`
- `archive`

---

## 4) Minimal VS Code tasks the new repo should have

Create tasks that call these lanes:
- `bundle exec fastlane tests`
- `bundle exec fastlane beta`
- `WAIT_FOR_PROCESSING=1 bundle exec fastlane beta`
- `bundle exec fastlane tf_status`
- `bundle exec fastlane tf_list_all`
- `bundle exec fastlane upload_metadata`
- `bundle exec fastlane release`
- `bundle exec fastlane release_full`

Optional:
- External TF distribution: `bundle exec fastlane pilot distribute ...`

---

## 5) Questions the agent MUST verify with the user before proceeding

Stop and ask these questions (do not guess):

1) **Do you already have an App Store Connect API key for this app/account?**
   - If yes, provide:
     - `ASC_KEY_ID`
     - `ASC_ISSUER_ID`
     - confirm where the `.p8` file is stored locally
   - If no, confirm whether the user wants to:
     - create a new key now, or
     - proceed temporarily with Apple ID auth only (slower + session/app-password requirements)

2) **Confirm the `.p8` local path convention**
   - Should we standardize on:
     - `$HOME/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8`?

3) **Deliver auth choice**
   - Confirm: default to Apple ID auth for `deliver`?
   - Will the user supply:
     - `FASTLANE_USER` + `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` (preferred), or
     - `FASTLANE_SESSION`?

4) **Project-specific build settings needed for `build_app`**
   - What are the correct values for:
     - Xcode project/workspace path
     - scheme name
     - bundle identifier
     - Development Team ID (if you pass `DEVELOPMENT_TEAM=` in `xcargs`)

5) **Build number strategy**
   - Should the new repo use:
     - agvtool, CFBundleVersion, or remote-driven bump (TestFlight compare)?

6) **Lane scope**
   - Does the new repo need:
     - TestFlight upload only,
     - metadata upload,
     - App Store submission (`release`), or
     - external TestFlight distribution via `pilot distribute`?

7) **Waiting behavior standard**
   - Confirm the standardized flag is exactly:
     - `WAIT_FOR_PROCESSING=1`
   - Should the VS Code task be the canonical way to enable it (recommended)?
