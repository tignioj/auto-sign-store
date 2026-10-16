import SwiftUI

@main
struct AutoSignStoreApp: App {
    @StateObject private var model = StoreModel()
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .environment(\.locale, L10n.locale)
                .id(language)
                .tint(StoreTheme.accent)
                .task { await model.sync() }
                .onChange(of: scenePhase) { _, phase in
                    Task { await model.sceneChanged(active: phase == .active) }
                }
        }
    }
}
