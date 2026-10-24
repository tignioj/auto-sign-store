import SwiftUI

struct SourcesView: View {
    @ObservedObject var model: StoreModel
    @State private var showingAdd = false
    @State private var removing: SavedAppSource?

    var body: some View {
        List {
            Section {
                Label(model.isConnected ? L10n.tr("sources.syncedWith", model.serverName) : L10n.tr("sources.offline"), systemImage: "desktopcomputer")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !model.hasCredentials {
                    Button(L10n.tr("sources.connect")) { model.selectedTab = 2 }
                } else if model.isConnected && !model.supportsSources {
                    Text(L10n.tr("sources.upgradeMac"))
                        .foregroundStyle(.orange)
                }
                if let error = model.sourceError {
                    Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                if model.isManagingSources { HStack { ProgressView(); Text(L10n.tr("sources.syncing")) } }
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
                            Text("\(L10n.tr("count.apps", source.catalog.apps.count)) · \(source.url.host ?? source.id)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(L10n.tr("sources.updatedAt", L10n.date(source.updatedAt)))
                                .font(.caption2).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                    .swipeActions {
                        Button(L10n.tr("common.remove"), role: .destructive) { removing = source }.disabled(!model.canManageSources)
                    }
                    .contextMenu {
                        Button(L10n.tr("sources.refresh"), systemImage: "arrow.clockwise") {
                            Task { await model.saveSource(source.id, refresh: true) }
                        }.disabled(!model.canManageSources)
                        Button(L10n.tr("sources.remove"), systemImage: "trash", role: .destructive) { removing = source }
                            .disabled(!model.canManageSources)
                    }
                }
                if model.sources.isEmpty {
                    ContentUnavailableView(L10n.tr("sources.empty.title"), systemImage: "shippingbox",
                        description: Text(L10n.tr("sources.empty.detail")))
                }
                Button { showingAdd = true } label: { Label(L10n.tr("sources.add"), systemImage: "plus.circle.fill") }
                    .disabled(!model.canManageSources)
            } header: { Text(L10n.tr("sources.subscribed")) }
              footer: { Text(L10n.tr("sources.storageHint")) }
        }
        .navigationTitle(L10n.tr("tab.sources"))
        .toolbar {
            Button { Task { await model.sync() } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(model.isLoading || model.isManagingSources).accessibilityLabel(L10n.tr("sources.sync"))
            Button { showingAdd = true } label: { Image(systemName: "plus") }
                .disabled(!model.canManageSources).accessibilityLabel(L10n.tr("sources.add"))
        }
        .refreshable { await model.sync() }
        .sheet(isPresented: $showingAdd) { AddSourceView(model: model) }
        .confirmationDialog(L10n.tr("sources.confirmRemove", removing?.catalog.name ?? ""), isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), titleVisibility: .visible) {
            if let source = removing {
                Button(L10n.tr("sources.remove"), role: .destructive) { Task { await model.removeSource(source) }; removing = nil }
            }
        } message: { Text(L10n.tr("sources.removeHint")) }
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
                        .accessibilityLabel(L10n.tr("sources.urlAccessibility"))
                    Button {
                        Task { if await model.saveSource(url) { dismiss() } }
                    } label: {
                        HStack {
                            Text(model.isManagingSources ? L10n.tr("sources.adding") : L10n.tr("sources.add"))
                            Spacer()
                            if model.isManagingSources { ProgressView() }
                        }
                    }.disabled(!model.canManageSources || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: { Text(L10n.tr("sources.url")) }
                  footer: { Text(L10n.tr("sources.validationHint")) }
                if let error = model.sourceError {
                    Section { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
                }
                Section(L10n.tr("sources.suggestions")) {
                    ForEach(suggested, id: \.0) { name, address in
                        Button(name) { url = address }.disabled(model.isManagingSources)
                    }
                }
            }
            .navigationTitle(L10n.tr("sources.addTitle")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("common.close")) { dismiss() }.disabled(model.isManagingSources) } }
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
                    Text(L10n.tr("sources.sourceUpdatedAt", L10n.date(source.updatedAt)))
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = model.sourceError { Text(error).font(.caption).foregroundStyle(.orange) }
                    if !model.isConnected { Text(L10n.tr("sources.offlineInstall")).font(.caption).foregroundStyle(.orange) }
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
                                    Text(app.latestVersion.map { "v\($0.displayVersion)" } ?? L10n.tr("sources.noVersion"))
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let developer = app.developerName { Text(developer).font(.caption2).foregroundStyle(.secondary) }
                                }
                            }.padding(.vertical, 3)
                        }
                    }
                    if apps.isEmpty { ContentUnavailableView(L10n.tr("sources.noResults"), systemImage: "magnifyingglass") }
                }
            } else { ContentUnavailableView(L10n.tr("sources.removed"), systemImage: "shippingbox") }
        }
        .navigationTitle(source?.catalog.name ?? L10n.tr("tab.sources")).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: L10n.tr("sources.search"))
        .toolbar {
            Button {
                Task { await model.saveSource(sourceID, refresh: true) }
            } label: {
                if model.isManagingSources { ProgressView() } else { Image(systemName: "arrow.clockwise") }
            }.disabled(!model.canManageSources).accessibilityLabel(L10n.tr("sources.refreshThis"))
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
                    LabeledContent(L10n.tr("apps.bundleID"), value: app.bundleIdentifier).font(.caption).textSelection(.enabled)
                    if let version = app.latestVersion {
                        LabeledContent(L10n.tr("sources.latestVersion"), value: version.displayVersion)
                        if let size = version.size, size > 0 { LabeledContent(L10n.tr("sources.fileSize"), value: L10n.fileSize(size)) }
                        if let minimum = version.minOSVersion { LabeledContent(L10n.tr("sources.minOS"), value: "iOS \(minimum)") }
                        if let maximum = version.maxOSVersion { LabeledContent(L10n.tr("sources.maxOS"), value: "iOS \(maximum)") }
                    }
                }
                Section {
                    Picker(L10n.tr("sources.installDevice"), selection: Binding(get: { model.selectedDeviceID }, set: model.selectDevice)) {
                        Text(L10n.tr("apps.selectDevice")).tag("")
                        ForEach(model.devices) { device in Text(device.isReady ? device.name : L10n.tr("device.notReady", device.name)).tag(device.id) }
                    }.disabled(model.isSubmitting)
                    Button {
                        Task { await model.install(app, from: source) }
                    } label: {
                        Label(model.currentDevice.map { L10n.tr("sources.installOn", $0.name) } ?? L10n.tr("sources.installLatest"), systemImage: "arrow.down.app.fill")
                    }.disabled(!model.canInstall || app.latestVersion == nil)
                    if !model.isConnected { Text(L10n.tr("sources.connectToInstall")).foregroundStyle(.orange) }
                    else if model.currentDevice?.isReady != true { Text(L10n.tr("sources.deviceHint")).font(.caption).foregroundStyle(.orange) }
                    else if let message = model.serverTaskMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                } footer: {
                    Text(L10n.tr("sources.installHint"))
                }
                if let notes = app.latestVersion?.localizedDescription, !notes.isEmpty {
                    Section(L10n.tr("sources.releaseNotes")) { Text(notes).font(.subheadline).textSelection(.enabled) }
                }
                if let description = app.localizedDescription, !description.isEmpty {
                    Section(L10n.tr("sources.description")) { Text(description).font(.subheadline).textSelection(.enabled) }
                }
            } else { ContentUnavailableView(L10n.tr("sources.appRemoved"), systemImage: "app.dashed") }
        }
        .navigationTitle(L10n.tr("common.appDetails")).navigationBarTitleDisplayMode(.inline)
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
