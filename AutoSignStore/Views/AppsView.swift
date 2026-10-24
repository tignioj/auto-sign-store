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
                    devicePicker
                    if let message = model.otherDeviceTaskMessage {
                        StoreCard {
                            Label(message, systemImage: "desktopcomputer")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if model.supportsUpdates { updatesSection }
                    if let job = model.activeJob, !job.state.isTerminal {
                        Button { model.selectedTab = 1 } label: {
                            StoreCard {
                                HStack(spacing: 14) {
                                    ProgressView()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(job.statusTitle) · \(model.currentDevice?.name ?? L10n.tr("device.current"))").font(.headline)
                                        Text(L10n.tr("apps.progress", job.items.filter { $0.state.isTerminal }.count, job.items.count))
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
                Text(L10n.tr("apps.tagline")).font(.system(size: 32, weight: .bold, design: .rounded)).tracking(-0.8)
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
                    Text(L10n.tr("apps.welcome.title")).font(.title2.bold())
                    Text(L10n.tr("apps.welcome.detail"))
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { model.selectedTab = 2 } label: {
                        Label(L10n.tr("apps.connect"), systemImage: "wifi").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    }.buttonStyle(.borderedProminent).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                step("1", L10n.tr("apps.step.service.title"), L10n.tr("apps.step.service.detail"))
                step("2", L10n.tr("apps.step.pair.title"), L10n.tr("apps.step.pair.detail"))
                step("3", L10n.tr("apps.step.install.title"), L10n.tr("apps.step.install.detail"))
            }.padding(.horizontal, 4)
        }
    }

    private var connectionPill: some View {
        HStack(spacing: 8) {
            Circle().fill(model.isConnected ? StoreTheme.accent : .orange).frame(width: 7, height: 7)
            Text(model.isConnected ? L10n.tr("connection.named", model.serverName) : L10n.tr("connection.offline"))
                .font(.caption.weight(.medium)).lineLimit(1)
            Spacer()
            Button { Task { await model.sync() } } label: {
                if model.isLoading { ProgressView().controlSize(.small) }
                else { Image(systemName: "arrow.clockwise").font(.callout.weight(.semibold)) }
            }.disabled(model.isLoading).accessibilityLabel(L10n.tr("connection.sync"))
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .background(StoreTheme.accent.opacity(0.08), in: Capsule())
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("apps.summary")).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(model.apps.count)").font(.system(size: 48, weight: .semibold, design: .rounded))
                        Text(L10n.tr(model.apps.count == 1 ? "apps.noun.one" : "apps.noun.other")).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: "checkmark.shield").font(.system(size: 28, weight: .light))
                    Text(model.needsAttention == 0 ? model.apps.isEmpty ? L10n.tr("apps.waiting") : L10n.tr("apps.healthy") : L10n.tr("count.expiring", model.needsAttention))
                        .font(.caption.weight(.medium))
                }.padding(.top, 4)
            }
            Button { Task { await model.refresh(model.refreshableApps) } } label: {
                HStack(spacing: 9) {
                    if model.isRefreshing { ProgressView().tint(StoreTheme.accent) }
                    else { Image(systemName: "arrow.triangle.2.circlepath") }
                    Text(model.isRefreshing ? model.currentTaskTitle : L10n.tr("apps.refreshAll")).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .foregroundStyle(StoreTheme.accent)
                .background(.white.opacity(model.canRefresh && !model.refreshableApps.isEmpty ? 1 : 0.65), in: RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain).disabled(!model.canRefresh || model.refreshableApps.isEmpty)
            Text(model.includeSelf ? L10n.tr("apps.includeSelf.detail") : L10n.tr("apps.excludeSelf.detail"))
                .font(.caption).foregroundStyle(.white.opacity(0.75)).frame(maxWidth: .infinity)
        }
        .padding(24).foregroundStyle(.white)
        .background(LinearGradient(colors: [StoreTheme.accent, Color(red: 0.06, green: 0.30, blue: 0.29)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }

    private var devicePicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Picker(L10n.tr("apps.device"), selection: Binding(get: { model.selectedDeviceID }, set: model.selectDevice)) {
                Text(L10n.tr("apps.selectDevice")).tag("")
                ForEach(model.devices) { device in
                    Text(device.isReady ? device.name : L10n.tr("device.notReady", device.name)).tag(device.id)
                }
            }.pickerStyle(.menu).disabled(model.isSubmitting || model.devices.isEmpty)
            Text(model.deviceSelectionHint)
                .font(.caption2).foregroundStyle(.secondary)
            if let device = model.currentDevice, !device.isReady {
                Text(L10n.tr("apps.deviceNotReady"))
                    .font(.caption).foregroundStyle(.orange)
            }
        }.padding(.horizontal, 3)
    }

    private var updatesSection: some View {
        StoreCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(model.updates.isEmpty ? L10n.tr("updates.title") : L10n.tr("count.updates", model.updates.count), systemImage: "arrow.down.circle.fill")
                        .font(.headline).foregroundStyle(StoreTheme.accent)
                    Spacer()
                    Button { Task { await model.checkUpdates() } } label: {
                        if model.isCheckingUpdates { ProgressView().controlSize(.small) }
                        else { Text(L10n.tr("updates.check")).font(.caption.bold()) }
                    }.disabled(!model.canManageSources || model.isLoading)
                }
                if model.updates.isEmpty {
                    Text(model.selectedDeviceID.isEmpty ? L10n.tr("updates.selectDevice") : (model.snapshot?.sourceCheck?.checkedAt == nil ? L10n.tr("updates.automaticHint") : L10n.tr("updates.none")))
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
                        Button(L10n.tr("updates.update")) { Task { await model.updateApps([update]) } }
                            .buttonStyle(.bordered).disabled(!model.canUpdate)
                    }
                }
                if !model.updates.isEmpty {
                    Button {
                        Task { await model.updateApps(Array(model.updates.prefix(50))) }
                    } label: {
                        Label(model.updates.count > 50 ? L10n.tr("updates.first50") : L10n.tr("updates.all"), systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }.buttonStyle(.borderedProminent).disabled(!model.canUpdate)
                    Text(L10n.tr("updates.identityHint"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let check = model.snapshot?.sourceCheck {
                    if let date = check.checkedAt {
                        Text(L10n.tr("updates.lastCheck", L10n.date(date)))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !check.errors.isEmpty {
                        Text(L10n.tr("count.failedSources", check.errors.count))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Text(check.automatic ? L10n.tr("updates.schedule") : L10n.tr("updates.disabled"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if !model.isConnected {
                    Text(L10n.tr("updates.offline"))
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.tr("tab.apps")).font(.title3.bold())
                Spacer()
                Text(L10n.tr("count.apps", model.apps.count)).font(.caption).foregroundStyle(.secondary)
            }
            if model.apps.isEmpty {
                StoreCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "tray").font(.title).foregroundStyle(.secondary)
                        Text(model.selectedDeviceID.isEmpty ? L10n.tr("apps.empty.selectDevice") : L10n.tr("apps.empty.title")).font(.headline)
                        Text(L10n.tr("apps.empty.detail"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(model.apps) { app in
                    Button { selectedApp = app } label: { appRow(app) }.buttonStyle(.plain)
                }
            }
            if model.apps.contains(where: \.isStore) {
                Toggle(L10n.tr("apps.includeSelf"), isOn: $model.includeSelf)
                    .font(.subheadline).padding(.horizontal, 4).disabled(model.isRefreshing)
                Text(model.supportsProfileRefresh ? L10n.tr("apps.profileRefreshHint") : L10n.tr("apps.selfRefreshHint"))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            Text(L10n.tr("apps.expiryHint"))
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
        }
    }

    private func appRow(_ app: StoreApp) -> some View {
        HStack(spacing: 14) {
            AppGlyph(isStore: app.isStore)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(app.name).font(.headline).lineLimit(1)
                    if app.isStore { Text(L10n.tr("apps.self")).font(.system(size: 9, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 3)
                        .background(StoreTheme.accent.opacity(0.1), in: Capsule()).foregroundStyle(StoreTheme.accent) }
                }
                Text(L10n.tr("apps.versionExpiry", app.version, L10n.date(app.expiration, includeTime: false)))
                    .font(.caption).foregroundStyle(.secondary)
                if let update = model.updates.first(where: { $0.id == app.id }) {
                    Text(L10n.tr("apps.newVersion", update.displayVersion)).font(.caption.bold()).foregroundStyle(StoreTheme.accent)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 3) {
                Text(app.expiration <= Date() ? L10n.tr("apps.expired") : L10n.tr("count.days", app.remainingDays())).font(.subheadline.bold())
                Text(L10n.tr("apps.remaining")).font(.caption2)
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
                            Text(L10n.tr("apps.version", app.version)).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                    LabeledContent(L10n.tr("apps.bundleID"), value: app.bundleIdentifier).font(.caption).textSelection(.enabled)
                    LabeledContent(L10n.tr("apps.expiration"), value: L10n.date(app.expiration))
                    LabeledContent(L10n.tr("apps.lastRefresh"), value: L10n.date(app.refreshedAt))
                }
                Section {
                    if let update = model.updates.first(where: { $0.id == app.id }) {
                        Button {
                            dismiss()
                            Task { await model.updateApps([update]) }
                        } label: { Label(L10n.tr("updates.toVersion", update.displayVersion), systemImage: "arrow.down.circle") }
                            .disabled(!model.canUpdate)
                        if let notes = update.localizedDescription, !notes.isEmpty {
                            Text(notes).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        dismiss()
                        Task { await model.refresh([app]) }
                    } label: { Label(app.isStore ? L10n.tr("apps.refreshSelf") : L10n.tr("apps.refreshSignature"), systemImage: "arrow.clockwise") }
                    .disabled(!model.canRefresh)
                } footer: {
                    Text(model.supportsProfileRefresh ? L10n.tr("apps.detail.profileHint") : (app.isStore ? L10n.tr("apps.detail.selfHint") : L10n.tr("apps.detail.refreshHint")))
                }
            }
            .navigationTitle(L10n.tr("common.appDetails")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.tr("common.done")) { dismiss() } } }
        }
    }
}
