import Foundation

struct DiscoveredServer: Identifiable {
    let id: String
    let name: String
    let address: String
}

@MainActor
final class ServerDiscovery: NSObject, ObservableObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    @Published private(set) var servers: [DiscoveredServer] = []
    @Published private var messageKey = "discovery.searching"
    var message: String { servers.isEmpty ? L10n.tr(messageKey) : L10n.tr("count.macs", servers.count) }
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        messageKey = "discovery.searching"
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
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        messageKey = "discovery.failed"
        started = false
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        messageKey = "discovery.resolveFailed"
    }
}
