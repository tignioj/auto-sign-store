import SwiftUI

struct AppsView: View {
    @ObservedObject var model: StoreModel
    @State private var selectedApp: StoreApp?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !model.hasCredentials {
                    welcome
                } else {
                    connectionPill
                    summary
                    if model.devices.count > 0 { devicePicker }
                    if model.supportsUpdates { updatesSection }
                    if let job = model.activeJob, !job.state.isTerminal {
                        Button { model.selectedTab = 1 } label: {
                            StoreCard {
                                HStack(spacing: 14) {
                                    ProgressView()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Mac 正在处理应用").font(.headline)
                                        Text("\(job.items.filter { $0.state.isTerminal }.count) / \(job.items.count) 已处理 · 查看进度")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    appsSection
                }
            }
            .padding(22)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(StoreTheme.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await model.sync() }
        .sheet(item: $selectedApp) { app in
            AppDetailView(app: app, model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("AUTOSIGN STORE").font(.caption.weight(.bold)).tracking(2.5).foregroundStyle(StoreTheme.accent)
                Text("让好用的应用，\n一直都在。").font(.system(size: 32, weight: .bold, design: .rounded)).tracking(-0.8)
            }
            Spacer(minLength: 8)
            AppGlyph(size: 46).padding(.top, 4)
        }.padding(.top, 16).padding(.bottom, 6)
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            StoreCard {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "iphone.and.arrow.forward").font(.system(size: 42)).foregroundStyle(StoreTheme.accent)
                    Text("手机选应用，Mac 帮你安装。").font(.title2.bold())
                    Text("连接同一 Wi-Fi 中的 AutoSign，添加应用源、选择应用，让 Mac 自动下载、签名并安装。安装后的应用和 Store 自身也可以随时续签。")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { model.selectedTab = 2 } label: {
                        Label("连接我的 Mac", systemImage: "wifi").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    }.buttonStyle(.borderedProminent).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                step("1", "在 Mac 开启服务", "打开 AutoSign 的“手机安装与续签”局域网服务。")
                step("2", "配对当前设备", "输入 Mac 显示的密钥，并核对这台 iPhone 或 iPad。")
                step("3", "选择应用，自动安装", "在“应用源”选择应用，安装成功后可在这里续签。")
            }.padding(.horizontal, 4)
        }
    }

    private var connectionPill: some View {
        HStack(spacing: 8) {
            Circle().fill(model.isConnected ? StoreTheme.accent : .orange).frame(width: 7, height: 7)
            Text(model.isConnected ? "已连接 \(model.serverName)" : "Mac 暂时离线")
                .font(.caption.weight(.medium)).lineLimit(1)
            Spacer()
            Button { Task { await model.sync() } } label: {
                if model.isLoading { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise").font(.callout.weight(.semibold)) }
            }.disabled(model.isLoading).accessibilityLabel("同步 Mac 状态")
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .background(StoreTheme.accent.opacity(0.08), in: Capsule())
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("签名概览").font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(model.apps.count)").font(.system(size: 48, weight: .semibold, design: .rounded))
                        Text("个应用").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: "checkmark.shield").font(.system(size: 28, weight: .light))
                    Text(model.needsAttention == 0 ? "\(model.apps.isEmpty ? "等待添加应用" : "签名状态良好")" : "\(model.needsAttention) 个即将到期")
                        .font(.caption.weight(.medium))
                }.padding(.top, 4)
            }
            Button { Task { await model.refresh(model.refreshableApps) } } label: {
                HStack(spacing: 9) {
                    if model.isRefreshing { ProgressView().tint(StoreTheme.accent) }
                    else { Image(systemName: "arrow.triangle.2.circlepath") }
                    Text(model.isRefreshing ? "Mac 正在处理…" : "刷新全部应用").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .foregroundStyle(StoreTheme.accent)
                .background(.white.opacity(model.canRefresh && !model.refreshableApps.isEmpty ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain).disabled(!model.canRefresh || model.refreshableApps.isEmpty)
            Text(model.includeSelf ? "包含 Store 自身 · 自身最后刷新" : "本次批量刷新不包含 Store 自身")
                .font(.caption).foregroundStyle(.white.opacity(0.75)).frame(maxWidth: .infinity)
        }
        .padding(24).foregroundStyle(.white)
        .background(LinearGradient(colors: [StoreTheme.accent, Color(red: 0.06, green: 0.30, blue: 0.29)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Picker("本机设备", selection: $model.selectedDeviceID) {
                Text("请选择本机设备").tag("")
                ForEach(model.devices) { device in
                    Text("\(device.name)\(device.isReady ? "" : " · 未就绪")").tag(device.id)
                }
            }.pickerStyle(.menu).disabled(model.isRefreshing)
            Text("请核对设备名称。iOS 不允许应用自动读取本机 UDID。")
                .font(.caption2).foregroundStyle(.secondary)
            if let device = model.currentDevice, !device.isReady {
                Text("设备未就绪：解锁设备，确认首次 USB 配对、Wi-Fi 连接和开发者模式。")
                    .font(.caption).foregroundStyle(.orange)
            }
        }.padding(.horizontal, 3)
    }

    private var updatesSection: some View {
        StoreCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(model.updates.isEmpty ? "应用更新" : "\(model.updates.count) 个应用可更新", systemImage: "arrow.down.circle.fill")
                        .font(.headline).foregroundStyle(StoreTheme.accent)
                    Spacer()
                    Button { Task { await model.checkUpdates() } } label: {
                        if model.isCheckingUpdates { ProgressView().controlSize(.small) }
                        else { Text("检查更新").font(.caption.bold()) }
                    }.disabled(!model.canManageSources || model.isLoading)
                }
                if model.updates.isEmpty {
                    Text(model.selectedDeviceID.isEmpty ? "请选择本机设备查看更新。" : (model.snapshot?.sourceCheck?.checkedAt == nil ? "Mac 将自动检查已订阅的源，也可以立即检查。" : "暂无可用更新"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(model.updates) { update in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(update.name).font(.subheadline.bold())
                            Text("v\(update.installedVersion) → v\(update.displayVersion)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("更新") { Task { await model.updateApps([update]) } }
                            .buttonStyle(.bordered).disabled(!model.canUpdate)
                    }
                }
                if !model.updates.isEmpty {
                    Button {
                        Task { await model.updateApps(Array(model.updates.prefix(50))) }
                    } label: {
                        Label(model.updates.count > 50 ? "更新前 50 个应用" : "一键更新全部", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }.buttonStyle(.borderedProminent).disabled(!model.canUpdate)
                    Text("保留原应用标识和签名团队 · Store 自身最后更新")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let check = model.snapshot?.sourceCheck {
                    if let date = check.checkedAt {
                        Text("上次检查 \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !check.errors.isEmpty {
                        Text("\(check.errors.count) 个源检查失败，保留上次结果。请稍后重试。")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Text(check.automatic ? "Mac 运行时每 30 分钟检查；打开 Store 自动同步提示。" : "Mac 已关闭自动检查，可点击“检查更新”。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if !model.isConnected {
                    Text("Mac 离线，显示上次同步的更新；重新连接后可更新。")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("我的应用").font(.title3.bold())
                Spacer()
                Text("\(model.apps.count) 个").font(.caption).foregroundStyle(.secondary)
            }
            if model.apps.isEmpty {
                StoreCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "tray").font(.title).foregroundStyle(.secondary)
                        Text(model.selectedDeviceID.isEmpty ? "先选择这台设备" : "还没有受管理的应用").font(.headline)
                        Text("在“应用源”添加源并选择应用，让 Mac 自动下载、签名和安装。安装成功后会显示在这里，也可以在 Mac 安装本地 IPA。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(model.apps) { app in
                    Button { selectedApp = app } label: { appRow(app) }.buttonStyle(.plain)
                }
            }
            if model.apps.contains(where: \.isStore) {
                Toggle("批量刷新包含 Store 自身", isOn: $model.includeSelf)
                    .font(.subheadline).padding(.horizontal, 4).disabled(model.isRefreshing)
                Text("刷新自身时应用可能关闭。Mac 会继续安装，重新打开后可查看结果。")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            Text("到期时间来自 Mac 最近成功安装的描述文件；离线时显示上次同步记录。")
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
        }
    }

    private func appRow(_ app: StoreApp) -> some View {
        HStack(spacing: 14) {
            AppGlyph(isStore: app.isStore)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(app.name).font(.headline).lineLimit(1)
                    if app.isStore { Text("自身").font(.system(size: 9, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 3)
                        .background(StoreTheme.accent.opacity(0.1), in: Capsule()).foregroundStyle(StoreTheme.accent) }
                }
                Text("v\(app.version) · \(app.expiration.formatted(date: .abbreviated, time: .omitted)) 到期")
                    .font(.caption).foregroundStyle(.secondary)
                if let update = model.updates.first(where: { $0.id == app.id }) {
                    Text("新版本 v\(update.displayVersion)").font(.caption.bold()).foregroundStyle(StoreTheme.accent)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 3) {
                Text(app.expiration <= Date() ? "已到期" : "\(app.remainingDays()) 天").font(.subheadline.bold())
                Text("剩余").font(.caption2)
            }.foregroundStyle(app.remainingDays() <= 1 ? .orange : StoreTheme.accent)
        }
        .padding(16).background(StoreTheme.card, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.caption.bold()).foregroundStyle(StoreTheme.accent).frame(width: 26, height: 26)
                .background(StoreTheme.accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppDetailView: View {
    let app: StoreApp
    @ObservedObject var model: StoreModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        AppGlyph(isStore: app.isStore, size: 62)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(app.name).font(.title3.bold())
                            Text("版本 \(app.version)").foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                    LabeledContent("应用标识", value: app.bundleIdentifier).font(.caption).textSelection(.enabled)
                    LabeledContent("签名到期", value: app.expiration.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("最近安装", value: app.refreshedAt.formatted(date: .abbreviated, time: .shortened))
                }
                Section {
                    if let update = model.updates.first(where: { $0.id == app.id }) {
                        Button {
                            dismiss()
                            Task { await model.updateApps([update]) }
                        } label: { Label("更新至 v\(update.displayVersion)", systemImage: "arrow.down.circle") }
                            .disabled(!model.canUpdate)
                        if let notes = update.localizedDescription, !notes.isEmpty {
                            Text(notes).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        dismiss()
                        Task { await model.refresh([app]) }
                    } label: { Label(app.isStore ? "刷新 AutoSign Store 自身" : "刷新签名", systemImage: "arrow.clockwise") }
                    .disabled(!model.canRefresh)
                } footer: {
                    Text(app.isStore ? "Mac 会重新签名并覆盖安装 Store。应用可能关闭，重新打开后会恢复任务结果。" : "使用 Mac 保存的原始 IPA 覆盖安装，保持应用标识和签名团队一致。")
                }
            }
            .navigationTitle("应用详情").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
