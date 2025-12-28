# Fastlane + VS Code Guide (Drop-in)

This file is meant to be copied into **any iOS app repo** to standardize how you run Fastlane locally and via VS Code Tasks.

It assumes:
- You run Fastlane via **Bundler** (`bundle exec fastlane ...`) so everyone uses the same Fastlane version.
- You authenticate to App Store Connect using an **App Store Connect API key** (preferred), or fall back to Apple ID session when needed.

---

## What to keep in every repo

### 1) `Gemfile`
Pin Fastlane so it’s reproducible across machines.

Recommended minimal `Gemfile`:
- `source "https://rubygems.org"`
- `gem "fastlane", "~> 2.x"`

Then install:
- `bundle install`

### 2) `fastlane/` folder
Typical files:
- `fastlane/Fastfile` — lanes you actually run (beta, tests, release, etc)
- `fastlane/Appfile` — app identifier / Apple ID info (optional when using API key)
- `fastlane/metadata/` — App Store metadata (optional)

### 3) `.vscode/tasks.json`
Add Tasks so anyone can run:
- upload to TestFlight
- check TestFlight status
- run tests
- upload metadata
- submit for App Store review

A copy/paste template is included below.

---

## Authentication (App Store Connect) ✅

### Preferred: App Store Connect API key
Create an App Store Connect API key in App Store Connect (Users and Access → Keys).

Set these environment variables:
- `ASC_KEY_ID` — Key ID (e.g. `ABC123DEFG`)
- `ASC_ISSUER_ID` — Issuer ID (UUID)
- `ASC_KEY_PATH` — absolute path to the `.p8` file on your machine

**Keep the `.p8` outside the repo** (e.g. `$HOME/.appstoreconnect/private_keys/`).

### Optional (legacy fallback): Apple ID session / app-specific password
If you don’t use an API key, Fastlane may require:
- `FASTLANE_USER`
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`
- or a `FASTLANE_SESSION`

API key auth is strongly recommended because it avoids session expiry drama.

---

## Environment management (recommended) — `direnv`

If you use `direnv`, commit a safe example file and keep secrets local.

1) Copy an example into place:
- copy `.envrc.example` → `.envrc`

2) Allow it:
- `direnv allow`

3) In VS Code Tasks, prefix commands with:
- `eval "$(direnv export zsh)" && ...`

If you don’t use `direnv`, remove that prefix from tasks and export vars another way.

### `.envrc.example` template
Create this in each repo (safe to commit **without** secrets beyond IDs):
- `ASC_KEY_ID="..."`
- `ASC_ISSUER_ID="..."`
- `ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8"`

---

## Common lanes (suggested standard)

These are lane names that tend to work well across projects:

### `fastlane tests`
- Runs unit/UI tests via `scan`.

### `fastlane beta`
- Builds + uploads to TestFlight.
- Optional env var for waiting on processing:
  - `WAIT_FOR_PROCESSING=1` (name is up to you; standardize it in your Fastfile)

### `fastlane tf_status`
- Prints latest processed build info.

### `fastlane upload_metadata`
- Uploads metadata/screenshots to App Store Connect (no binary upload).

### `fastlane release`
- Submits the latest build for App Store review (usually using `deliver`).

### `fastlane release_full`
- Upload metadata/screenshots and submit for review in one go.

> Tip: Keep lane behavior consistent repo-to-repo even if the underlying build system differs (XcodeGen, Xcodeproj, workspace, etc).

---

## VS Code Tasks (copy/paste)

Add (or merge) the following into `.vscode/tasks.json`.

Notes:
- These tasks assume Bundler: `bundle exec fastlane ...`
- These tasks assume `direnv` is used to load `ASC_*` env vars.
- If you *don’t* use `direnv`, delete the `eval "$(direnv export zsh)" &&` prefix.

**Template tasks** (JSONC):

- `Fastlane: Beta Upload`
- `Fastlane: TestFlight Status`
- `Fastlane: Tests`
- `Fastlane: Upload Metadata & Screenshots`
- `Fastlane: Submit for App Store Review`
- `Fastlane: Full App Store Submission`

(Recommended) include a meta-task:
- `Fastlane: Beta External (Upload + Submit)` using `dependsOn`.

If you already have non-Fastlane tasks (deploy scripts, etc.), keep them alongside these.

---

## Minimal Fastfile patterns (high level)

A portable pattern that works well:

1) `maybe_setup_api_key` private lane
- If `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH` exist → call `app_store_connect_api_key(...)`.
- Otherwise print a message and continue (Apple ID auth fallback).

2) Build number strategy
Pick one per repo and document it:
- Xcode “Current Project Version” (agvtool)
- Info.plist `CFBundleVersion`
- XcodeGen `project.yml` as source-of-truth
- “remote-driven” (compare local build vs latest TestFlight build and bump accordingly)

3) `beta` lane
- build
- upload_to_testflight
- optional wait flag driven by env var

---

## Troubleshooting

### `bundle exec fastlane` fails with Ruby errors
- Ensure you’re using a modern Ruby (via `rbenv`, `asdf`, or `ruby-install`).
- Re-run `bundle install`.

### TestFlight upload auth issues
- Prefer API key auth (ASC vars).
- If using Apple ID auth, sessions expire; refresh the session or switch to API keys.

### Xcode signing issues
- For local builds, you may need:
  - Automatic signing enabled
  - `-allowProvisioningUpdates`
  - correct `DEVELOPMENT_TEAM`

### Processing wait takes forever
- Waiting on processing can take a while (minutes to an hour). Keep the wait optional via an env var.

---

## Suggested repo checklist

- [ ] `Gemfile` pins fastlane
- [ ] `bundle install` works cleanly
- [ ] `fastlane/Fastfile` has lanes: `tests`, `beta`, `tf_status`, `upload_metadata`, `release`, `release_full`
- [ ] `.envrc.example` exists and is safe to commit
- [ ] `.vscode/tasks.json` includes the Fastlane tasks
