import SwiftUI

struct RootView: View {
    @ObservedObject var model: StoreModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            NavigationStack { AppsView(model: model) }
                .tabItem { Label("我的应用", systemImage: "square.grid.2x2.fill") }.tag(0)
            NavigationStack { ActivityView(model: model) }
                .tabItem { Label("活动", systemImage: "clock.arrow.circlepath") }.tag(1)
            NavigationStack { ConnectionView(model: model) }
                .tabItem { Label("连接", systemImage: "wifi") }.tag(2)
        }
        .alert("操作提示", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.clearError() } })) {
            Button("知道了", role: .cancel) { model.clearError() }
        } message: { Text(model.error ?? "") }
    }
}
