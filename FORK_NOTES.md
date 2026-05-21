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

- **Team:** Vipads
- **Bundle ID:** `ru.keepcoder.Telegram` (hozir o'zgartirilmagan — Mac App Store deploy paytida o'zgartiriladi)
- **Sign Style:** Automatic, Personal Team yetadi (testing uchun)

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
