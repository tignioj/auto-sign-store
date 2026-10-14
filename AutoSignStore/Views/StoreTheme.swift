import SwiftUI

enum StoreTheme {
    static let accent = Color(red: 0.08, green: 0.44, blue: 0.38)
    static let ink = Color.primary
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct AppGlyph: View {
    var isStore = true
    var size: CGFloat = 52
    var body: some View {
        Image(systemName: isStore ? "arrow.triangle.2.circlepath" : "app.dashed")
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(isStore ? .white : StoreTheme.accent)
            .frame(width: size, height: size)
            .background(isStore ? StoreTheme.accent : StoreTheme.accent.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: size * 0.24))
            .accessibilityHidden(true)
    }
}

struct StoreCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(StoreTheme.card, in: RoundedRectangle(cornerRadius: 24))
    }
}

extension RefreshState {
    var title: String {
        switch self {
        case .queued: "等待中"
        case .running: "正在刷新"
        case .completed: "已完成"
        case .failed: "需要处理"
        }
    }
    var symbol: String {
        switch self {
        case .queued: "clock"
        case .running: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        }
    }
    var color: Color { self == .failed ? .orange : StoreTheme.accent }
}
