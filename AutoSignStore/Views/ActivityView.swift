import SwiftUI

struct ActivityView: View {
    @ObservedObject var model: StoreModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let device = model.currentDevice {
                    Label(device.name, systemImage: "iphone.gen3")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let message = model.otherDeviceTaskMessage {
                    StoreCard {
                        Label(message, systemImage: "desktopcomputer")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if model.jobs.isEmpty {
                    ContentUnavailableView(L10n.tr("activity.empty.title"), systemImage: "clock.arrow.circlepath",
                        description: Text(L10n.tr("activity.empty.detail")))
                        .padding(.top, 70)
                }
                ForEach(model.jobs) { job in
                    StoreCard {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(job.statusTitle, systemImage: job.state.symbol).font(.headline).foregroundStyle(job.state.color)
                                    Text(L10n.date(job.createdAt))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(L10n.tr("count.apps", job.items.count)).font(.caption).foregroundStyle(.secondary)
                            }
                            if !job.state.isTerminal {
                                ProgressView(value: Double(job.items.filter { $0.state.isTerminal }.count), total: Double(max(1, job.items.count)))
                                Text(L10n.tr("activity.backgroundHint"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(job.items) { item in
                                HStack(alignment: .top, spacing: 11) {
                                    if item.state == .running { ProgressView().controlSize(.small).frame(width: 20) }
                                    else { Image(systemName: item.state.symbol).foregroundStyle(item.state.color).frame(width: 20) }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.name).font(.subheadline.bold())
                                        Text(item.message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                        if let expiry = item.expiration {
                                            Text(L10n.tr("activity.expiration", L10n.date(expiry)))
                                                .font(.caption2).foregroundStyle(StoreTheme.accent)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                }
            }
            .padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(StoreTheme.canvas)
        .navigationTitle(L10n.tr("tab.activity"))
        .toolbar {
            Button { Task { await model.sync() } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(model.isLoading).accessibilityLabel(L10n.tr("activity.sync"))
        }
        .refreshable { await model.sync() }
    }
}
