import Foundation

struct DiscoveredServer: Identifiable {
    let id: String
    let name: String
    let address: String
}

@MainActor
final class ServerDiscovery: NSObject, ObservableObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    @Published private(set) var servers: [DiscoveredServer] = []
    @Published private(set) var message = "搜索同一 Wi-Fi 中的 Mac"
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        browser.delegate = self
        browser.searchForServices(ofType: "_autosign._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        services.forEach { $0.stop() }
        services.removeAll()
        servers.removeAll()
        started = false
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 8)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        servers.removeAll { $0.id == service.name }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = sender.hostName, sender.port > 0 else { return }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host.hasSuffix(".") ? String(host.dropLast()) : host
        components.port = sender.port
        guard let address = components.url?.absoluteString else { return }
        servers.removeAll { $0.id == sender.name }
        servers.append(DiscoveredServer(id: sender.name, name: sender.name, address: address))
        servers.sort { $0.name < $1.name }
        message = "发现 \(servers.count) 台 Mac"
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        message = "无法发现 Mac。请在系统设置中允许本地网络访问，或手动输入地址。"
        started = false
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        message = "发现了服务，但解析地址失败；可以手动输入 Mac 的 IP 地址。"
    }
}
