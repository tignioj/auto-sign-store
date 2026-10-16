import Foundation
import Testing
@testable import AutoSignStoreCore

private let english = Locale(identifier: "en")
private let chinese = Locale(identifier: "zh-Hans")

@Test func languageSelectionRespectsOverridesAndSystemPreferences() {
    #expect(AppLanguage.english.resolved(preferredLanguages: ["zh-Hans-CN"]) == .english)
    #expect(AppLanguage.simplifiedChinese.resolved(preferredLanguages: ["en-US"]) == .simplifiedChinese)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-Hans"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW", "en"]) == .simplifiedChinese)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "zh-Hans-CN"]) == .simplifiedChinese)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: []) == .english)
}

@Test func translationsUseTheRequestedLanguageAndKeepArgumentsVerbatim() {
    #expect(L10n.string("tab.apps", locale: english) == "My Apps")
    #expect(L10n.string("tab.apps", locale: chinese) == "我的应用")
    #expect(L10n.string("tab.apps", locale: Locale(identifier: "fr")) == "My Apps")
    #expect(L10n.string("sources.installOn", locale: english, arguments: ["小明’s Mac 100%"]) == "Install on 小明’s Mac 100%")
    #expect(L10n.string("apps.progress", locale: english, arguments: [1, 5]) == "1 / 5 processed · View progress")
    #expect(L10n.string("apps.progress", locale: chinese, arguments: [1, 5]) == "1 / 5 已处理 · 查看进度")
    #expect(L10n.string("error.server", locale: english, arguments: [503]) == "Mac service error (503).")
}

@Test(arguments: [0, 1, 2, 50])
func countsUseEnglishPluralRulesAndChineseUnits(count: Int) {
    #expect(L10n.string("count.apps", locale: english, arguments: [count]) == "\(count) \(count == 1 ? "app" : "apps")")
    #expect(L10n.string("count.apps", locale: chinese, arguments: [count]) == "\(count) 个应用")
    #expect(L10n.string("count.days", locale: english, arguments: [count]) == "\(count) \(count == 1 ? "day" : "days")")
    #expect(L10n.string("count.days", locale: chinese, arguments: [count]) == "\(count) 天")
    #expect(L10n.string("count.updates", locale: english, arguments: [count]) == "\(count) app \(count == 1 ? "update" : "updates") available")
}

private func table(_ name: String, locale: Locale) throws -> [String: Any] {
    let url = try #require(L10n.bundle(for: locale).url(forResource: "Localizable", withExtension: name))
    return try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
}

@Test func bothLanguagesCoverEveryClientKeyAndUseMatchingFormatArguments() throws {
    let en = try table("strings", locale: english)
    let zh = try table("strings", locale: chinese)
    let enPlurals = try table("stringsdict", locale: english)
    let zhPlurals = try table("stringsdict", locale: chinese)
    #expect(Set(en.keys) == Set(zh.keys))
    #expect(Set(enPlurals.keys) == Set(zhPlurals.keys))
    let placeholders = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:ld|@)"#)
    for key in en.keys {
        let left = try #require(en[key] as? String)
        let right = try #require(zh[key] as? String)
        #expect(!left.isEmpty && !right.isEmpty, "Empty translation: \(key)")
        func formats(_ text: String) -> [String] {
            placeholders.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                String(text[Range($0.range, in: text)!])
            }.sorted()
        }
        #expect(formats(left) == formats(right), "Mismatched format arguments: \(key)")
    }
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let sources = try #require(FileManager.default.enumerator(at: root.appendingPathComponent("AutoSignStore"), includingPropertiesForKeys: nil))
    let lookup = try NSRegularExpression(pattern: #"L10n\.(?:tr|string)\("([^"]+)""#)
    let allKeys = Set(en.keys).union(enPlurals.keys)
    for case let file as URL in sources where file.pathExtension == "swift" {
        let text = try String(contentsOf: file, encoding: .utf8)
        for match in lookup.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            let key = String(text[Range(match.range(at: 1), in: text)!])
            if !key.contains("\\(") { #expect(allKeys.contains(key), "Missing translation: \(key)") }
        }
    }
}

@Test(arguments: [RefreshState.queued, .running, .completed, .failed])
func everyTaskOperationHasLocalizedStatus(state: RefreshState) throws {
    var job = RefreshJob(id: "task", requestID: "request", deviceUDID: "phone", state: state,
                         items: [], createdAt: Date(), updatedAt: Date())
    for operation in ["refresh", "install", "update"] {
        job.installRequest = operation == "install" ? StoreInstallRequest(requestID: "request", deviceUDID: "phone", sourceURL: "https://example.com/apps.json", bundleIdentifier: "app") : nil
        job.updateRequest = operation == "update" ? RefreshRequest(requestID: "request", deviceUDID: "phone", appIDs: ["app"]) : nil
        for locale in [english, chinese] {
            let title = job.statusTitle(locale: locale)
            #expect(!title.contains("task.") && !title.contains("state."))
            if !state.isTerminal {
                let status = StoreJobStatus(recentJobs: [job], latestJob: nil, devices: [], selectedDeviceID: "other", requestID: nil, locale: locale)
                let message = try #require(status.busyMessage)
                #expect(message.contains("phone"))
                #expect(!message.contains("task.") && !message.contains("device."))
            }
        }
    }
}

@Test func dateAndFileSizeFormattingFollowTheSelectedLocale() {
    let date = Date(timeIntervalSince1970: 1_760_000_000)
    #expect(L10n.date(date, includeTime: false, locale: english) != L10n.date(date, includeTime: false, locale: chinese))
    #expect(!L10n.fileSize(1_234_567, locale: english).isEmpty)
    #expect(!L10n.fileSize(1_234_567, locale: chinese).isEmpty)
}
