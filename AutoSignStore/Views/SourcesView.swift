import SwiftUI

struct SourcesView: View {
    @ObservedObject var model: StoreModel
    @State private var showingAdd = false
    @State private var removing: SavedAppSource?

    var body: some View {
        List {
            Section {
                Label(model.isConnected ? "源与 \(model.serverName) 同步" : "Mac 离线 · 显示上次同步的源", systemImage: "desktopcomputer")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !model.hasCredentials {
                    Button("先连接 Mac") { model.selectedTab = 2 }
                } else if model.isConnected && !model.supportsSources {
                    Text("请更新 Mac AutoSign，以使用手机源管理和安装功能。")
                        .foregroundStyle(.orange)
                }
                if let error = model.sourceError {
                    Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                if model.isManagingSources { HStack { ProgressView(); Text("正在同步应用源…") } }
                if let message = model.otherDeviceTaskMessage {
                    Label(message, systemImage: "desktopcomputer")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(model.sources) { source in
                    NavigationLink {
                        SourceAppsView(model: model, sourceID: source.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(source.catalog.name).font(.headline)
                            Text("\(source.catalog.apps.count) 个应用 · \(source.url.host ?? source.id)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("更新于 \(source.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                    .swipeActions {
                        Button("移除", role: .destructive) { removing = source }.disabled(!model.canManageSources)
                    }
                    .contextMenu {
                        Button("刷新源", systemImage: "arrow.clockwise") {
                            Task { await model.saveSource(source.id, refresh: true) }
                        }.disabled(!model.canManageSources)
                        Button("移除源", systemImage: "trash", role: .destructive) { removing = source }
                            .disabled(!model.canManageSources)
                    }
                }
                if model.sources.isEmpty {
                    ContentUnavailableView("还没有应用源", systemImage: "shippingbox",
                        description: Text("添加 AltStore / SideStore 源，浏览应用并交给 Mac 安装。"))
                }
                Button { showingAdd = true } label: { Label("添加源", systemImage: "plus.circle.fill") }
                    .disabled(!model.canManageSources)
            } header: { Text("已订阅的源") }
              footer: { Text("源保存在已连接的 Mac，并与 Mac 的“从源获取”共用。移除源不会卸载已安装应用。") }
        }
        .navigationTitle("应用源")
        .toolbar {
            Button { Task { await model.sync() } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(model.isLoading || model.isManagingSources).accessibilityLabel("同步源列表")
            Button { showingAdd = true } label: { Image(systemName: "plus") }
                .disabled(!model.canManageSources).accessibilityLabel("添加源")
        }
        .refreshable { await model.sync() }
        .sheet(isPresented: $showingAdd) { AddSourceView(model: model) }
        .confirmationDialog("移除“\(removing?.catalog.name ?? "")”？", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), titleVisibility: .visible) {
            if let source = removing {
                Button("移除源", role: .destructive) { Task { await model.removeSource(source) }; removing = nil }
            }
        } message: { Text("已安装的应用和 Mac 保存的安装包会保留。") }
    }
}

private struct AddSourceView: View {
    @ObservedObject var model: StoreModel
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    private let suggested = [
        ("AutoSign Store", "https://raw.githubusercontent.com/tignioj/auto-sign-store/source/apps.json"),
        ("Kazumi", "https://raw.githubusercontent.com/ChouChiu/Kazumi-AltStore-Source/kazumi/generated/apps.json")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/apps.json", text: $url, axis: .vertical)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel("应用源 JSON 地址")
                    Button {
                        Task { if await model.saveSource(url) { dismiss() } }
                    } label: {
                        HStack {
                            Text(model.isManagingSources ? "正在添加…" : "添加源")
                            Spacer()
                            if model.isManagingSources { ProgressView() }
                        }
                    }.disabled(!model.canManageSources || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: { Text("源地址") }
                  footer: { Text("Mac 会读取并验证 AltStore / SideStore 格式的 JSON。") }
                if let error = model.sourceError {
                    Section { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
                }
                Section("快捷填写") {
                    ForEach(suggested, id: \.0) { name, address in
                        Button(name) { url = address }.disabled(model.isManagingSources)
                    }
                }
            }
            .navigationTitle("添加应用源").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(model.isManagingSources) } }
            .interactiveDismissDisabled(model.isManagingSources)
        }
    }
}

private struct SourceAppsView: View {
    @ObservedObject var model: StoreModel
    let sourceID: String
    @State private var search = ""
    private var source: SavedAppSource? { model.sources.first { $0.id == sourceID } }
    private var apps: [SourceApp] {
        (source?.catalog.apps ?? []).filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(search)
                || ($0.developerName?.localizedCaseInsensitiveContains(search) == true)
        }
    }

    var body: some View {
        List {
            if let source {
                Section {
                    Text(source.id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Text("源更新于 \(source.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = model.sourceError { Text(error).font(.caption).foregroundStyle(.orange) }
                    if !model.isConnected { Text("Mac 离线，连接后可刷新和安装。 ").font(.caption).foregroundStyle(.orange) }
                }
                Section {
                    ForEach(apps) { app in
                        NavigationLink {
                            SourceAppDetailView(model: model, sourceID: source.id, appID: app.id)
                        } label: {
                            HStack(spacing: 12) {
                                SourceIcon(url: app.iconURL, size: 48)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(app.name).font(.headline)
                                    Text(app.latestVersion.map { "v\($0.displayVersion)" } ?? "暂无可下载版本")
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let developer = app.developerName { Text(developer).font(.caption2).foregroundStyle(.secondary) }
                                }
                            }.padding(.vertical, 3)
                        }
                    }
                    if apps.isEmpty { ContentUnavailableView("没有找到应用", systemImage: "magnifyingglass") }
                }
            } else { ContentUnavailableView("源已移除", systemImage: "shippingbox") }
        }
        .navigationTitle(source?.catalog.name ?? "应用源").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "搜索名称、开发者或应用标识")
        .toolbar {
            Button {
                Task { await model.saveSource(sourceID, refresh: true) }
            } label: {
                if model.isManagingSources { ProgressView() } else { Image(systemName: "arrow.clockwise") }
            }.disabled(!model.canManageSources).accessibilityLabel("刷新此源")
        }
        .refreshable { await model.saveSource(sourceID, refresh: true) }
    }
}

private struct SourceAppDetailView: View {
    @ObservedObject var model: StoreModel
    let sourceID: String
    let appID: String
    private var source: SavedAppSource? { model.sources.first { $0.id == sourceID } }
    private var app: SourceApp? { source?.catalog.apps.first { $0.id == appID } }

    var body: some View {
        List {
            if let source, let app {
                Section {
                    HStack(spacing: 16) {
                        SourceIcon(url: app.iconURL, size: 64)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(app.name).font(.title3.bold())
                            if let developer = app.developerName { Text(developer).font(.subheadline).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical, 8)
                    LabeledContent("应用标识", value: app.bundleIdentifier).font(.caption).textSelection(.enabled)
                    if let version = app.latestVersion {
                        LabeledContent("最新版本", value: version.displayVersion)
                        if let size = version.size, size > 0 { LabeledContent("安装包大小", value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
                        if let minimum = version.minOSVersion { LabeledContent("最低系统", value: "iOS \(minimum)") }
                        if let maximum = version.maxOSVersion { LabeledContent("最高系统", value: "iOS \(maximum)") }
                    }
                }
                Section {
                    Picker("安装设备", selection: $model.selectedDeviceID) {
                        Text("请选择本机设备").tag("")
                        ForEach(model.devices) { device in Text("\(device.name)\(device.isReady ? "" : " · 未就绪")").tag(device.id) }
                    }.disabled(model.isSubmitting)
                    Button {
                        Task { await model.install(app, from: source) }
                    } label: {
                        Label(model.currentDevice.map { "安装到 \($0.name)" } ?? "安装最新版本", systemImage: "arrow.down.app.fill")
                    }.disabled(!model.canInstall || app.latestVersion == nil)
                    if !model.isConnected { Text("连接 Mac 后可安装。").foregroundStyle(.orange) }
                    else if model.currentDevice?.isReady != true { Text("请核对并选择已配对、已解锁且开启开发者模式的设备。").font(.caption).foregroundStyle(.orange) }
                    else if let message = model.serverTaskMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                } footer: {
                    Text("Mac 会重新检查最新版本，自动下载、签名并安装。新应用使用 Mac 配置的签名团队；升级保留原应用标识及团队。安装 Store 自身时可能退出，重新打开可查看结果。")
                }
                if let notes = app.latestVersion?.localizedDescription, !notes.isEmpty {
                    Section("更新说明") { Text(notes).font(.subheadline).textSelection(.enabled) }
                }
                if let description = app.localizedDescription, !description.isEmpty {
                    Section("应用介绍") { Text(description).font(.subheadline).textSelection(.enabled) }
                }
            } else { ContentUnavailableView("应用已不在源中", systemImage: "app.dashed") }
        }
        .navigationTitle("应用详情").navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourceIcon: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        AsyncImage(url: url.flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }) { image in
            image.resizable().scaledToFit()
        } placeholder: { AppGlyph(isStore: false, size: size) }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.23))
        .accessibilityHidden(true)
    }
}
