# Copilot Instructions — PDF Packet Builder (v1, iOS 16+)

## Product Promise
Build and send personalized **fillable AcroForm PDFs** from a CSV list, log sends **only after confirmed delivery actions**, and export logs as CSV. Offline-first. No backend.

## Pricing
- App price: **$9.99 one-time purchase**
- IAP (non-consumable):
  - Product ID: **`com.yancmo.pdfpacketbuilder.pro.unlock`**
  - Removes Free tier limits

## v1 Rules (Free vs Paid)
**Free tier**
- 1 active PDF template at a time (replacement allowed)
- Max 10 recipients per batch
- Keep only 7 days of send logs internally
- Never delete user-saved PDF files in the device **Files app**

**Paid unlock removes limits**
- Unlimited templates
- Unlimited recipients
- Full log history + CSV export retention

## Core Behavior Requirements
- **Share sheet:** log only if `completed == true`
- **Mail composer:** log only if result is `.sent`
- **If Mail unavailable:** show alert and do not log
- **Mapping:** always manual; never auto-generate fields or mapping suggestions
- **PDF support:** AcroForm text fields only in v1
- **CSV support:** commas, quoted fields, mixed `LF/CRLF`, missing values without crash

## Current Objective
Ensure the Template and Recipients screens work cleanly on simulator/device, and IAP plumbing is minimal and stable.

## PR/Test Requirements for every change
Test this exact flow:
1. Import fillable PDF
2. Import CSV
3. Map CSV columns to PDF fields
4. Generate 1:1 PDFs to Files
5. Share 1 PDF → complete → log appears
6. Share 1 PDF → cancel → no log
7. Mail 1 PDF → send → log appears
8. Mail 1 PDF → cancel → no log
9. Replace template → confirm → mapping/logs reset (free only)
10. Export Logs → CSV appears in Files and opens cleanly

## Anti-Patterns to avoid in shipping code
- No long comments, narration, or inspirational text
- No force unwraps (`!`) without optional binding
- No new build systems or dependencies unless required
- No emojis or marketing adjectives in UI text

Keep implementation simple, human-structured, and App Store compliant.