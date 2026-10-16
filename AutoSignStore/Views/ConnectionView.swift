import SwiftUI

struct ConnectionView: View {
    @ObservedObject var model: StoreModel
    @StateObject private var discovery = ServerDiscovery()
    @State private var showToken = false
    @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker(L10n.tr("language.title"), selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .accessibilityIdentifier("languagePicker")
            } footer: { Text(L10n.tr("language.hint")) }
            Section {
                HStack(spacing: 14) {
                    Image(systemName: model.isConnected ? "wifi.circle.fill" : "wifi.slash")
                        .font(.system(size: 38)).foregroundStyle(StoreTheme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.isConnected ? model.serverName : L10n.tr("connection.title")).font(.headline)
                        Text(model.isConnected ? L10n.tr("connection.connected") : L10n.tr("connection.subtitle"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 10)
            }
            Section {
                if discovery.servers.isEmpty {
                    HStack { ProgressView().padding(.trailing, 6); Text(discovery.message).font(.subheadline) }
                }
                ForEach(discovery.servers) { server in
                    Button {
                        model.address = server.address
                    } label: {
                        HStack {
                            Image(systemName: "desktopcomputer")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(server.name).foregroundStyle(.primary)
                                Text(server.address).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.address == server.address { Image(systemName: "checkmark.circle.fill") }
                        }
                    }.disabled(!model.canChangeConnection)
                }
                Button(L10n.tr("connection.searchAgain")) { discovery.stop(); discovery.start() }
            } header: { Text(L10n.tr("connection.nearby")) }
              footer: { Text(L10n.tr("connection.discoveryHint")) }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("connection.address")).font(.caption).foregroundStyle(.secondary)
                    TextField("http://192.168.1.10:8091", text: $model.address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel(L10n.tr("connection.addressAccessibility"))
                }.padding(.vertical, 4)
                HStack {
                    Group {
                        if showToken { TextField(L10n.tr("connection.tokenPlaceholder"), text: $model.pairingToken) }
                        else { SecureField(L10n.tr("connection.tokenPlaceholder"), text: $model.pairingToken) }
                    }
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel(L10n.tr("connection.token"))
                    Button { showToken.toggle() } label: { Image(systemName: showToken ? "eye.slash" : "eye") }
                        .accessibilityLabel(showToken ? L10n.tr("connection.hideToken") : L10n.tr("connection.showToken"))
                }
                Button { Task { await model.pair() } } label: {
                    HStack {
                        Text(model.isLoading ? L10n.tr("connection.connecting") : L10n.tr("connection.pair"))
                        Spacer()
                        if model.isLoading { ProgressView() } else { Image(systemName: "arrow.right") }
                    }
                }.disabled(!model.canChangeConnection || model.address.isEmpty || model.pairingToken.isEmpty)
            } header: { Text(L10n.tr("connection.pairSection")) }
              footer: { Text(L10n.tr("connection.securityHint")) }
            if model.hasCredentials {
                Section {
                    Button(L10n.tr("connection.syncStatus")) { Task { await model.sync() } }.disabled(model.isLoading)
                    Button(L10n.tr("connection.unpair"), role: .destructive) { model.disconnect() }.disabled(!model.canChangeConnection)
                }
            }
            Section(L10n.tr("connection.firstUse")) {
                guide("cable.connector", L10n.tr("connection.usb.title"), L10n.tr("connection.usb.detail"))
                guide("hammer", L10n.tr("connection.developer.title"), L10n.tr("connection.developer.detail"))
                guide("checkmark.shield", L10n.tr("connection.trust.title"), L10n.tr("connection.trust.detail"))
                guide("arrow.clockwise", L10n.tr("connection.self.title"), L10n.tr("connection.self.detail"))
            }
            Section {
                Text("AutoSign Store 1.2 · iOS 17+").font(.caption).foregroundStyle(.secondary)
                Text(L10n.tr("connection.appleHint"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.tr("tab.connection"))
        .task { discovery.start() }
        .onDisappear { discovery.stop() }
    }

    private func guide(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(StoreTheme.accent).frame(width: 23).padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 5)
    }
}
