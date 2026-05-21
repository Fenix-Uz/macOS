//
//  FenixuzAppStoreIAP.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/AppStoreIAP/Sources/FenixuzAppStoreIAP.swift
//
//  Apple Review 3.1.1 — Fenixuz raqamli obuna sotmaydi. Telegram serveri
//  rasmiy bo'lmagan client uchun StoreKit receipt'larini qabul qilmaydi,
//  shuning uchun har qanday Premium / Stars / Gift / Bot Premium-subscription
//  yo'li pulga yetib bormay UI'da bloklanadi va foydalanuvchi rasmiy
//  Telegram for macOS'ga yo'naltiriladi.
//
//  Mac uchun farqi:
//    - UIAlertController o'rniga TGUIKit `verifyAlert(for: Window, ...)`
//      ishlatamiz (project'da kanonik wrapper).
//    - URL ochish uchun `NSWorkspace.shared.open(url)` (iOS'dagi
//      UIApplication.shared.open o'rniga).
//    - 3 chokepoint:
//        InAppLinks.swift          — t.me/$slug → invoice
//        WebpageModalController    — Web App "web_app_open_invoice"
//        ChatInterfaceInteraction  — keyboard button "payment" / @PremiumBot
//      barchasi `shouldBlock(currency:hasSubscriptionPeriod:)` orqali
//      filtrlanadi va bloklanadigan invoice uchun `presentBlockedAlert` chaqiriladi.
//
//  Detection rule (bot invoice):
//    - currency.uppercased() != "XTR"   (Stars allowed — Apple-da IAP sifatida tasdiqlangan)
//    - subscriptionPeriod != nil        (one-off non-subscription invoice'lar — fizik tovar
//                                        uchun — qoladi)

import Foundation
import AppKit
import TGUIKit
import TelegramCore

public enum FenixuzAppStoreIAP {
    /// Tashqi observabilityyo'q (Mac uchun App Store flag yo'q hozircha) — placeholder bo'lib
    /// turadi, kelajakda agar FBuildConfig kabi flag qo'shilsa, AppDelegate'dan to'ldiriladi.
    public static var isAppStoreBuild: Bool = false

    /// Official Telegram for macOS App Store URL — Mac App Store deep-link sxemasi.
    private static let officialTelegramAppStoreURL = "macappstore://apps.apple.com/app/telegram/id747648890"

    // MARK: - Bot-invoice gate

    /// `true` qaytarsa, ushbu invoice uchun `PaymentsCheckoutController` ko'rsatish
    /// taqiqlanadi va o'rniga blok alert ko'rsatiladi.
    public static func shouldBlock(currency: String, hasSubscriptionPeriod: Bool) -> Bool {
        if currency.uppercased() == "XTR" {
            return false
        }
        return hasSubscriptionPeriod
    }

    /// Convenience overload: `TelegramMediaInvoice` qabul qiladi.
    public static func shouldBlock(invoice: TelegramMediaInvoice) -> Bool {
        return shouldBlock(currency: invoice.currency, hasSubscriptionPeriod: invoice.subscriptionPeriod != nil)
    }

    // MARK: - StoreKit IAP gate

    /// Mac builds — Fenixuz fork StoreKit ishlatmaydi, har qanday IAP funnel bu yerga keladi.
    /// Hozircha Mac tomonda StoreKit chokepoint mavjud emas (iOS'dagi `InAppPurchaseManager`
    /// kabi yagona joy yo'q), shuning uchun bu flag mavjud kelgusi waves uchun
    /// (Mac Premium UI ulanganda).
    public static var shouldBlockIAP: Bool {
        return true
    }

    // MARK: - Alert presentation

    /// Localized alert ko'rsatish — Mac uchun TGUIKit'ning standart wrapper'i.
    /// Main thread'dan chaqiring.
    public static func presentBlockedAlert(on window: Window) {
        let l10n = FenixuzL10n.current
        verifyAlert(
            for: window,
            header: l10n.iap_block_title,
            information: l10n.iap_block_message,
            ok: l10n.iap_block_open_app_store,
            cancel: l10n.iap_block_cancel,
            successHandler: { result in
                if case .basic = result {
                    if let url = URL(string: officialTelegramAppStoreURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        )
    }
}
