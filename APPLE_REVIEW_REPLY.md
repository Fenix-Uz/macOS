# App Store Connect — Reply to Review (Submission ID a0ff9208-00df-4016-9721-4cd5fd7619ce)

> Paste the section below into the App Store Connect → Resolution Center reply box.
> Review the bracketed notes first and remove anything that doesn't match your ASC metadata.

---

Hello, and thank you for the detailed feedback. We have addressed both points and submitted a new build (version 1.0.0). Details below.

**Guideline 4.1(a) — Copycats / app name referencing Telegram**

We have removed every reference to "Telegram" from the application's name and branding throughout the binary:

- The macOS menu bar items now read **About Fenixuz**, **Hide Fenixuz**, and **Quit Fenixuz** (previously "…Telegram"). This was the most visible remaining reference and has been corrected in all localizations (English, German, Spanish, Italian, Dutch, Portuguese, Russian, Ukrainian).
- The main window title is now **Fenixuz**.
- The application bundle and process name are now **Fenixuz** (the build previously shipped as "Telegram.app"; it now builds and runs as "Fenixuz.app").
- The bundle display name, bundle name, and copyright string are **Fenixuz** / "© 2026 Fenixuz".
- The application icon is our own original phoenix design — it does not use Telegram's logo or visual identity.

Fenixuz is an independent, third-party client for the Telegram messaging network, built on Telegram's publicly documented open API (Telegram officially permits and publishes source for third-party clients). With the rebranding above, the app no longer creates any misleading association with Telegram FZ-LLC's official app. [If you also reference Telegram anywhere in the App Store listing — subtitle, keywords, promotional text, description, or screenshots — scrub those in ASC before resubmitting; reviewers check metadata too.]

**Guideline 4.2.2 — Minimum functionality**

Fenixuz is a fully native macOS application written in Swift and AppKit (NSView/NSViewController). It is **not** a web wrapper and contains no WKWebView-based UI; it speaks the MTProto protocol directly. Native macOS functionality includes:

- Native multi-window management, full-screen, and standard window chrome
- Native macOS notifications, Dock integration, and menu-bar commands with keyboard shortcuts
- A native Share extension (system Share menu) and a Focus Filter app extension
- Native drag-and-drop of files and images into and out of conversations
- Hardware-accelerated rendering, native media playback, voice/video calls (camera + microphone), and screen sharing
- Spotlight indexing of recent contacts
- Native text input, spell-check, and substitutions via the standard Edit menu

To experience the full native app, please sign in with the demo account below. The one-time SMS code is fetched and filled in automatically by the app — please wait 2–10 seconds after pressing **Next** on the phone-number screen.

- **Phone:** +998 33 599 94 79
- **Two-step verification (cloud) password:** Xabarchi

Once signed in, the reviewer has access to the complete native messaging experience (chats, media, calls, settings, etc.).

Thank you again for your time. We're happy to provide any additional information.

---

## Internal checklist before resubmitting (do NOT paste this part)

- [ ] New build (1.0.0 / build ≥ 15) uploaded and selected for this version in ASC.
- [ ] ASC **App Information → Name** = "Fenixuz" (confirm — it already appears to be).
- [ ] ASC **Subtitle**, **Keywords**, **Promotional Text**, **Description** contain no "Telegram".
- [ ] **Screenshots / App Preview** show "Fenixuz" in the menu bar / window (re-capture from the new build if any show "Telegram").
- [ ] **App Review Information → Notes** repeats the demo phone + password + the "code auto-fills, wait 2–10 s" instruction.
- [ ] Demo account sign-in tested from a clean machine right before submitting (xmax.uz endpoint reachable).
