import Foundation

public enum StoreClientError: LocalizedError {
    case invalidAddress, unauthorized, incompatibleServer, invalidIPA(String), response(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress: L10n.tr("error.invalidAddress")
        case .unauthorized: L10n.tr("error.unauthorized")
        case .incompatibleServer: L10n.tr("error.incompatibleServer")
        case .invalidIPA(let message), .response(let message): message
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

    public func installIPA(at url: URL, requestID: String, deviceUDID: String) async throws -> RefreshJob {
        guard url.isFileURL, url.pathExtension.lowercased() == "ipa" else {
            throw StoreClientError.invalidIPA(L10n.tr("ipa.invalidFile"))
        }
        let staged = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
        defer { try? FileManager.default.removeItem(at: staged) }
        let size = try Self.stageIPA(at: url, to: staged)
        try Task.checkCancellation()

        var request = authenticatedRequest(path: "v1/install/ipa")
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(String(size), forHTTPHeaderField: "Content-Length")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.setValue(deviceUDID, forHTTPHeaderField: "X-Device-UDID")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.setValue(url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: allowed),
                         forHTTPHeaderField: "X-IPA-Filename")

        let configuration = session.configuration
        configuration.timeoutIntervalForResource = 60 * 60
        let uploadSession = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        defer { uploadSession.finishTasksAndInvalidate() }
        let (data, response) = try await uploadSession.upload(for: request, fromFile: staged)
        return try decode(data, response)
    }

    /// File providers can move or replace a document. Keep a coordinated snapshot until the request finishes.
    private static func stageIPA(at url: URL, to destination: URL) throws -> Int {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Int, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { file in
            result = Result {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true, let size = values.fileSize, size > 0 else {
                    throw StoreClientError.invalidIPA(L10n.tr("ipa.invalidFile"))
                }
                guard size <= 4 * 1024 * 1024 * 1024 else {
                    throw StoreClientError.invalidIPA(L10n.tr("ipa.tooLarge"))
                }
                try FileManager.default.copyItem(at: file, to: destination)
                return size
            }
        }
        do {
            if let coordinationError { throw coordinationError }
            guard let result else { throw StoreClientError.invalidIPA(L10n.tr("ipa.invalidFile")) }
            return try result.get()
        } catch let error as StoreClientError { throw error }
        catch { throw StoreClientError.invalidIPA(L10n.tr("ipa.readError", error.localizedDescription)) }
    }

    public func job(_ id: String) async throws -> RefreshJob {
        guard UUID(uuidString: id) != nil else { throw StoreClientError.response(L10n.tr("error.invalidJob")) }
        return try await send(path: "v1/jobs/\(id)")
    }

    private func authenticatedRequest(path: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(L10n.language.resolved().rawValue, forHTTPHeaderField: "Accept-Language")
        return request
    }

    private func send<T: Decodable>(path: String, body: Data? = nil) async throws -> T {
        var request = authenticatedRequest(path: path)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        return try decode(data, response)
    }

    private func decode<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else { throw StoreClientError.response(L10n.tr("error.invalidResponse")) }
        if http.statusCode == 401 { throw StoreClientError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? StoreJSON.decoder().decode(StoreAPIError.self, from: data))?.message
            throw StoreClientError.response(detail ?? L10n.tr("error.server", http.statusCode))
        }
        return try StoreJSON.decoder().decode(T.self, from: data)
    }
}
