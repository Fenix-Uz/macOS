# TelegramSwift fork — Fenixuz notes

Tarix: 2026-05-18
Maqsad: Telegram-Mac (overtake/TelegramSwift) ni macOS Tahoe (Xcode 26) da build qilib, Apple Review uchun demo account auto-fill qo'shish.

Bu hujjat **forkning hozirgi holatini, qilingan patchlarni va kelajakdagi rejalarni** saqlaydi. Yangi mashinada qaytadan boshlasangiz, shu hujjat orqali bir necha soatlik debugging'ni o'tkazib yuborasiz.

---

## 1. Folder strukturasi

```
/Users/codingtech/Documents/TelegramSwift/    ← repo (overtake/TelegramSwift fork)
├── Telegram-Mac/                              ← asosiy app sources
│   ├── AuthController.swift                   ← demo hooks shu yerda
│   ├── Auth_CodeEntry.swift
│   ├── Auth_PhoneNumber.swift
│   ├── FenixuzDemoCodeFetcher.swift          ← bizning yangi fayl (220 qator)
│   └── ...
├── Telegram.xcodeproj/                        ← Xcode project (patched)
├── packages/                                  ← lokal SPM packages
├── submodules/                                ← git submodules (telegram-ios, tg_owt, ...)
├── core-xprojects/                            ← native C/C++ build scripts
└── Telegram-Mac.xcworkspace                   ← buni Xcode'da ochasiz
```

**Build qilingan app:**
```
/tmp/tgmac-dd/Build/Products/Debug/Telegram.app
```

---

## 2. Build muhiti

- macOS: Tahoe (Darwin 25.4.0)
- Xcode: 26.x (XCODE_PRODUCT_BUILD_VERSION 17F42)
- SDK: MacOSX26.5.sdk
- Swift: 6.3.2 (Apple)
- Build CLI: `xcodebuild -workspace Telegram-Mac.xcworkspace -scheme Telegram -configuration Debug ...`
- Disk ishlatildi: ~3-4 GB (core-xprojects build) + ~2 GB (derived data) = ~6 GB

---

## 3. Build paytida qilingan patch'lar (TARTIBLI)

Yangi mashinaga ko'chsangiz, **shu tartibda** qaytaring:

### 3.1 SSH → HTTPS rewrites

`.gitmodules` da barcha URL'lar SSH formatda (`git@github.com:...`). HTTPS'ga o'tkazing:

```bash
cd ~/Documents/TelegramSwift
sed -i.bak 's|git@github.com:|https://github.com/|g; s|git@gitlab.com:|https://gitlab.com/|g' .gitmodules
git submodule sync
git submodule update --init --recursive
```

### 3.2 CMake kompatibilik (CMake 4.x dan boshlab `< 3.5` o'chirilgan)

4 ta build script'ga `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` qo'shildi:

| Fayl | Joy |
|---|---|
| `core-xprojects/Mozjpeg/Mozjpeg/build.sh` | line 38, `cmake ...` chaqiruvi |
| `core-xprojects/libwebp/libwebp/build-cmake.sh` | line 69 |
| `core-xprojects/webrtc/webrtc/build.sh` | line 38-39 |
| `core-xprojects/tde2e/tde2e/build.sh` | `options=` ga qo'shildi + line 27 |

### 3.3 FFmpeg versiya

`core-xprojects/ffmpeg/ffmpeg/build.sh` line 32:
```bash
FF_VERSION="7.1.1"   # was "7.1"; submodule has 7.1.1 directory
```

### 3.4 WebRTC clang lifetimebound

`submodules/tg_owt/src/api/candidate.h` line 108:
```cpp
// PRE:
//   void set_type(absl::string_view type ABSL_ATTRIBUTE_LIFETIME_BOUND) {
// POST:
   void set_type(absl::string_view type) {
       Assign(type_, type);
   }
```
Sabab: Yangi clang `[[clang::lifetimebound]]` ni void function parameter'da rad etadi.

### 3.5 Deployment target bumps

Xcode 26 da MACOSX_DEPLOYMENT_TARGET 10.13'dan past bo'lsa Swift 5.0 compat libs talab qiladi (Metal toolchain'da yo'q).

**Patched fayllar:**
- 18 ta `*.xcodeproj/project.pbxproj` (10.11/10.12/10.13/10.14 → 10.15)
- 71 ta `Package.swift` (.v10_11/v10_12/v10_13/v10_14 → .v10_15)

Bulk patch:
```bash
cd ~/Documents/TelegramSwift
find . -name "Package.swift" -not -path "*/.build/*" \
    -exec sed -i.bak 's/\.macOS(\.v10_9)/.macOS(.v10_15)/g; s/\.macOS(\.v10_10)/.macOS(.v10_15)/g; s/\.macOS(\.v10_11)/.macOS(.v10_15)/g; s/\.macOS(\.v10_12)/.macOS(.v10_15)/g; s/\.macOS(\.v10_13)/.macOS(.v10_15)/g; s/\.macOS(\.v10_14)/.macOS(.v10_15)/g' {} \;

find . -name "project.pbxproj" -not -path "*/.build/*" -not -path "*/tg_owt/*" -not -path "*/telegram-ios/*" \
    -exec sed -i.bak 's/MACOSX_DEPLOYMENT_TARGET = 10\.\(11\|12\|13\|14\);/MACOSX_DEPLOYMENT_TARGET = 10.15;/g' {} \;
```

### 3.6 Hardcoded `libswiftAppKit.dylib` ssylkalarini olib tashlash

`Telegram.xcodeproj/project.pbxproj` da 4 ta qator olib tashlandi:
```
$(TOOLCHAIN_DIR)/usr/lib/swift-5.0/macosx/libswiftAppKit.dylib
```
Bu yangi Xcode'da Metal toolchain'da yo'q lib'ni izlaydi va xato beradi.

```bash
sed -i.bak '/swift-5.0\/macosx\/libswiftAppKit\.dylib/d' Telegram.xcodeproj/project.pbxproj
```

### 3.7 Firebase (iOS-only) ni butunlay olib tashlash

Firebase iOS SDK macOS app bundle strukturasiga mos kelmaydi ("contains Info.plist, expected Versions/Current/Resources/Info.plist").

**a) Swift kodda imports + ishlatish kommentariyaga olindi:**
- `Telegram-Mac/AppDelegate.swift` line 34-35: `import Firebase`, `import FirebaseCrashlytics`
- Line 463-467: `FirebaseApp.configure()` va Crashlytics chaqiruvlari

**b) `Telegram.xcodeproj/project.pbxproj` dan Firebase entry'lar olib tashlandi:**
```bash
sed -i.bak '/FirebaseCrashlytics in Frameworks/d; /FirebaseAnalytics in Frameworks/d; /\/\* FirebaseAnalytics \*\/,$/d; /\/\* FirebaseCrashlytics \*\/,$/d; /firebase-ios-sdk" \*\/,$/d' Telegram.xcodeproj/project.pbxproj
```

Qolgan orphan definitions (XCRemoteSwiftPackageReference va XCSwiftPackageProductDependency bloklari) Xcode tomonidan bemalol e'tibordan chetda qoldiriladi.

### 3.8 Sparkle updater'ni butunlay o'chirish

**3 ta joyda patch:**

**a) `Telegram-Mac/Debug.xcconfig` line 16:**
```ini
// Sparkle SFEED_URL — soxta localhost (bo'sh string crash beradi:
// AppUpdateViewController.swift:570 `as! String` force-cast).
SFEED_URL = https:$(SIMPLE_SLASH)/127.0.0.1/none.xml
```

**b) `Telegram-Mac/AppUpdateViewController.swift` `resetUpdater()` — no-op:**
```swift
private func resetUpdater() {
    // Fully disabled — was hitting mac-updates.telegram.org and
    // overwriting this fork's binary with upstream.
    return
}
```

**c) `Telegram-Mac/AccountViewController.swift` Settings → "Update" menyusi yashirilgan (line 623-626):**
```swift
// if let state = appUpdateState, !context.isSupport {
//     entries.append(.update(...))
//     index += 1
// }
```

Birinchi ikkita asosiy — settings menyusini olib tashlash ham UI-darajada ortiqcha. Birinchi qadamlar bilan ham app crash bo'lmasdan ishlaydi, lekin Settings → Updates panel'ni ochsa, bo'sh pane ko'rinardi.

### 3.9 App Store 3.1.1 IAP gate — Settings'da Premium / Stars / Business / Gift yashirilgan

iOS Fenixuz da Apple 2026-05-18 da `Telegram-iOS` build 15 ni 3.1.1 (digital subscriptions IAP'siz) sababli rad etgan. Bizning fork **Telegram Premium / Stars / Business / Premium Gift** ni hech qanday yo'l bilan (na IAP, na fiat) sotmaydi — chunki Telegram serveri faqat rasmiy klient IAP receipt'larini qabul qiladi va uz.fenixuz.app uchun StoreKit register qilish teatr bo'lar edi. Mac fork ham xuddi shu siyosatga rioya qilishi kerak.

**Patched fayl:** `Telegram-Mac/AccountViewController.swift` (line ~656-681)

`accountInfoEntries(...)` ichidagi `if !context.premiumIsBlocked { ... }` bloki **butunlay kommentariyaga olingan**:
- `.premium` entry
- `.stars` entry (XTR balance + purchase)
- `.ton` entry (TON wallet)
- `.business` entry
- `.giftPremium` entry
- `.whiteSpace` separator

```swift
// Fenixuz: Premium / Stars / Business / Gift hidden for App Store 3.1.1 compliance.
// This fork does not sell these via any payment mechanism — Telegram server only
// honors IAP receipts from the official client, so registering StoreKit products
// would be theatre. Same posture as iOS Fenixuz. See CLAUDE.md §4 and HOOKS.md.
// TON balance is also hidden because the entry sits inside this same block.
// if !context.premiumIsBlocked { ... }
```

**Eslatma — bu UI darajada gate.** Agar foydalanuvchi deep-link orqali (`t.me/...?startgroup=` invoice URL) yoki bot checkout orqali Premium oynaga kirsa, hozircha bloklanmaydi. iOS dagi `submodules/Fenixuz/AppStoreIAP/` ekvivalent moduli Mac uchun keyinroq qilinishi kerak (Bot Checkout / Web App invoice / Premium boarding hook nuqtalari aniqlanishi).

### 3.10 Version string'dan "Beta" suffix olib tashlash

**Patched fayl:** `Telegram-Mac/AboutModalController.swift` (line 12-26)

Original `APP_VERSION_STRING` da preprocessor flag'lariga qarab " Beta" / " AppStore" / " Alpha" / " Stable" suffix qo'shilardi. Fenixuz fork'ida bu suffix Settings sidebar pastida foydalanuvchiga "1.0.0.10 Beta" ko'rinishida ko'rinib, marketing screenshot'larda chiroyli emas.

**O'zgartirilgan:**
```swift
var APP_VERSION_STRING: String {
    // Fenixuz: build-type suffix (Stable / AppStore / Alpha / Beta) removed so
    // Settings sidebar and About modal show only the version number.
    return "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "1").\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "0")"
}
```

Endi Settings sidebar pastida shunchaki `1.0.0.10` (yoki `1.0.0.11` keyingi build'da) ko'rinadi.

**Affected display joylari** (`APP_VERSION_STRING` chaqiruvchilari):
- `AccountViewController.swift:424` — Settings sidebar pastidagi version label
- `AboutModalController.swift:42, 62, 119` — About modal oynasidagi version label + clipboard'ga copy qilish

### 3.11 App Store 4.1(a) Copycats + 4.2.2 — app nomini "Telegram" → "Fenixuz" (2026-06-02)

Apple Submission `a0ff9208-00df-4016-9721-4cd5fd7619ce` (review 2026-06-01, build `1.0.0 (14)`) ikki sabab bilan rad etdi: **4.1(a) Copycats** ("the app's name includes references to Telegram") va **4.2.2 Minimum Functionality**.

**Muhim:** `CFBundleName`/`CFBundleDisplayName` allaqachon "Fenixuz" edi (878bbb429 da). Demak reviewer "Telegram" ni boshqa joyda ko'rdi: **menu bar** (About/Hide/Quit Telegram), **window title**, va **.app fayl nomi / process nomi** (`PRODUCT_NAME = $(TARGET_NAME)` = "Telegram").

**Qilingan o'zgarishlar (faqat user-visible nom; module nomi tegilmadi):**

1. **`Telegram-Mac/*.lproj/MainMenu.xib`** (7 ta: Base, en, de, es, it, nl, pt-BR) — faqat `title="..."` atributlari: `TelegramMac`/`About Telegram`/`Hide Telegram`/`Quit Telegram`/`Telegram` (Window item)/`<window title="Telegram">` → **Fenixuz**.
   - ⚠️ `customModule="Telegram"` (Swift **module** nomi, 358 ta) **TEGILMADI**. Agar o'zgartirilsa nib `Telegram.AppDelegate`/`MMMenuItem` klasslarini topa olmaydi → launch'da crash.
2. **`Telegram-Mac/*.lproj/MainMenu.strings`** (7 ta: de, es, it, nl, pt-BR, ru, uk) — localized menu qiymatlari "Telegram" → "Fenixuz".
   - ⚠️ **de/es/it = UTF-16LE (BOM bilan)**. BSD `sed` ularda "illegal byte sequence" beradi va faylni o'zgartirmaydi. `python3` bilan encoding saqlab o'zgartirildi (BOM-aware decode/encode). nl/pt-BR/ru/uk = UTF-8.
3. **`Telegram-Mac/Spotlight.swift:49`** — `attributeSet.creator = "Telegram"` → `appName`.
4. **`Telegram.xcodeproj/project.pbxproj`** — main **Telegram** target (Debug + Release):
   ```
   PRODUCT_NAME = Fenixuz;          // edi: "$(TARGET_NAME)" = Telegram
   PRODUCT_MODULE_NAME = Telegram;  // PIN — module nomi o'zgarmasligi shart
   ```
   Endi `.app` = **Fenixuz.app**, process = **Fenixuz**, lekin Swift module hali **Telegram** (nib `customModule` + share ext `$(PRODUCT_MODULE_NAME).ShareViewController` ishlashi uchun). **TelegramShare** va **FocusIntents** target'lari tegilmadi (`$(TARGET_NAME)`) — extension'lar fayl nomi bilan emas, bundle ID bilan ishlaydi; display name allaqachon "Fenixuz".

**Tegilmagan (ataylab):** `ParseAppearanceColors.swift:358` default `copyright = "Telegram"` (theme palette default, reviewer ko'rmaydi); `tg`/`telegram` URL scheme'lari (deep link uchun kerak); in-feature copy ("Telegram Premium" h.k. — service nomi, app nomi emas).

**Icon:** `Assets.xcassets/AppIcon.appiconset/Logo_*.png` allaqachon **qizil phoenix** (Fenixuz brendi), Telegram logosi EMAS — 4.1 uchun xavfsiz.

**4.2.2:** kod o'zgarmadi. Bu to'liq native AppKit app (web wrapper emas). Reply message + demo login (reviewer ichkariga kirib native funksiyani ko'rishi uchun) bilan hal qilinadi. Reply matni: `APPLE_REVIEW_REPLY.md`.

**Eslatma — ASC metadata:** binary tuzatildi, lekin App Store Connect listing'da (subtitle, keywords, promotional text, description, screenshots) "Telegram" bo'lmasligini foydalanuvchi tekshirishi kerak (Apple metadata'ni ham tekshiradi).

---

## 4. Demo account auto-fill (asosiy maqsad)

### 4.1 Yangi fayl

`Telegram-Mac/FenixuzDemoCodeFetcher.swift` (220 qator) — iOS `submodules/Fenixuz/AppleReview/Sources/FenixuzDemoCodeFetcher.swift` (v3) portasi.

**Public API:**
```swift
public enum FenixuzDemoCodeFetcher {
    public static let demoPhone = "+998335999479"
    public static let cloudPassword2FA = "Xabarchi"

    public static func isDemoPhone(_ phoneNumber: String) -> Bool
    public static func prewarmIfDemo(phoneNumber: String)
    public static func autoFillIfDemo(
        phoneNumber: String,
        applyCode: @escaping (String) -> Void
    )
}
```

**Parametrlar (iOS v3 bilan bir xil):**
| Parametr | Qiymat | Sabab |
|---|---|---|
| `pollInterval` | 0.5s | xmax.uz 0.5s'da yetadi |
| `perRequestTimeout` | 15s | xmax.uz ~7s'da javob beradi |
| `hardTimeout` | 60s | Reviewer bundan ko'p kutmaydi |
| Consecutive errors auto-cancel | **YO'Q** | Faqat hardTimeout failure path |
| Stale baseline check | **YO'Q** | xmax.uz JORIY kodni qaytaradi |

### 4.2 Hook'lar (`Telegram-Mac/AuthController.swift`)

**A. Phone submit'da prewarm (`sendCode()` boshida, ~line 1053):**
```swift
private func sendCode(_ phoneNumber: String, updateState: ...) {
    FenixuzDemoCodeFetcher.prewarmIfDemo(phoneNumber: phoneNumber)
    guard let window = self.window else { return }
    ...
```

**B. Code Entry ko'rsatilganda auto-fill (`code_entry_c.update(...)` dan keyin, ~line 825):**
```swift
}, takeError: { ... })
FenixuzDemoCodeFetcher.autoFillIfDemo(
    phoneNumber: number,
    applyCode: { [weak code_entry_c] code in
        code_entry_c?.applyExternalLoginCode(code)
    }
)
```

`Auth_CodeEntryController.applyExternalLoginCode(_:)` — Telegram-Mac'da tayyor metod, Apple uchun maxsus yozilmagan. Biz uni callback orqali ishlatamiz.

### 4.3 Xcode project'ga qo'shilgan

`Telegram.xcodeproj/project.pbxproj` da 4 ta entry:
- `PBXBuildFile`: `FE10DEC04E14C19000000001`
- `PBXFileReference`: `FE10DEC04E14C19000000002`
- Group (Telegram-Mac folder) listing
- `PBXSourcesBuildPhase` (Compile Sources phase)

---

## 5. Build qilish (yangi mashinada)

```bash
# 1. Brew dependencies
brew install cmake ninja zlib autoconf libtool automake yasm pkg-config
# Eslatma: openssl@1.1 Homebrew'dan o'chirilgan, lekin kerak emas
# (configure_frameworks.sh o'zining OpenSSL 1.1.1'ini source'dan build qiladi)

# 2. Repo + submodullar (3.1 patch qilingan .gitmodules bilan)
cd ~/Documents
git clone https://github.com/overtake/TelegramSwift.git
cd TelegramSwift
# 3.1 dagi sed qo'llang
git submodule update --init --recursive

# 3. Bizning barcha patchlarni qaytarib qo'llang (3.2-3.8)

# 4. Rebuild flag
echo "yes" > scripts/rebuild

# 5. Frameworks (1-2 soat)
bash scripts/configure_frameworks.sh

# 6. Xcode'ni oching, Apple ID tanlang
open Telegram-Mac.xcworkspace

# 7. Build (Debug)
xcodebuild -workspace Telegram-Mac.xcworkspace \
    -scheme Telegram -configuration Debug \
    -derivedDataPath /tmp/tgmac-dd \
    clean build CODE_SIGN_STYLE=Automatic
```

---

## 6. Apple ID va codesign

- **Team:** **Vipads MCHJ** (organization), Apple Team ID `ZDBP5RSRZF`, Apple ID `vipadsllc@gmail.com`. **NOT a personal team.** Same team as iOS Fenixuz (`uz.fenixuz.app`) — required for Universal Purchase.
- **Bundle ID:** `uz.fenixuz.app` (renamed 2026-05-21 from `uz.fenixuz.macapp` to match iOS for Universal Purchase). Share extension: `uz.fenixuz.app.TelegramShare`. FocusIntents: `uz.fenixuz.app.FocusIntents`.
- **Sign Style:** Automatic. Development certs may display the individual developer's name (e.g. "Apple Development: Azimjon Abdurasulov") because Apple labels Dev certs by Apple ID owner — but the **Team ID** under which they're issued is always `ZDBP5RSRZF`. Distribution certs for Mac App Store must be `Apple Distribution: Vipads MCHJ`.

### 6.1 Archive signing keys — DO NOT leave empty (2026-05-22 fix)

Xcode Organizer → Distribute App "No Team Found in Archive" rejection happens when `CODE_SIGN_IDENTITY` is an empty string in the Release configuration. With `CODE_SIGN_STYLE = Automatic` AND `CODE_SIGN_IDENTITY = ""`, Xcode at archive time has nothing to lock signing to and falls back to **ad-hoc** signing (`codesign -dvvv` shows `Signature=adhoc`, `TeamIdentifier=not set`). The archive's `Info.plist` `ApplicationProperties.Team` and `SigningIdentity` then come out empty strings, and Organizer refuses to proceed with "No Team Found in Archive".

The fix is to mirror what the Debug config has — keep `CODE_SIGN_IDENTITY = "Apple Development"` (plus the `[sdk=macosx*]` variant) in BOTH the **Telegram** main target's Release config AND the **TelegramShare** Release config inside `Telegram.xcodeproj/project.pbxproj`:

```
CODE_SIGN_IDENTITY = "Apple Development";
"CODE_SIGN_IDENTITY[sdk=macosx*]" = "Apple Development";
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = ZDBP5RSRZF;
```

Distribution cert assignment for Mac App Store is handled at Xcode → Organizer → Distribute App step (not at archive time) — the archive only needs valid Development signing + Team for Organizer to proceed.

**Regression-check (run after every pbxproj rewrite):**

```bash
grep -n 'CODE_SIGN_IDENTITY = "";' Telegram.xcodeproj/project.pbxproj
# must return: (no output). If it returns lines, the archive will be adhoc-signed.

xcodebuild -showBuildSettings -workspace Telegram-Mac.xcworkspace \
    -scheme Telegram -configuration Release 2>/dev/null \
  | grep -E "CODE_SIGN_IDENTITY|DEVELOPMENT_TEAM|_DEVELOPMENT_TEAM_IS_EMPTY"
# must show:
#   CODE_SIGN_IDENTITY = Apple Development
#   DEVELOPMENT_TEAM = ZDBP5RSRZF
#   _DEVELOPMENT_TEAM_IS_EMPTY = NO
```

---

## 7. Kelajak rejalar (HOZIR EMAS)

### 7.1 Mac App Store deployment
- [ ] Apple Developer Program ($99/yil)
- [ ] Bundle ID o'zgartirish: `ru.keepcoder.Telegram` → `uz.fenix.TelegramMac` (yoki shunga o'xshash)
- [ ] App Store Connect'da app yaratish
- [ ] Archive build (Release configuration)
- [ ] App Store Connect orqali submit
- [ ] **Apple Review notes'ga yozish:**
  ```
  Demo phone: +998 33 599 94 79
  2FA cloud password: Xabarchi

  The SMS code is auto-fetched and pre-filled by the app — wait 2-10
  seconds after tapping Next on the phone entry screen.
  ```

### 7.2 Update mexanizmi
**TANLOV:** Mac App Store orqali tarqatamiz → **Sparkle KERAK EMAS** (Apple o'zi update qiladi).

Direct .dmg tarqatish kerak bo'lsa:
- **Variant 1:** GitHub Releases + Sparkle's `generate_appcast` CLI (bepul)
- **Variant 2:** O'z VPS server'ida `versions.xml` + `.dmg` host qilish
- DSA/EdDSA imzo kalit kerak (Sparkle xavfsizlik talab qiladi)

### 7.3 Firebase qaytarish (ixtiyoriy)
Hozir crash reporting yo'q. Agar kerak bo'lsa:
- Mac App Store builds'da: **MetricKit** (Apple'ning native crash collector)
- Yoki: **Sentry** (cross-platform, macOS uchun yaxshi xCFramework bor)
- Yoki: **Crashlytics** ni macOS uchun to'g'ri sozlash (iOS SDK ishlamaydi, alohida Mac SDK kerak)

### 7.4 Bundle ID, App Group, Keychain
Mac App Store deploy paytida:
- `ru.keepcoder.Telegram` → `uz.fenix.<sizning_nom>`
- `6N38VWS5BX.ru.keepcoder.Telegram` (App Group) → `<sizning_team_id>.uz.fenix.<sizning_nom>`
- Bularning hammasi `Config.swift`, `*.entitlements`, `*.plist`, `*.pbxproj` da

Fayllar ro'yxati:
```
Telegram-Mac/Telegram-Sandbox.entitlements
Telegram-Mac/GoogleService-Info.plist          (Firebase o'chirilganidan keyin shart emas)
Telegram-Mac/Telegram-Mac.entitlements
TelegramShare/TelegramShare.entitlements
FocusIntents/FocusIntents.entitlements
Telegram.xcodeproj/project.pbxproj
packages/ApiCredentials/Sources/ApiCredentials/Config.swift
```

---

## 8. Sinash

Build qilingandan keyin:

```bash
open /tmp/tgmac-dd/Build/Products/Debug/Telegram.app
```

1. Telefon raqami: `+998335999479` → **Next**
2. Code Entry ochiladi
3. **2-10 soniyada kod avtomatik to'ldiriladi** (xmax.uz'dan)
4. 2FA so'ralsa: `Xabarchi`

**Agar ishlamasa:**
- `Console.app` da `FenixuzDemoLogin` qidiring — debug log'lar ko'rinadi
- xmax.uz endpoint'i ishlayotganini tekshirsh: `curl https://xmax.uz/code.php`
- Network'ingiz xmax.uz'ga ulana olishi kerak

---

## 9. tdesktop bilan farq

Bu fork (TelegramSwift) **Mac uchun native Swift** versiyasi. Bizning ikkinchi forkimiz `~/TBuild/tdesktop` — Qt/C++ versiyasi (Windows + Linux + macOS Qt UI).

| | tdesktop (Qt) | TelegramSwift (Swift) |
|---|---|---|
| Joy | `~/TBuild/tdesktop/` | `~/Documents/TelegramSwift/` |
| Til | C++ / Qt 6 | Swift / AppKit |
| Demo fetcher | `intro/demo_code_fetcher.{h,cpp}` | `Telegram-Mac/FenixuzDemoCodeFetcher.swift` |
| Build | `cmake --build out --target Telegram` | `xcodebuild -scheme Telegram` |
| macOS look | Qt UI (Win/Linux'ga o'xshash) | Native Mac (App Store'dagidek) |
| Tarqatish maqsadi | DMG + Windows + Linux | Mac App Store |
