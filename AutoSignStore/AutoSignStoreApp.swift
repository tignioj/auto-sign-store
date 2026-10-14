import SwiftUI

@main
struct AutoSignStoreApp: App {
    @StateObject private var model = StoreModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .tint(StoreTheme.accent)
                .task { await model.sync() }
                .onChange(of: scenePhase) { _, phase in
                    Task { await model.sceneChanged(active: phase == .active) }
                }
        }
    }
}
