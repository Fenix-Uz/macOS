//
//  FenixuzL10n.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/Localization/Sources/FenixuzL10n.swift
//
//  Fenixuz string'lari uchun mini-localizer. Telegram'ning .strings fayllariga
//  qo'shmaymiz — upstream merge har gal conflict beradi. Hammasi shu file'da.
//
//  Languages shipped: en (default), uz, ru. Boshqasi → en fallback.
//
//  Mac farqi: iOS `PresentationStrings.primaryComponent.languageCode` o'rniga
//  TelegramSwift `import Localization` -> `appCurrentLanguage.languageCode`
//  ishlatadi. Public API string-darajada bir xil saqlandi:
//    FenixuzL10n.current.settings_title
//    FenixuzL10n(languageCode: "uz").settings_title
//

import Foundation
import Localization

public struct FenixuzL10n {
    private let langCode: String

    public init(languageCode: String) {
        self.langCode = languageCode
    }

    /// Uses the host app's current language. Resolved at call time, so
    /// language switches are picked up without re-instantiating.
    public static var current: FenixuzL10n {
        return FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
    }

    public static func from(languageCode: String) -> FenixuzL10n {
        FenixuzL10n(languageCode: languageCode)
    }

    private func pick(en: String, uz: String, ru: String) -> String {
        switch langCode {
        case "uz": return uz
        case "ru": return ru
        default:   return en
        }
    }

    // MARK: - Tab + Tasks screens

    public var tab_tasks: String {
        pick(en: "Todos", uz: "Vazifalar", ru: "Задачи")
    }

    public var tasks_segment_scheduled: String {
        pick(en: "Scheduled", uz: "Rejalashtirilgan", ru: "Запланированные")
    }

    public var tasks_segment_todo: String {
        pick(en: "To-Do", uz: "Vazifalar", ru: "Задачи")
    }

    public var tasks_relative_today: String {
        pick(en: "Today", uz: "Bugun", ru: "Сегодня")
    }

    public var tasks_relative_tomorrow: String {
        pick(en: "Tomorrow", uz: "Ertaga", ru: "Завтра")
    }

    public var tasks_relative_yesterday: String {
        pick(en: "Yesterday", uz: "Kecha", ru: "Вчера")
    }

    // MARK: - Settings → Fenixuz screen

    public var settings_title: String { "Fenixuz" } // Brand name — never translated

    public var settings_state_enabled: String {
        pick(en: "On", uz: "Yoqilgan", ru: "Включено")
    }

    public var settings_state_disabled: String {
        pick(en: "Off", uz: "O'chirilgan", ru: "Отключено")
    }

    // Section headers
    public var settings_section_interface: String {
        pick(en: "INTERFACE", uz: "INTERFEYS", ru: "ИНТЕРФЕЙС")
    }

    public var settings_section_chat: String {
        pick(en: "CHAT", uz: "CHAT", ru: "ЧАТ")
    }

    public var settings_section_messaging: String {
        pick(en: "MESSAGES", uz: "XABARLAR", ru: "СООБЩЕНИЯ")
    }

    public var settings_section_voice: String {
        pick(en: "VOICE → TEXT", uz: "OVOZ → MATN", ru: "ГОЛОС → ТЕКСТ")
    }

    public var settings_section_protection: String {
        pick(en: "PROTECTION", uz: "HIMOYA", ru: "ЗАЩИТА")
    }

    // Chat section
    public var settings_chat_deletedMessages_title: String {
        pick(en: "Deleted messages", uz: "O'chirilgan xabarlar", ru: "Удалённые сообщения")
    }

    public var settings_chat_deletedMessages_subtitle: String {
        pick(
            en: "Show deleted messages with a trash marker",
            uz: "O'chirilgan xabarlarni belgi bilan ko'rsatish",
            ru: "Показывать удалённые сообщения с меткой"
        )
    }

    public var settings_chat_footer: String {
        pick(
            en: "Changes apply to all chats immediately.",
            uz: "O'zgarishlar barcha chatlarga darhol qo'llaniladi.",
            ru: "Изменения применяются ко всем чатам мгновенно."
        )
    }

    public var settings_chat_firstMessage_title: String {
        pick(en: "Jump to first message", uz: "Birinchi xabarga o'tish", ru: "К первому сообщению")
    }

    public var settings_chat_firstMessage_subtitle: String {
        pick(
            en: "Add a \"View First Message\" entry to the profile menu",
            uz: "Profil menyusida \"View First Message\" tugmasini qo'shish",
            ru: "Добавить пункт «Перейти к первому сообщению» в меню профиля"
        )
    }

    public var settings_chat_ghost_title: String {
        pick(en: "Ghost mode button", uz: "Ghost rejimi tugmasi", ru: "Кнопка режима «Призрак»")
    }

    public var settings_chat_ghost_subtitle: String {
        pick(
            en: "Quick Ghost-mode toggle at the top of the chat list",
            uz: "Chatlar ro'yxati tepasida tezkor Ghost rejimi tugmasi",
            ru: "Быстрое переключение «Призрак» над списком чатов"
        )
    }

    public var settings_chat_camera_title: String {
        pick(en: "Camera picker", uz: "Kamerani tanlash", ru: "Выбор камеры")
    }

    public var settings_chat_camera_subtitle: String {
        pick(
            en: "Long-press the video-message button to switch front/back camera",
            uz: "Video xabar tugmasini uzun bosib old/orqa kamerani tanlash",
            ru: "Долгое нажатие на кнопку видео-сообщения переключает камеру"
        )
    }

    // Interface section
    public var settings_interface_hideFolders_title: String {
        pick(en: "Hide folders", uz: "Jildlarni yashirish", ru: "Скрыть папки")
    }

    public var settings_interface_hideFolders_subtitle: String {
        pick(
            en: "Temporarily hide folders at the top of the chat list",
            uz: "Chatlar ro'yxati tepasidagi jildlarni vaqtinchalik berkitish",
            ru: "Временно скрыть папки в верхней части списка чатов"
        )
    }

    public var settings_interface_stories_title: String {
        pick(en: "Stories panel", uz: "Hikoyalar paneli", ru: "Панель историй")
    }

    public var settings_interface_stories_subtitle: String {
        pick(
            en: "Show stories at the top of the chat list",
            uz: "Chatlar ro'yxati tepasida hikoyalarni ko'rsatish",
            ru: "Показывать истории над списком чатов"
        )
    }

    public var settings_interface_mutualSymbol_title: String {
        pick(en: "Mutual contact badge", uz: "Mutual kontakt belgisi", ru: "Значок взаимного контакта")
    }

    public var settings_interface_mutualSymbol_subtitle: String {
        pick(
            en: "Show the mutual badge in the contacts list",
            uz: "Kontaktlar ro'yxatida mutual belgisini ko'rsatish",
            ru: "Показывать значок взаимного контакта в списке"
        )
    }

    public var settings_interface_footer: String {
        pick(
            en: "Affects only this device.",
            uz: "Faqat sizning qurilmangizga ta'sir qiladi.",
            ru: "Влияет только на это устройство."
        )
    }

    // Messaging section
    public var settings_messaging_textStyle_title: String {
        pick(en: "Text style", uz: "Yozuv uslubi", ru: "Стиль текста")
    }

    public var settings_messaging_autoText_title: String {
        pick(en: "Auto-text suffix", uz: "Avto-matn qo'shimchasi", ru: "Авто-постфикс")
    }

    public var settings_messaging_autoTranslate_title: String {
        pick(en: "Auto-translate", uz: "Avto-tarjima", ru: "Авто-перевод")
    }

    public var settings_messaging_translateToggle_title: String {
        pick(en: "Translate button", uz: "Tarjima tugmasi", ru: "Кнопка перевода")
    }

    public var settings_messaging_translateToggle_subtitle: String {
        pick(
            en: "Show \"Translate\" in the message context menu",
            uz: "Xabar context menyusida \"Translate\" ko'rsatilsin",
            ru: "Показывать «Перевести» в контекстном меню сообщения"
        )
    }

    public var settings_messaging_translateLanguage_title: String {
        pick(en: "Translation language", uz: "Tarjima tili", ru: "Язык перевода")
    }

    public var settings_messaging_footer: String {
        pick(
            en: "Controls the appearance and translation of outgoing messages.",
            uz: "Yuboriladigan xabarlarning ko'rinishi va tarjimasini boshqaradi.",
            ru: "Управляет видом и переводом исходящих сообщений."
        )
    }

    // Voice section
    public var settings_voice_stt_title: String {
        pick(en: "Voice to text", uz: "Ovozni matnga o'girish", ru: "Голос в текст")
    }

    public var settings_voice_stt_subtitle: String {
        pick(
            en: "Show the STT shortcut near the microphone",
            uz: "Mikrofon yonida tezkor STT tugmasini ko'rsatish",
            ru: "Кнопка распознавания рядом с микрофоном"
        )
    }

    public var settings_voice_sttLang_title: String {
        pick(en: "Recognition language", uz: "Tanish tili", ru: "Язык распознавания")
    }

    // Protection section
    public var settings_protection_foreign_title: String {
        pick(en: "Block foreign numbers", uz: "Xorijiy raqamlarni bloklash", ru: "Блокировать иностранные номера")
    }

    public var settings_protection_foreign_subtitle: String {
        pick(
            en: "Automatically block messages from numbers in other countries",
            uz: "Boshqa davlat raqamlaridan kelgan xabarlarni avtomatik bloklash",
            ru: "Автоматически блокировать сообщения с зарубежных номеров"
        )
    }

    public var settings_protection_apk_title: String {
        pick(en: "Block APK files", uz: "APK fayllarni bloklash", ru: "Блокировать APK-файлы")
    }

    public var settings_protection_apk_subtitle: String {
        pick(
            en: "Hide .apk files in chats (Android packages)",
            uz: "Chatlarda .apk fayllarni yashirish (Android dasturlari)",
            ru: "Скрывать .apk-файлы в чатах (Android-пакеты)"
        )
    }

    public var settings_protection_footer: String {
        pick(
            en: "Protection from spam and harmful content.",
            uz: "Spam va zararli kontentdan himoya.",
            ru: "Защита от спама и вредоносного контента."
        )
    }

    // MARK: - Sub-controllers (placeholder for Wave 5)

    public var sub_comingSoon_title: String {
        pick(en: "Coming soon", uz: "Tez orada", ru: "Скоро")
    }

    public var sub_comingSoon_message: String {
        pick(
            en: "This screen is available in the iOS Fenixuz app. The macOS port is in progress.",
            uz: "Bu ekran iOS Fenixuz ilovasida mavjud. macOS porti ustida ishlanmoqda.",
            ru: "Этот экран есть в iOS-приложении Fenixuz. macOS-порт в разработке."
        )
    }

    // MARK: - App Store IAP compliance (Apple guideline 3.1.1)

    public var iap_block_title: String {
        pick(
            en: "Telegram Premium",
            uz: "Telegram Premium",
            ru: "Telegram Premium"
        )
    }

    public var iap_block_message: String {
        pick(
            en: "Premium subscriptions are not sold in this app. To subscribe to Telegram Premium, please install the official Telegram app from the App Store and subscribe there.",
            uz: "Premium obuna bu ilovada sotilmaydi. Telegram Premium'ga obuna bo'lish uchun App Store'dan rasmiy Telegram ilovasini o'rnating va obunani o'sha yerda amalga oshiring.",
            ru: "Premium-подписка в этом приложении не продаётся. Чтобы подписаться на Telegram Premium, установите официальное приложение Telegram из Mac App Store и оформите подписку там."
        )
    }

    public var iap_block_open_app_store: String {
        pick(
            en: "Open App Store",
            uz: "App Store'da ochish",
            ru: "Открыть App Store"
        )
    }

    public var iap_block_cancel: String {
        pick(
            en: "Cancel",
            uz: "Bekor qilish",
            ru: "Отмена"
        )
    }

    // MARK: - Demo auto-fill dialog (Apple Review)

    public var demo_dialog_title: String {
        pick(en: "Demo Mode", uz: "Demo rejim", ru: "Демо-режим")
    }

    public var demo_dialog_fetching: String {
        pick(
            en: "Fetching verification code. This usually takes 2-10 seconds.",
            uz: "Tasdiqlash kodi olinmoqda. Odatda 2-10 soniya oladi.",
            ru: "Получение кода подтверждения. Обычно занимает 2-10 секунд."
        )
    }

    public func demo_dialog_fetching_elapsed(_ seconds: Int) -> String {
        pick(
            en: "Fetching verification code… \(seconds)s elapsed\n\nFor App Store reviewers only.\nTap 'Cancel auto-fill' for manual entry.",
            uz: "Kod olinmoqda… \(seconds)s\n\nFaqat App Store reviewer uchun.\nQo'lda kiritish uchun 'Bekor qilish' tugmasini bosing.",
            ru: "Получение кода… прошло \(seconds)с\n\nТолько для рецензентов App Store.\nДля ручного ввода нажмите «Отменить»."
        )
    }

    public var demo_dialog_cancel: String {
        pick(en: "Cancel auto-fill", uz: "Avto-to'ldirishni bekor qilish", ru: "Отменить авто-ввод")
    }

    public var demo_dialog_timeout: String {
        pick(
            en: "Auto-fetch unavailable (timeout). Tap 'Cancel auto-fill' to enter the code manually.",
            uz: "Avto-fetch ishlamadi (timeout). Kodni qo'lda kiritish uchun 'Bekor qilish'ni bosing.",
            ru: "Авто-ввод недоступен (timeout). Нажмите «Отменить» и введите код вручную."
        )
    }

    public func demo_dialog_received(_ code: String) -> String {
        pick(
            en: "Code received: \(code)\nSigning in…",
            uz: "Kod qabul qilindi: \(code)\nTizimga kirilmoqda…",
            ru: "Код получен: \(code)\nВход в систему…"
        )
    }

    // MARK: - STT language menu

    public static let sttSupportedLanguages: [(id: String, name: String)] = [
        ("en-US", "🇬🇧 English"),
        ("ru-RU", "🇷🇺 Русский"),
        ("tr-TR", "🇹🇷 Türkçe"),
        ("de-DE", "🇩🇪 Deutsch"),
        ("fr-FR", "🇫🇷 Français"),
        ("es-ES", "🇪🇸 Español"),
        ("it-IT", "🇮🇹 Italiano"),
        ("pt-BR", "🇧🇷 Português"),
        ("ar-SA", "🇸🇦 العربية"),
        ("zh-CN", "🇨🇳 中文"),
        ("ja-JP", "🇯🇵 日本語"),
        ("ko-KR", "🇰🇷 한국어"),
        ("hi-IN", "🇮🇳 हिन्दी"),
        ("nl-NL", "🇳🇱 Nederlands"),
        ("pl-PL", "🇵🇱 Polski"),
        ("sv-SE", "🇸🇪 Svenska"),
        ("da-DK", "🇩🇰 Dansk"),
        ("fi-FI", "🇫🇮 Suomi"),
        ("nb-NO", "🇳🇴 Norsk"),
        ("uk-UA", "🇺🇦 Українська"),
        ("cs-CZ", "🇨🇿 Čeština"),
        ("el-GR", "🇬🇷 Ελληνικά"),
        ("ro-RO", "🇷🇴 Română"),
        ("hu-HU", "🇭🇺 Magyar"),
        ("sk-SK", "🇸🇰 Slovenčina"),
        ("hr-HR", "🇭🇷 Hrvatski"),
        ("ca-ES", "🇪🇸 Català"),
        ("vi-VN", "🇻🇳 Tiếng Việt"),
        ("ms-MY", "🇲🇾 Bahasa Melayu"),
        ("id-ID", "🇮🇩 Bahasa Indonesia"),
        ("th-TH", "🇹🇭 ไทย"),
        ("he-IL", "🇮🇱 עברית"),
        ("en-GB", "🇬🇧 English (UK)"),
        ("en-AU", "🇦🇺 English (AU)"),
        ("fr-CA", "🇨🇦 Français (CA)"),
        ("es-MX", "🇲🇽 Español (MX)"),
        ("zh-TW", "🇹🇼 中文 (繁體)"),
        ("pt-PT", "🇵🇹 Português (PT)"),
    ]

    public static func sttLanguageName(for localeId: String) -> String {
        for (id, name) in sttSupportedLanguages where id == localeId {
            return name
        }
        return localeId
    }

    // MARK: - Text style screen

    public var textStyle_screenTitle: String {
        pick(en: "Message Style", uz: "Xabar uslubi", ru: "Стиль сообщений")
    }

    public var textStyle_listHeader: String {
        pick(en: "STYLE", uz: "USLUB", ru: "СТИЛЬ")
    }

    public var textStyle_selectedLabel: String {
        pick(en: "✓ Selected", uz: "✓ Tanlangan", ru: "✓ Выбрано")
    }

    public var textStyle_footer: String {
        pick(
            en: "All your outgoing text messages will be formatted in the selected style.",
            uz: "Yuborayotgan barcha xabarlaringiz shu uslubda formatlanadi.",
            ru: "Все исходящие сообщения будут оформлены в выбранном стиле."
        )
    }

    // MARK: - Auto-text screen

    public var autoText_screenTitle: String {
        pick(en: "Auto Suffix", uz: "Avtomatik qo'shimcha", ru: "Авто-подпись")
    }

    public var autoText_info: String {
        pick(
            en: "When enabled, the suffix below is appended to every outgoing message. Example: typing 'Hello' with suffix '(Pro)' sends 'Hello (Pro)'.",
            uz: "Bu funksiya yoqilganda, yozgan xabarning oxiriga avtomatik ravishda quyidagi matn qo'shiladi. Masalan: \"Salom\" + \"(Pro)\" → \"Salom (Pro)\".",
            ru: "Когда включено, к каждому исходящему сообщению добавляется указанный ниже суффикс. Например: «Привет» + «(Pro)» → «Привет (Pro)»."
        )
    }

    public var autoText_toggleTitle: String {
        pick(en: "Auto suffix", uz: "Avtomatik qo'shimcha", ru: "Авто-подпись")
    }

    public var autoText_toggleSubtitle: String {
        pick(
            en: "Append the suffix to every outgoing message",
            uz: "Har bir xabar yuborishda qo'shimcha matn qo'shish",
            ru: "Добавлять подпись к каждому исходящему сообщению"
        )
    }

    public var autoText_inputHeader: String {
        pick(en: "SUFFIX", uz: "QO'SHIMCHA MATN", ru: "СУФФИКС")
    }

    public var autoText_inputPlaceholder: String {
        pick(en: "Enter the suffix…", uz: "Qo'shimcha matnni kiriting…", ru: "Введите суффикс…")
    }

    public var autoText_inputHint: String {
        pick(
            en: "Saved automatically. Up to 300 characters.",
            uz: "Avtomatik saqlanadi. 300 belgigacha.",
            ru: "Сохраняется автоматически. До 300 символов."
        )
    }

    // MARK: - Auto-translate screen

    public var autoTranslate_screenTitle: String {
        pick(en: "Auto Translate", uz: "Avtomatik tarjima", ru: "Авто-перевод")
    }

    public var autoTranslate_info: String {
        pick(
            en: "When enabled, every outgoing message is automatically translated to the selected language before sending.",
            uz: "Yoqilganda, yuborayotgan barcha xabarlaringiz tanlangan tilga avtomatik tarjima qilinadi.",
            ru: "Когда включено, каждое исходящее сообщение автоматически переводится на выбранный язык."
        )
    }

    public var autoTranslate_toggleTitle: String {
        pick(en: "Auto translate", uz: "Avtomatik tarjima", ru: "Авто-перевод")
    }

    public var autoTranslate_toggleSubtitle: String {
        pick(
            en: "Translate every outgoing message",
            uz: "Barcha chiqayotgan xabarlarni tarjima qilish",
            ru: "Переводить все исходящие сообщения"
        )
    }

    public var autoTranslate_langHeader: String {
        pick(en: "LANGUAGE", uz: "TIL", ru: "ЯЗЫК")
    }

    public var autoTranslate_labelSelected: String {
        pick(en: "✓ Selected", uz: "✓ Tanlangan", ru: "✓ Выбрано")
    }

    public var autoTranslate_labelDownloaded: String {
        pick(en: "Downloaded", uz: "Yuklab olingan", ru: "Загружено")
    }

    public var autoTranslate_labelDownload: String {
        pick(en: "Download", uz: "Yuklash", ru: "Загрузить")
    }

    public func autoTranslate_languageName(_ key: String) -> String {
        switch key {
        case "en": return pick(en: "English", uz: "Ingliz tili", ru: "Английский")
        case "ru": return pick(en: "Russian", uz: "Rus tili", ru: "Русский")
        case "uz": return pick(en: "Uzbek",   uz: "O'zbek tili", ru: "Узбекский")
        case "tr": return pick(en: "Turkish", uz: "Turk tili", ru: "Турецкий")
        case "de": return pick(en: "German",  uz: "Nemis tili", ru: "Немецкий")
        case "fr": return pick(en: "French",  uz: "Fransuz tili", ru: "Французский")
        case "es": return pick(en: "Spanish", uz: "Ispan tili", ru: "Испанский")
        case "it": return pick(en: "Italian", uz: "Italyan tili", ru: "Итальянский")
        case "ar": return pick(en: "Arabic",  uz: "Arab tili", ru: "Арабский")
        case "zh": return pick(en: "Chinese", uz: "Xitoy tili", ru: "Китайский")
        case "ja": return pick(en: "Japanese", uz: "Yapon tili", ru: "Японский")
        case "ko": return pick(en: "Korean",  uz: "Koreys tili", ru: "Корейский")
        default:   return key
        }
    }

    // MARK: - Translation language picker (target list)

    public var translationLang_screenTitle: String {
        pick(en: "Translation Languages", uz: "Tarjima tillari", ru: "Языки перевода")
    }

    public var translationLang_footer: String {
        pick(
            en: "Choose which language other people's messages will be translated into.",
            uz: "Boshqa foydalanuvchilarning xabarlari qaysi tilga tarjima qilinishi kerakligini tanlang.",
            ru: "Выберите язык, на который будут переводиться сообщения собеседников."
        )
    }

    // MARK: - Chat pincode

    public var pincode_set_title: String {
        pick(en: "Set Pincode", uz: "Pincode o'rnating", ru: "Установить пинкод")
    }

    public var pincode_set_subtitle: String {
        pick(en: "Enter a 4-digit code", uz: "4 raqamli kodni kiriting", ru: "Введите 4-значный код")
    }

    public var pincode_set_confirmTitle: String {
        pick(en: "Confirm", uz: "Tasdiqlang", ru: "Подтвердите")
    }

    public var pincode_set_confirmSubtitle: String {
        pick(en: "Enter the code again", uz: "Kodni qayta kiriting", ru: "Введите код ещё раз")
    }

    public var pincode_verify_title: String {
        pick(en: "Enter Pincode", uz: "Pincode kiriting", ru: "Введите пинкод")
    }

    public var pincode_verify_subtitle: String {
        pick(en: "Pincode required to open this chat", uz: "Chatni ochish uchun kod kerak", ru: "Для открытия чата нужен пинкод")
    }

    public var pincode_remove_title: String {
        pick(en: "Confirm Pincode", uz: "Pincode tasdiqlang", ru: "Подтвердите пинкод")
    }

    public var pincode_remove_subtitle: String {
        pick(
            en: "Enter the current code to remove it",
            uz: "O'chirish uchun amaldagi kodni kiriting",
            ru: "Введите текущий код для удаления"
        )
    }

    public var pincode_error_mismatch: String {
        pick(en: "Codes do not match", uz: "Kod mos kelmadi", ru: "Коды не совпадают")
    }

    public var pincode_error_wrong: String {
        pick(en: "Wrong pincode", uz: "Noto'g'ri kod", ru: "Неправильный пинкод")
    }

    // MARK: - Edited message history

    public var editedHistory_screenTitle: String {
        pick(en: "Edit History", uz: "Tahrirlar tarixi", ru: "История изменений")
    }

    public var editedHistory_listHeader: String {
        pick(en: "VERSIONS", uz: "VERSIYALAR", ru: "ВЕРСИИ")
    }

    public var editedHistory_currentLabel: String {
        pick(en: "Current", uz: "Joriy", ru: "Текущее")
    }

    public var editedHistory_empty: String {
        pick(
            en: "No previous versions recorded.",
            uz: "Oldingi versiyalar mavjud emas.",
            ru: "Прошлые версии не записаны."
        )
    }

    public var editedHistory_footer: String {
        pick(
            en: "Edits captured locally on this device.",
            uz: "Tahrirlar shu qurilmada lokal ravishda saqlangan.",
            ru: "Изменения сохранены локально на этом устройстве."
        )
    }

    // MARK: - Speech-to-text errors

    public var stt_error_denied: String {
        pick(
            en: "Speech recognition permission denied. Enable it in System Settings.",
            uz: "Ovozni aniqlash ruxsati berilmagan. Sozlamalardan yoqing.",
            ru: "Разрешение на распознавание речи отклонено. Включите в настройках системы."
        )
    }

    public var stt_error_restricted: String {
        pick(
            en: "Speech recognition is restricted on this device.",
            uz: "Bu qurilmada ovozni aniqlash cheklangan.",
            ru: "Распознавание речи ограничено на этом устройстве."
        )
    }

    public var stt_error_pending: String {
        pick(
            en: "Speech recognition permission pending.",
            uz: "Ovozni aniqlash ruxsati kutilmoqda.",
            ru: "Разрешение на распознавание речи ожидается."
        )
    }

    public var stt_error_unavailable: String {
        pick(
            en: "Speech recognition is unavailable for the selected language.",
            uz: "Tanlangan til uchun ovozni aniqlash mavjud emas.",
            ru: "Распознавание речи недоступно для выбранного языка."
        )
    }

    public var stt_error_setup: String {
        pick(
            en: "Could not start speech recognition.",
            uz: "Ovozni aniqlash so'rovini yaratib bo'lmadi.",
            ru: "Не удалось запустить распознавание речи."
        )
    }

    // MARK: - Tasks screens

    public var tasks_folderHeader: String {
        pick(en: "FOLDERS", uz: "PAPKALAR", ru: "ПАПКИ")
    }

    public var tasks_addFolder: String {
        pick(en: "+ Add Folder", uz: "+ Papka qo'shish", ru: "+ Добавить папку")
    }

    public var tasks_addTask: String {
        pick(en: "+ Add Task", uz: "+ Vazifa qo'shish", ru: "+ Добавить задачу")
    }

    public var tasks_newFolder: String {
        pick(en: "New Folder", uz: "Yangi papka", ru: "Новая папка")
    }

    public var tasks_newTask: String {
        pick(en: "New Task", uz: "Yangi vazifa", ru: "Новая задача")
    }

    public var tasks_folderNamePlaceholder: String {
        pick(en: "Folder name", uz: "Papka nomi", ru: "Название папки")
    }

    public var tasks_taskTitlePlaceholder: String {
        pick(en: "Task title", uz: "Vazifa nomi", ru: "Название задачи")
    }

    public var tasks_taskDescPlaceholder: String {
        pick(en: "Description (optional)", uz: "Tavsif (ixtiyoriy)", ru: "Описание (необязательно)")
    }

    public var tasks_markCompleted: String {
        pick(en: "Mark completed", uz: "Bajarilgan deb belgilash", ru: "Отметить выполненной")
    }

    public var tasks_deleteTask: String {
        pick(en: "Delete task", uz: "Vazifani o'chirish", ru: "Удалить задачу")
    }

    public var tasks_taskDetailTitle: String {
        pick(en: "Task", uz: "Vazifa", ru: "Задача")
    }

    public var tasks_footer: String {
        pick(
            en: "Your tasks are stored locally on this device.",
            uz: "Vazifalaringiz shu qurilmada lokal saqlanadi.",
            ru: "Задачи хранятся локально на этом устройстве."
        )
    }

    public var tasks_listFooter: String {
        pick(
            en: "Tap a task to edit. Drag to reorder.",
            uz: "Tahrirlash uchun vazifani bosing.",
            ru: "Нажмите на задачу для редактирования."
        )
    }

    public var tasks_detailFooter: String {
        pick(
            en: "Changes are saved automatically.",
            uz: "O'zgarishlar avtomatik saqlanadi.",
            ru: "Изменения сохраняются автоматически."
        )
    }

    public var alert_create: String {
        pick(en: "Create", uz: "Yaratish", ru: "Создать")
    }

    public var alert_cancel: String {
        pick(en: "Cancel", uz: "Bekor qilish", ru: "Отмена")
    }

    // MARK: - Foreign user banner

    public var foreignUser_bannerMessage: String {
        pick(
            en: "Warning: this contact is from a different country. Verify identity before sharing private information.",
            uz: "Diqqat: bu foydalanuvchi boshqa davlatdan. Shaxsiy ma'lumot ulashishdan oldin tekshiring.",
            ru: "Внимание: этот контакт из другой страны. Проверьте подлинность перед передачей личной информации."
        )
    }

    // MARK: - Text style picker labels

    public func textStyle_displayName(_ key: String) -> String {
        switch key {
        case "bold":
            return pick(en: "Bold", uz: "Qalin (Bold)", ru: "Жирный (Bold)")
        case "italic":
            return pick(en: "Italic", uz: "Kiyshiq (Italic)", ru: "Курсив (Italic)")
        case "monospace":
            return pick(en: "Monospace (Code)", uz: "Monospace (Kod)", ru: "Моноширинный (Код)")
        case "strikethrough":
            return pick(en: "Strikethrough", uz: "Chizilgan (Strikethrough)", ru: "Зачёркнутый (Strikethrough)")
        case "underline":
            return pick(en: "Underline", uz: "Tagiga chizilgan (Underline)", ru: "Подчёркнутый (Underline)")
        case "spoiler":
            return "Spoiler"
        default:
            return pick(en: "Plain (None)", uz: "Uslubsiz (Oddiy)", ru: "Без стиля (Обычный)")
        }
    }
}
