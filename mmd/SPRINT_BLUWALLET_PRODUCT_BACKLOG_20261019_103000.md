# Sprint: BluWallet product backlog (formerly BluPOS)

**Created:** 2026-10-19 10:30 EAT
**Status:** PENDING
**Rename:** BluPOS / expo_blupos_v5 is now **BluWallet**.
**Source:** BluWallet one-page solution doc, 2026-10-19

## Goal

Turn today's standalone Flask POS into BluWallet: an installed product that reconciles payments from any provider's confirmation SMS (official M-Pesa, banks, Saccos) without direct provider integration, and files the shop's taxes on eCitizen remotely. SMS reconciliation is the primary selling point.

## Built today vs upgrade

| Area | Built today (repo) | Upgrade |
| --- | --- | --- |
| Desktop delivery | Flask web app opened in a browser; setup script installs Python | Same Flask app bundled as an .exe, downloaded from the companion's setup page |
| Companion micro-server | Health, activation, SMS lists, local inventory | Also serves the setup and download page |
| Payment senders | Two hard-coded test shortcodes in the companion | Owner selects valid senders in desktop master settings |
| SMS parsing | Fixed checks for a few M-Pesa formats | Regex groups per provider + confidence scoring |
| Provider coverage | M-Pesa | M-Pesa, banks, Saccos, from a growing template database |
| Matching rule | Amount covers total; each payment used once | Same, plus transaction-code check (open) |
| Receipt printer | USB thermal on desktop; 58 mm Bluetooth in companion | Desktop: USB first, Bluetooth fallback, 57 and 80 mm |
| Checkout scanner | Works with checkout barcode scanners; camera scan in companion | No change |
| Cash drawer | Not supported | Desktop: kick via USB printer's drawer port, direct USB fallback |
| Tax filing | None | eCitizen filing via embedded RecordFlow, triggered from companion |

Pilot: a supermarket is testing today's build.

## Backlog

- [ ] **[INTERNAL] Bundle as .exe** — ship the Flask backend as one bundled executable (still Flask); retire `windows_setup.bat` / `setup.ps1` as the default path. `build_to_exe.ps1` points at a non-existent `BluPOS_Backend.py`.
- [ ] **[INTERNAL] Setup via companion** — companion micro-server serves a setup page opened in the PC browser; PC downloads the .exe from it and pairs.
- [ ] **[INTERNAL] Two modes** — kiosk mode (companion is the full POS, 57 mm Bluetooth printer, small kiosk owners) and desktop mode (.exe is the primary POS; companion becomes sales summary + payment processor). Both stay in development.
- [ ] **[INTERNAL] Sender selection in master settings** — owner selects valid inbound SMS sender addresses. Replaces hard-coded `approvedShortcodes = ['123456', '123457']` in `apk_section/blupos_wallet/lib/services/sms_service.dart`; companion pulls the list from the POS.
- [ ] **[INTERNAL] Regex groups per provider** — extract amount, reference, payer, time.
- [ ] **[INTERNAL] Intelligent scoring** — confidence score per parse (sender, format match, field checks); low scores route to the cashier.
- [ ] **[INTERNAL] Provider database** — store each new message format; template library for banks, Saccos, official M-Pesa.
- [ ] **[INTERNAL] Printers** — desktop: USB first, Bluetooth fallback, 57 and 80 mm. Kiosk: 57 mm Bluetooth.
- [ ] **[INTERNAL] Cash drawer** — desktop only. Primary: drawer on the printer's drawer port, ESC/POS drawer-kick sent through the USB printer. Fallback: direct USB drawer. Printer setup detects which is attached.
- [ ] **[EXPORT → sj-private-extension] eCitizen tax filing** — bake the RecordFlow engine (persistent Chrome profile, recorder → recipe, replay + screenshot, API-key webhook) into the desktop .exe. eCitizen routes only. Companion replaces the sj-private portal as the paired server; works whenever phone and desktop are paired, no other condition. POS fills recipe slots from its sales records; owner approves the screenshot before submit; first eCitizen login (OTP/captcha) done once at the desktop.
- [ ] **[INTERNAL] Rename** — BluPOS → BluWallet across app names, UI strings and docs.

## Open questions

- Provider database per shop, or synced across all installs?
- What score clears a sale automatically, and who approves a new provider template?
- Should reconciliation also match the M-Pesa transaction code, not only the amount?
- Remote filing off the shop network needs a relay between companion and desktop: which?

## Log

- 2026-10-19 — Backlog captured from the BluWallet solution doc. Not started.

## Next

- Flowchart the parser/scoring engine before implementation.
