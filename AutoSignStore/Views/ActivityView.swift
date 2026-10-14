import SwiftUI

struct ActivityView: View {
    @ObservedObject var model: StoreModel

    private var visibleJobs: [RefreshJob] {
        var jobs = model.jobs
        if let active = model.activeJob, active.deviceUDID == model.selectedDeviceID {
            jobs.removeAll { $0.id == active.id }
            jobs.insert(active, at: 0)
        }
        return jobs
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if visibleJobs.isEmpty {
                    ContentUnavailableView("还没有任务记录", systemImage: "clock.arrow.circlepath",
                        description: Text("安装应用或刷新签名后，这里会显示 Mac 的执行进度与结果。"))
                        .padding(.top, 70)
                }
                ForEach(visibleJobs) { job in
                    StoreCard {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(job.state == .running ? (job.installRequest == nil ? "正在刷新" : "正在安装") : job.state.title, systemImage: job.state.symbol).font(.headline).foregroundStyle(job.state.color)
                                    Text(job.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(job.items.count) 个应用").font(.caption).foregroundStyle(.secondary)
                            }
                            if !job.state.isTerminal {
                                ProgressView(value: Double(job.items.filter { $0.state.isTerminal }.count), total: Double(max(1, job.items.count)))
                                Text("Mac 独立执行任务，关闭手机应用后仍会继续。")
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
                                            Text("到期：\(expiry.formatted(date: .abbreviated, time: .shortened))")
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
        .navigationTitle("活动")
        .toolbar {
            Button { Task { await model.sync() } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(model.isLoading).accessibilityLabel("同步任务")
        }
        .refreshable { await model.sync() }
    }
}
