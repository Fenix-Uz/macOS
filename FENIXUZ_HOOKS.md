# Fenixuz hooks in Telegram-Mac (macOS native fork)

Source-of-truth index for every line of Fenixuz code that lives outside Fenixuz-prefixed files (`Telegram-Mac/Fenixuz*.swift`). Each entry: the exact file + region modified, the hook code, why it lives outside a Fenixuz module.

On every `git pull upstream master`, this file is used to re-apply hooks if upstream code moved. **Fenixuz hooks always win** against upstream changes; surrounding upstream code is taken as-is.

Companion to `submodules/Fenixuz/HOOKS.md` in the iOS fork. iOS uses Bazel + module submodules; macOS uses Xcode + single-target compilation, so every Fenixuz file is directly in `Telegram-Mac/`.

> Last verified: 2026-05-21 — initial inventory created when porting the iOS Apple §3.1.1 IAP gate to macOS.

---

## App Store IAP gate (Apple guideline 3.1.1) — May 2026 rejection fix

**Context.** Apple Submission ID `d5a06920-6b5f-4167-b7fb-46c80b156aa8` rejected the iOS Fenixuz fork in May 2026 under §3.1.1 because the reviewer reached `BotCheckoutController` from `@PremiumBot` and could pay 269 990 UZS for an Annual Premium Subscription — i.e. a digital subscription via fiat card, bypassing IAP. The same flow exists on macOS (`PaymentsCheckoutController` reached via `t.me/$slug`, Web App `web_app_open_invoice`, or chat keyboard payment button). Plus every StoreKit-backed Premium / Stars / Gift purchase on macOS would fail server-side anyway: Telegram's server only honours receipts from the official client bundle. So on this fork we block both paths and direct the user to the official Telegram for macOS (Mac App Store ID `747648890`).

**Files added (not hooks — Fenixuz-owned):**
- `Telegram-Mac/FenixuzAppStoreIAP.swift` — `shouldBlock(invoice:)`, `shouldBlock(currency:hasSubscriptionPeriod:)`, `shouldBlockIAP`, `presentBlockedAlert(on:Window)`. Uses TGUIKit `verifyAlert` + `NSWorkspace.shared.open` for the Mac App Store deep link.
- `Telegram-Mac/FenixuzL10n.swift` — `iap_block_title`, `iap_block_message`, `iap_block_open_app_store`, `iap_block_cancel` (en/uz/ru).

**Detection rules:**
- **Invoice gate** (`shouldBlock(invoice:)`): `currency.uppercased() != "XTR"` AND `subscriptionPeriod != nil`. Stars stay allowed at the invoice surface; one-off non-subscription bot invoices for physical goods continue to work.
- **StoreKit gate** (`shouldBlockIAP`): unconditional `true`. Every Premium / Stars / Gift / Subscription / Restore goes through StoreKit on Mac via `InAppPurchaseManager.buyProduct(...)` and `restorePurchases(...)`. None of those receipts are honoured by Telegram's server.

---

### `Telegram-Mac/InAppLinks.swift` (line ~1313)

**Hook in `case let .invoice(_, context, slug):` of `execute(inapp:afterComplete:)`, inside the `fetchBotPaymentInvoice` next-block, BEFORE the `if invoice.currency == XTR` branching.**

```swift
// Fenixuz: Apple 3.1.1 — t.me/$slug deep-link orqali fiat-card Premium obuna sotib olishni bloklaymiz.
if FenixuzAppStoreIAP.shouldBlock(invoice: invoice) {
    FenixuzAppStoreIAP.presentBlockedAlert(on: getWindow(context))
    return
}
```

Reason: covers the deep-link path (`https://t.me/$slug` resolved to an invoice). `getWindow(context)` returns the active `Window` (TGUIKit).

---

### `Telegram-Mac/WebpageModalController.swift` (line ~1875)

**Hook inside the `web_app_open_invoice` handler, in the `if let window = self?.window` block, BEFORE the `if invoice.currency == XTR` branching.**

```swift
// Fenixuz: Apple 3.1.1 — Web App ichidan ochilgan fiat-card Premium obunani bloklaymiz.
if FenixuzAppStoreIAP.shouldBlock(invoice: invoice) {
    FenixuzAppStoreIAP.presentBlockedAlert(on: window)
    self?.sendEvent(name: "invoice_closed", data: "{\"slug\": \"\(slug)\", \"status\": \"cancelled\"}")
    return
}
```

Reason: Web Apps (`web_app_open_invoice`) can trigger Premium subscription invoices independently of the slug deep-link path. We also send `invoice_closed: cancelled` so the WebApp JS learns the flow ended (matches existing cancellation semantics).

---

### `Telegram-Mac/ChatInterfaceInteraction.swift` (line ~826)

**Hook in `case .payment:` of the chat keyboard-button handler, inside the `if let receiptMessageId = receiptMessageId { ... } else { ... }` else-branch, BEFORE the `else if invoice.currency == XTR` branch.**

```swift
// Fenixuz: Apple 3.1.1 — chat-ichi bot keyboard tugmasi orqali @PremiumBot fiat-card obuna yo'lini bloklaymiz.
if FenixuzAppStoreIAP.shouldBlock(invoice: invoice) {
    FenixuzAppStoreIAP.presentBlockedAlert(on: strongSelf.context.window)
} else if invoice.currency == XTR {
    showModal(...)
} else {
    showModal(...)
}
```

Reason: this is the exact path the May 2026 iOS reviewer used — tapping `@PremiumBot`'s invoice message in chat would otherwise present `PaymentsCheckoutController` modally.

---

### `Telegram-Mac/PremiumBoardingController.swift` (lines ~1672 + ~1765)

Two hooks: the `buyAppStore` closure (Subscribe path) and the `restore()` method (Restore Purchases path).

**Hook 1 — inside `buyAppStore = { ... }`, BEFORE the `canPurchasePremium` chain (around line 1668):**

```swift
// Fenixuz: Apple 3.1.1 — StoreKit Premium subscription fork'da sotilmaydi.
// Telegram serveri rasmiy bo'lmagan client receiptlarini qabul qilmaydi.
if FenixuzAppStoreIAP.shouldBlockIAP {
    lockModal.close()
    needToShow = false
    FenixuzAppStoreIAP.presentBlockedAlert(on: context.window)
    return
}
```

**Hook 2 — at the top of `func restore()`, BEFORE `context.inAppPurchaseManager.restorePurchases(...)`:**

```swift
// Fenixuz: Apple 3.1.1 — restorePurchases bu fork uchun hech qachon Premium qaytarmaydi
// (StoreKit receipt'lar Telegram serverida invalid). Foydalanuvchini rasmiy clientga yo'naltirsin.
if FenixuzAppStoreIAP.shouldBlockIAP {
    FenixuzAppStoreIAP.presentBlockedAlert(on: context.window)
    return
}
```

Reason: the Premium Boarding screen still renders (view-only — features list, prices). The Subscribe and Restore buttons end at the alert. `lockModal.close()` is called explicitly so the brief "preparing purchase" modal doesn't linger behind the alert.

---

### `Telegram-Mac/GiveawayModalController.swift` (line ~1342)

**Hook BEFORE the `canPurchasePremium` chain that funnels into `inAppPurchaseManager.buyProduct(...)`:**

```swift
// Fenixuz: Apple 3.1.1 — StoreKit Giveaway purchase fork'da bloklanadi.
if FenixuzAppStoreIAP.shouldBlockIAP {
    lockModal.close()
    needToShow = false
    FenixuzAppStoreIAP.presentBlockedAlert(on: context.window)
    return
}
```

Reason: Channel boost / giveaway flows route through StoreKit Premium subscriptions; the receipt would fail server-side. Same `lockModal.close()` + `needToShow = false` pattern as PremiumBoardingController.

---

### `Telegram-Mac/PremiumGiftController.swift` (line ~611)

**Hook inside `buyAppStore = { ... }`, BEFORE the `canPurchasePremium` chain.**

```swift
// Fenixuz: Apple 3.1.1 — StoreKit Premium gift fork'da bloklanadi.
if FenixuzAppStoreIAP.shouldBlockIAP {
    lockModal.close()
    needToShow = false
    FenixuzAppStoreIAP.presentBlockedAlert(on: context.window)
    return
}
```

Reason: gifting Premium to another user routes through StoreKit subscriptions. Same alert flow.

---

### `Telegram-Mac/PremiumGiftingController.swift` (line ~802)

**Hook inside the `buyAppStore = { ... }` closure, BEFORE the `canPurchasePremium` chain.**

```swift
// Fenixuz: Apple 3.1.1 — StoreKit Premium gift code fork'da bloklanadi.
if FenixuzAppStoreIAP.shouldBlockIAP {
    lockModal.close()
    needToShow = false
    FenixuzAppStoreIAP.presentBlockedAlert(on: context.window)
    return
}
```

Reason: multi-recipient gift-code flow routes through StoreKit Premium. Same alert flow.

---

### `Telegram-Mac/PreviewStarGiftController.swift` (line ~1167)

**Hook inside `buyAppStore: (PremiumGiftProduct) -> Void = { premiumProduct in ... }`, BEFORE the `canPurchasePremium` chain.**

```swift
// Fenixuz: Apple 3.1.1 — StoreKit Premium gift (preview) fork'da bloklanadi.
if FenixuzAppStoreIAP.shouldBlockIAP {
    lockModal.close()
    needToShow = false
    FenixuzAppStoreIAP.presentBlockedAlert(on: context.window)
    return
}
```

Reason: gift preview screen also routes through StoreKit. Same alert flow.

---

### `Telegram-Mac/Star_ListScreen.swift` (line ~1395)

**Hook BEFORE the `canPurchasePremium` chain — the Stars top-up funnel.**

```swift
// Fenixuz: Apple 3.1.1 — StoreKit Stars top-up fork'da bloklanadi.
// Stars (XTR) Apple Review tomonidan tasdiqlanadi, lekin bizning fork
// StoreKit transaksiyalarini Telegram serverida nikqachon submit qila olmaydi.
if FenixuzAppStoreIAP.shouldBlockIAP {
    lockModal.close()
    needToShow = false
    FenixuzAppStoreIAP.presentBlockedAlert(on: window)
    return
}
```

Note: uses `window` (the `var window: Window` defined at line 1231), not `context.window`. The Stars list screen creates a `bestWindow(context, getController?())` derivation because it can be presented standalone from contexts that don't have a parent window in `context`.

Reason: Stars top-up goes through `inAppPurchaseManager.buyProduct(...)` with `.stars` or `.starsGift` purpose. Even though Stars themselves are Apple-approved (XTR currency), the StoreKit transaction itself can't be redeemed on Telegram's server for this fork. Block all of them.

---

## Hook inventory summary (this fork)

| File | Hook count | Purpose |
|---|---|---|
| `Telegram-Mac/InAppLinks.swift` | 1 | t.me/$slug invoice gate (§3.1.1) |
| `Telegram-Mac/WebpageModalController.swift` | 1 | Web App invoice gate (§3.1.1) |
| `Telegram-Mac/ChatInterfaceInteraction.swift` | 1 | Chat keyboard payment gate (§3.1.1) |
| `Telegram-Mac/PremiumBoardingController.swift` | 2 | Subscribe + Restore gates (§3.1.1) |
| `Telegram-Mac/GiveawayModalController.swift` | 1 | Giveaway StoreKit gate (§3.1.1) |
| `Telegram-Mac/PremiumGiftController.swift` | 1 | Premium gift StoreKit gate (§3.1.1) |
| `Telegram-Mac/PremiumGiftingController.swift` | 1 | Premium gift-code StoreKit gate (§3.1.1) |
| `Telegram-Mac/PreviewStarGiftController.swift` | 1 | Premium gift preview StoreKit gate (§3.1.1) |
| `Telegram-Mac/Star_ListScreen.swift` | 1 | Stars top-up StoreKit gate (§3.1.1) |

**Total Telegram-owned files with hooks: 9. Total hook insertions: 10.** Every Fenixuz-owned code surface (`FenixuzAppStoreIAP.swift`, `FenixuzL10n.swift`, `FenixuzDemoCodeFetcher.swift`, the Fenixuz Settings controllers, the Tasks tab, etc.) lives in `Telegram-Mac/Fenixuz*.swift` and is the source of truth for these features.

---

## Pull conflict workflow (manual, AI-assisted)

Whenever `git pull upstream master` is run for the TelegramSwift fork:

1. Checkpoint: `git tag pre-pull-checkpoint-$(date +%Y%m%d-%H%M)` + `git branch backup-before-merge-$(date +%Y%m%d)`.
2. `git pull upstream master --no-rebase`.
3. If merge conflicts surface in any of the files listed above, do NOT auto-resolve. Open this file, locate the hook block, re-apply manually at the new line position. Surrounding upstream code wins for everything else.
4. Build via `xcodebuild -workspace Telegram-Mac.xcworkspace -scheme Telegram -configuration Debug -derivedDataPath /tmp/tgmac-dd build CODE_SIGN_STYLE=Automatic` — must succeed. Then launch the app and verify the IAP alert still appears on Subscribe (Premium / Stars / Gift).

Never merge upstream changes without re-applying hooks. If a hook is silently dropped, Apple will re-reject the next submission.

---

## Adding a new hook

1. Put 100% of the logic into `Telegram-Mac/Fenixuz<Feature>.swift`.
2. Keep the Telegram-side hook to 1–8 lines: a single function call OR a tiny accessor method.
3. Append a new section to this file documenting the exact hook code and reason.
4. Commit the FENIXUZ_HOOKS.md update in the same commit as the hook itself.

If a hook grows beyond ~10 lines, refactor — move state into a `Telegram-Mac/Fenixuz*.swift` file and expose a single delegate-style call site.
