import Foundation

public enum StoreClientError: LocalizedError {
    case invalidAddress, unauthorized, incompatibleServer, response(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress: "请输入局域网地址，例如 http://192.168.1.10:8091。"
        case .unauthorized: "配对密钥无效。请从 Mac 的 AutoSign 重新复制。"
        case .incompatibleServer: "Mac 服务版本不兼容，请更新 AutoSign。"
        case .response(let message): message
        }
    }
}

public enum ServerAddress {
    public static func parse(_ input: String) throws -> URL {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host?.lowercased(), isLocal(host),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              url.port.map({ (1...65535).contains($0) }) ?? true else {
            throw StoreClientError.invalidAddress
        }
        return url
    }

    private static func isLocal(_ host: String) -> Bool {
        let host = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host == "::1" || host.hasSuffix(".local") || host.hasSuffix(".local.") { return true }
        if host.contains(":"), host.hasPrefix("fd") || host.hasPrefix("fc") || host.hasPrefix("fe80:") { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) else { return false }
        let octets = parts.compactMap { UInt8($0) }
        return octets[0] == 10 || octets[0] == 127
            || (octets[0] == 192 && octets[1] == 168)
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 169 && octets[1] == 254)
    }
}

/// Reject redirects so a LAN server cannot forward the pairing credential to another host.
private final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct StoreClient: Sendable {
    private let baseURL: URL
    private let token: String
    private let session: URLSession

    public init(address: String, token: String, session: URLSession? = nil) throws {
        self.baseURL = try ServerAddress.parse(address)
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 90
        configuration.waitsForConnectivity = false
        self.session = session ?? URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }

    public func snapshot() async throws -> StoreSnapshot {
        let value: StoreSnapshot = try await send(path: "v1/status")
        guard value.protocolVersion == 1 else { throw StoreClientError.incompatibleServer }
        return value
    }

    public func refresh(_ request: RefreshRequest) async throws -> RefreshJob {
        try await send(path: "v1/refresh", body: StoreJSON.encoder().encode(request))
    }

    public func checkUpdates() async throws -> StoreSnapshot {
        try await send(path: "v1/updates/check", body: Data("{}".utf8))
    }

    public func updateApps(_ request: RefreshRequest) async throws -> RefreshJob {
        try await send(path: "v1/updates", body: StoreJSON.encoder().encode(request))
    }

    func sources() async throws -> [SavedAppSource] {
        try await send(path: "v1/sources")
    }

    func saveSource(_ url: String, refresh: Bool = false) async throws -> [SavedAppSource] {
        try await send(path: refresh ? "v1/sources/refresh" : "v1/sources", body: StoreJSON.encoder().encode(StoreSourceRequest(url: url)))
    }

    func removeSource(_ url: String) async throws -> [SavedAppSource] {
        try await send(path: "v1/sources/remove", body: StoreJSON.encoder().encode(StoreSourceRequest(url: url)))
    }

    public func install(_ request: StoreInstallRequest) async throws -> RefreshJob {
        try await send(path: "v1/install", body: StoreJSON.encoder().encode(request))
    }

    public func job(_ id: String) async throws -> RefreshJob {
        guard UUID(uuidString: id) != nil else { throw StoreClientError.response("无效的任务编号。") }
        return try await send(path: "v1/jobs/\(id)")
    }

    private func send<T: Decodable>(path: String, body: Data? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StoreClientError.response("Mac 返回了无效响应。") }
        if http.statusCode == 401 { throw StoreClientError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? StoreJSON.decoder().decode(StoreAPIError.self, from: data))?.message
            throw StoreClientError.response(detail ?? "Mac 服务错误（\(http.statusCode)）。")
        }
        return try StoreJSON.decoder().decode(T.self, from: data)
    }
}
