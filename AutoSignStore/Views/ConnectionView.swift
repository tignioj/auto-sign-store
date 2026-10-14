import SwiftUI

struct ConnectionView: View {
    @ObservedObject var model: StoreModel
    @StateObject private var discovery = ServerDiscovery()
    @State private var showToken = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: model.isConnected ? "wifi.circle.fill" : "wifi.slash")
                        .font(.system(size: 38)).foregroundStyle(StoreTheme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.isConnected ? model.serverName : "连接你的 Mac").font(.headline)
                        Text(model.isConnected ? "局域网服务已连接" : "同一 Wi-Fi，安装与续签")
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
                Button("重新搜索") { discovery.stop(); discovery.start() }
            } header: { Text("附近的 AutoSign") }
              footer: { Text("在 Mac 的 AutoSign 中开启“手机安装与续签”服务。首次使用时请允许本地网络访问。") }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mac 地址").font(.caption).foregroundStyle(.secondary)
                    TextField("http://192.168.1.10:8091", text: $model.address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel("Mac 局域网地址")
                }.padding(.vertical, 4)
                HStack {
                    Group {
                        if showToken { TextField("粘贴 Mac 上的配对密钥", text: $model.pairingToken) }
                        else { SecureField("粘贴 Mac 上的配对密钥", text: $model.pairingToken) }
                    }
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel("配对密钥")
                    Button { showToken.toggle() } label: { Image(systemName: showToken ? "eye.slash" : "eye") }
                        .accessibilityLabel(showToken ? "隐藏密钥" : "显示密钥")
                }
                Button { Task { await model.pair() } } label: {
                    HStack {
                        Text(model.isLoading ? "正在连接…" : "配对并连接")
                        Spacer()
                        if model.isLoading { ProgressView() } else { Image(systemName: "arrow.right") }
                    }
                }.disabled(!model.canChangeConnection || model.address.isEmpty || model.pairingToken.isEmpty)
            } header: { Text("配对 Mac") }
              footer: { Text("配对密钥保存在本机钥匙串。此服务使用局域网 HTTP，请仅连接你信任的网络。") }
            if model.hasCredentials {
                Section {
                    Button("同步连接状态") { Task { await model.sync() } }.disabled(model.isLoading)
                    Button("解除此 Mac 的配对", role: .destructive) { model.disconnect() }.disabled(!model.canChangeConnection)
                }
            }
            Section("首次使用") {
                guide("cable.connector", "先通过 USB 配对", "解锁设备，信任 Mac，并在 Finder 启用“连接到 Wi-Fi 时显示此设备”。")
                guide("hammer", "开启开发者模式", "前往设置 → 隐私与安全性 → 开发者模式，按系统提示重启。")
                guide("checkmark.shield", "首次安装信任证书", "必要时在设置 → 通用 → VPN 与设备管理中信任开发者。")
                guide("arrow.clockwise", "Store 自身也能刷新", "先用新版 AutoSign 安装 Store IPA。刷新自身时应用可能退出，Mac 会继续完成安装。")
            }
            Section {
                Text("AutoSign Store 1.1 · iOS 17+").font(.caption).foregroundStyle(.secondary)
                Text("续签会向 Apple 请求新描述文件。免费账号刷新成功后获得新 7 天签名；未签发新文件时会显示失败。Mac 上的 Xcode 账号需要保持有效。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("连接")
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
