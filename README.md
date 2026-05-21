<div align="center">
  <img src="Telegram-Mac/Assets.xcassets/AppIcon.appiconset/Logo_1024.png"
      width="125"
      height="125">

  <h2 align="center">Fenixuz for macOS</h2>
  <p align="center">An unofficial Telegram client for macOS, built and maintained in Uzbekistan.</p>
</div>

---

This repository is the **macOS port of [Fenixuz](https://fenixuz.uz)** — an unofficial Telegram client distributed in Uzbekistan by Vipads MCHJ. It is a fork of [overtake/TelegramSwift](https://github.com/overtake/TelegramSwift) (the native AppKit Swift implementation of the Telegram client for macOS, GPL v2). All Telegram-related functionality is reached through the official Telegram MTProto API using a Fenixuz-owned `api_id` registered at [my.telegram.org](https://my.telegram.org).

## Status

This is a **work-in-progress port**. Most of the Fenixuz iOS productivity features (Tasks tab, Chat Pincode, Voice-to-Text, Edited Message History, Settings panel, brand customization) are already ported across; the App Store §3.1.1 in-app-purchase compliance gate is in place; the demo-account auto-fill flow for App Review is wired up. The roadmap below tracks what still needs the macOS treatment.

## Branding and Terms compliance

Per the [Telegram API Terms of Service](https://core.telegram.org/api/terms):

- The app is **named "Fenixuz"** — not "Telegram". This satisfies §2.3.
- The logo is a custom orange phoenix mark, **not** the official Telegram paper-plane. This satisfies §2.4.
- The app is **built on the open-source Telegram client codebase**, GPL v2 — explicitly disclosed in the App Store description and in this README (§2.2).
- A unique Telegram `api_id` is registered for this client (§2.1).
- All Telegram sponsored messages are rendered unchanged from the upstream behavior — third-party clients must display them per §3.3.

## Get it

Coming soon to the Mac App Store. The iOS sibling is live: [Fenixuz on the App Store](https://apps.apple.com/app/id6768202244).

## Fenixuz-specific features (delta from upstream)

| Module | Purpose |
|---|---|
| `FenixuzDemoCodeFetcher` | Apple Review demo-account SMS auto-fill via `xmax.uz` |
| `FenixuzAppStoreIAP` | Apple §3.1.1 gate — blocks Premium/Stars/Gift purchases (Telegram server does not honor IAP receipts from non-official clients) |
| `FenixuzTasksController` + `FenixuzTasksDatabase` | "Vazifalar" — built-in to-do tab backed by SQLite |
| `FenixuzChatPincodeManager` + `FenixuzChatPincodeViewController` | PIN-protect individual chats |
| `FenixuzSpeechToTextManager` | Voice-to-text dictation via `SFSpeechRecognizer` |
| `FenixuzEditedHistoryController` + `FenixuzEditedHistoryManager` | Edited-message history viewer |
| `FenixuzForeignUserBlock` + `FenixuzForeignUserBannerView` | Country-code helpers for the Uzbek market |
| `FenixuzL10n`, `FenixuzSettingsController`, `FenixuzTextStyleController` | Brand strings + a "Fenixuz" Settings tab |
| `FenixuzBrandColors` | Brand palette (emerald primary) |
| `FenixuzAutoTextController`, `FenixuzAutoTranslateController`, `FenixuzTranslationLanguageController` | Auto-text snippets + translation glue |

See `FORK_NOTES.md` and `FENIXUZ_HOOKS.md` for the full audit trail — every upstream-owned file the fork touches is listed there, with the exact hook code and the reason it cannot live inside a Fenixuz module. Those documents are the **single source of truth** when re-applying patches after an upstream merge.

## Upstream merge workflow

This repository tracks two remotes:

- `origin` → `github.com/Fenix-Uz/macOS` (this repo — push target)
- `upstream` → `github.com/overtake/TelegramSwift` (the upstream native macOS client — fetch only)

To pull the latest upstream release into this fork:

```bash
# 1. Tag a checkpoint before merging (so we can roll back).
git tag pre-upstream-merge-$(date +%Y%m%d-%H%M)

# 2. Fetch the upstream branches.
git fetch upstream

# 3. Merge upstream/master into our main. Conflicts surface — do NOT auto-resolve.
git merge upstream/master --no-rebase

# 4. Resolve conflicts file-by-file, using FENIXUZ_HOOKS.md as the source of truth
#    for every Fenixuz patch in an upstream-owned file. Fenixuz hooks always win;
#    upstream code wins for everything around them.

# 5. Build before pushing — the binary must launch and the demo flow must still
#    auto-fill the SMS code.
xcodebuild -workspace Telegram-Mac.xcworkspace \
    -scheme Telegram -configuration Debug \
    -derivedDataPath /tmp/tgmac-dd \
    build CODE_SIGN_STYLE=Automatic

# 6. Only after the build is green, push to origin.
git push origin main

# 7. If something is wrong, roll back to the tag from step 1.
```

## How to build

Open `Telegram-Mac.xcworkspace` in Xcode (not `Telegram.xcodeproj` directly — the workspace is the canonical entry point) and Run. First-time setup requires building the `core-xprojects` native dependencies (OpenSSL, OpenH264, libopus, libvpx, mozjpeg, libwebp, dav1d, ffmpeg, webrtc, tde2e) via `scripts/configure_frameworks.sh` — this takes 1–2 hours.

For CI / command-line builds:

```bash
xcodebuild -workspace Telegram-Mac.xcworkspace \
    -scheme Telegram -configuration Debug \
    -derivedDataPath /tmp/tgmac-dd \
    build CODE_SIGN_STYLE=Automatic
```

The signed `.app` will be at `/tmp/tgmac-dd/Build/Products/Debug/Telegram.app`.

## Permissions

Same as upstream Telegram for macOS:

- **Microphone** — voice messages, voice notes, audio calls, voice-to-text dictation.
- **Camera** — profile pictures and video calls.
- **Location** — share your location with friends.
- **Outgoing network connections** — connect to Telegram MTProto servers.
- **Incoming network connections** — peer-to-peer voice / video calls.
- **User-selected files** — save received media to disk.
- **Downloads folder** — auto-download received files.

## License

Fenixuz for macOS is GPL v2 (inherited from upstream Telegram for macOS — see [LICENSE](LICENSE)). All Fenixuz-specific Swift modules are also released under GPL v2 by Vipads MCHJ.

## Credits

- [overtake / TelegramSwift](https://github.com/overtake/TelegramSwift) — the upstream native macOS Swift client this fork builds on.
- [Telegram Messenger LLP](https://telegram.org/) — the underlying messaging platform and MTProto API.
- Fenixuz iOS / macOS development by [Vipads MCHJ](https://fenixuz.uz), Tashkent, Uzbekistan.

## Contact

- Website: https://fenixuz.uz
- Support: admin@fenixuz.uz
