import Cocoa

public final class ApiEnvironment {
    public static var apiId:Int32 {
        return 35846757
    }
    public static var apiHash:String {
        return "67cdc52f3eda13727603d4e779ee2894"
    }
    
    public static var bundleId: String {
        return "uz.fenixuz.app"
    }
    /// Eski bundle ID — `uz.fenixuz.macapp`'dan `uz.fenixuz.app`'ga (Universal Purchase uchun iOS bilan moslash)
    /// rename qilingach, eski container (group) ni yangi joyga ko'chiramiz. Yagona safar ishlatiladi.
    public static var legacyBundleId: String {
        return "uz.fenixuz.macapp"
    }
    public static var legacyGroup: String {
        return teamId + "." + legacyBundleId
    }
    public static var intentsBundleId: String {
        return teamId + "." + bundleId + ".FocusIntents"
    }
    public static var teamId: String {
        return "ZDBP5RSRZF"
    }
    
    
    
    public static var containerURL: URL? {
        let appGroupName = ApiEnvironment.group
        let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)?.appendingPathComponent(prefix)
        if let containerUrl = containerUrl {
            try? FileManager.default.createDirectory(at: containerUrl, withIntermediateDirectories: true, attributes: nil)
            return containerUrl
        }
        return nil
    }
    
    public static func migrate() {
        if let containerURL = containerURL, let legacy = legacyContainerURL, let sequence = FileManager.default.enumerator(atPath: legacy.path) {
            let contents = try? FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil, options: [])
            if let contents = contents, !contents.isEmpty {
                return
            }
            for value in sequence {
                if let value = value as? String {
                    if !prefixList.contains(value) {
                        try? FileManager.default.moveItem(at: legacy.appendingPathComponent(value), to: containerURL.appendingPathComponent(value))
                    }
                }
            }
        }
        // Fenixuz: bundle ID `uz.fenixuz.macapp` → `uz.fenixuz.app` rename'idan keyin
        // eski app-group container'idagi ma'lumotlarni (account session, settings) yangi joyga ko'chiramiz.
        // Bir martagina ishlatiladi: yangi container bo'sh bo'lsa va eski container ma'lumot saqlasa.
        migrateLegacyBundleContainerIfNeeded()
    }

    private static func migrateLegacyBundleContainerIfNeeded() {
        guard let newContainer = containerURL else { return }
        // Yangi container bo'sh emasligini tekshiramiz — agar to'lgan bo'lsa migratsiya allaqachon bo'lgan
        let newContents = (try? FileManager.default.contentsOfDirectory(at: newContainer, includingPropertiesForKeys: nil)) ?? []
        if !newContents.isEmpty {
            return
        }
        let legacyAppGroup = legacyGroup
        guard let legacyContainerRoot = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: legacyAppGroup) else {
            return
        }
        let legacyContainer = legacyContainerRoot.appendingPathComponent(prefix)
        guard FileManager.default.fileExists(atPath: legacyContainer.path) else { return }
        let oldContents = (try? FileManager.default.contentsOfDirectory(atPath: legacyContainer.path)) ?? []
        for name in oldContents {
            let src = legacyContainer.appendingPathComponent(name)
            let dst = newContainer.appendingPathComponent(name)
            try? FileManager.default.moveItem(at: src, to: dst)
        }
    }
    
    public static var legacyContainerURL: URL? {
        let appGroupName = ApiEnvironment.group
        let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        return containerUrl
    }
    
    public static var group: String {
        return teamId + "." + bundleId
    }
    
    public static var appData: Data {
        let apiData = evaluateApiData() ?? ""
        let dict:[String: String] = ["bundleId": bundleId, "data": apiData]
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }
    public static var language: String {
        return "macos"
    }
    
    public static var prefixList:[String] {
        return ["debug", "stable", "appstore", "beta"]
    }
    
    public static var resolvedDeviceName:[String : String]? {
        if let file = Bundle.main.path(forResource: "mac_devices", ofType: "txt") {
            if let string = try? String(contentsOf: .init(fileURLWithPath: file)) {
                let lines = string.components(separatedBy: "\n\n")
                
                var result:[String : String] = [:]
                for line in lines {
                    let resolved = line.components(separatedBy: "\n")
                    if resolved.count == 2 {
                        result[resolved[1]] = resolved[0]
                    }
                }
                
                return result
            }
        }
        return nil
    }
    
    public static var prefix: String {
        var prefix: String = ""
        switch Configuration.value(for: .source) {
        case "DEBUG":
            prefix = "debug"
        case "STABLE":
            prefix = "stable"
        case "APP_STORE":
            prefix = "appstore"
        default:
            prefix = "beta"
        }
        return prefix
    }
    
    public static var version: String {
        var suffix: String = ""
        
        suffix = Configuration.value(for: .source) ?? "DEBUG"
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
        return "\(shortVersion) \(suffix)"
    }
    
    public static var premiumProductId: String {
        return "org.telegram.telegramPremium.monthly"
    }
}



