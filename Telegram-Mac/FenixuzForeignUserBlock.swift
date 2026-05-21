//
//  FenixuzForeignUserBlock.swift
//  Telegram-Mac
//
//  iOS portasi:
//    submodules/Fenixuz/ForeignUserBlock/Sources/ProForeignUserBlockHelper.swift
//    submodules/Fenixuz/ForeignUserBlock/Sources/ChatList_ProForeignUserBlockHelper.swift
//
//  Bu modul faqat DATA layer'ni taqdim etadi:
//    - extractCountryCallingCode(from:) — telefon raqamidan davlat kodini ajratadi
//    - arePhoneNumbersFromSameCountry(_:_:) — ikkita raqam bir davlatdanmi
//    - isForeignUser(peer:myPhone:) — peer xorijiy foydalanuvchimi
//
//  Mac UI consumer'lar (chat list filter, message filter) hozir ulanmagan.
//  Wave 5 da `Telegram-Mac/ChatListController.swift` va kerakli boshqa joylarga
//  ulanadi. Bu Wave 4 da faqat data layer mavjudligini ta'minlaymiz, shunda
//  consumer kod kelajakda hech qanday extra logikaga muhtoj bo'lmaydi —
//  global funksiyalar fork uchun universal helper.

import Foundation
import Postbox
import TelegramCore

/// Telefon raqamidan davlat kodini (country calling code) ajratadi.
/// Eng uzun moslikni qidiradi (longest prefix match).
///   "998901234567" → "998"
///   "79001234567"  → "7"
///   "14155551234"  → "1"
public func extractCountryCallingCode(from phoneNumber: String) -> String? {
    let digits = phoneNumber.filter { $0.isNumber }
    guard !digits.isEmpty else { return nil }

    // 3-digit codes (longest match first)
    let threeDigitCodes: Set<String> = [
        // CIS + Central Asia
        "998", "992", "993", "994", "995", "996", "374", "375", "380", "373", "371", "370", "372",
        // Middle East
        "971", "966", "965", "968", "974", "973", "964", "963", "962", "961", "967",
        // Asia
        "856", "855", "852", "853", "886", "880", "977", "960", "976", "975", "670", "673", "959",
        // Africa
        "234", "254", "255", "256", "251", "233", "237", "243", "221", "225", "227", "223", "226",
        "229", "228", "231", "232", "235", "236", "241", "242", "244", "249", "252", "253", "257",
        "258", "261", "263", "260", "264", "265", "266", "267", "268", "269",
        // Europe
        "351", "352", "353", "354", "355", "356", "357", "358", "359", "381", "382", "383", "385",
        "386", "387", "389", "420", "421",
        // Latin America
        "591", "592", "593", "594", "595", "596", "597", "598",
        // Other
        "212", "213", "216", "218", "220", "222", "238", "239", "240", "245", "246", "247", "248",
        "250", "262", "290", "291", "297", "298", "299"
    ]

    let twoDigitCodes: Set<String> = [
        "20", "27", "30", "31", "32", "33", "34", "36", "39", "40", "41", "43", "44", "45", "46",
        "47", "48", "49", "51", "52", "53", "54", "55", "56", "57", "58", "60", "61", "62", "63",
        "64", "65", "66", "81", "82", "84", "86", "90", "91", "92", "93", "94", "95", "98"
    ]

    let singleDigitCodes: Set<String> = ["1", "7"]

    if digits.count >= 3 {
        let prefix3 = String(digits.prefix(3))
        if threeDigitCodes.contains(prefix3) { return prefix3 }
    }
    if digits.count >= 2 {
        let prefix2 = String(digits.prefix(2))
        if twoDigitCodes.contains(prefix2) { return prefix2 }
    }
    if digits.count >= 1 {
        let prefix1 = String(digits.prefix(1))
        if singleDigitCodes.contains(prefix1) { return prefix1 }
    }
    return nil
}

/// Ikki telefon raqami bir davlat kodiga tegishlimi.
/// Biror raqam yo'q yoki country code aniqlanmasa, false — himoya sifatida bloklash.
public func arePhoneNumbersFromSameCountry(_ phone1: String?, _ phone2: String?) -> Bool {
    guard let p1 = phone1, let p2 = phone2 else { return false }
    guard let c1 = extractCountryCallingCode(from: p1),
          let c2 = extractCountryCallingCode(from: p2) else { return false }
    return c1 == c2
}

/// Berilgan peer xorijiy foydalanuvchimi (foreign user).
/// 1:1 shaxsiy chatlar uchun ishlaydi. Guruh, kanal, bot, Saved Messages,
/// Telegram service accounts (777000, 333000) uchun false qaytaradi.
public func isForeignUser(peer: Peer?, myPhone: String?) -> Bool {
    guard let user = peer as? TelegramUser else { return false }
    if user.botInfo != nil { return false }
    if user.id.isReplies || user.id.namespace != Namespaces.Peer.CloudUser { return false }

    let userId = user.id.id._internalGetInt64Value()
    if userId == 777000 || userId == 333000 { return false }

    guard let myP = myPhone, !myP.isEmpty,
          let peerP = user.phone, !peerP.isEmpty else {
        return false
    }
    return !arePhoneNumbersFromSameCountry(myP, peerP)
}
