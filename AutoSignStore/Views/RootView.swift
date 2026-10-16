import SwiftUI

struct RootView: View {
    @ObservedObject var model: StoreModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            NavigationStack { AppsView(model: model) }
                .tabItem { Label(L10n.tr("tab.apps"), systemImage: "square.grid.2x2.fill") }.badge(model.updates.count).tag(0)
            NavigationStack { SourcesView(model: model) }
                .tabItem { Label(L10n.tr("tab.sources"), systemImage: "shippingbox.fill") }.tag(3)
            NavigationStack { ActivityView(model: model) }
                .tabItem { Label(L10n.tr("tab.activity"), systemImage: "clock.arrow.circlepath") }.tag(1)
            NavigationStack { ConnectionView(model: model) }
                .tabItem { Label(L10n.tr("tab.connection"), systemImage: "wifi") }.tag(2)
        }
        .alert(L10n.tr("common.alert"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.clearError() } })) {
            Button(L10n.tr("common.ok"), role: .cancel) { model.clearError() }
        } message: { Text(model.error ?? "") }
    }
}
