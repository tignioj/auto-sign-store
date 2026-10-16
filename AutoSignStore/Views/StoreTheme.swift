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
        case .queued: L10n.tr("state.queued")
        case .running: L10n.tr("state.running")
        case .completed: L10n.tr("state.completed")
        case .failed: L10n.tr("state.failed")
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
