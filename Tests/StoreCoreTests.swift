import Foundation
import Testing
@testable import AutoSignStoreCore

@Test func acceptsOnlyLocalServerAddresses() throws {
    for value in ["http://192.168.1.10:8091", "http://10.0.0.1:8091", "http://172.16.0.1:8091", "http://Mac.local:8091", "http://Mac.local.:8091", "http://[fd12::1]:8091", "http://localhost:8091"] {
        #expect(throws: Never.self) { try ServerAddress.parse(value) }
    }
    for value in ["https://example.com", "file:///tmp/test", "http://8.8.8.8:8091", "http://192.168.1.999", "http://172.32.0.1", "http://192.168.1.1/path", "http://user:pass@Mac.local", "http://Mac.local?token=secret", "http://Mac.local#fragment", "http://Mac.local:0", "http://Mac.local:65536"] {
        #expect(throws: StoreClientError.self) { try ServerAddress.parse(value) }
    }
}

@Test func expiryNeverClaimsExtraValidity() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    func app(_ interval: Double) -> StoreApp {
        StoreApp(id: "app", deviceUDID: "phone", name: "App", bundleIdentifier: "test.app", version: "1",
                 expiration: now.addingTimeInterval(interval), refreshedAt: now, isStore: false)
    }
    #expect(app(-1).remainingDays(at: now) == 0)
    #expect(app(0).remainingDays(at: now) == 0)
    #expect(app(1).remainingDays(at: now) == 1)
    #expect(app(86_401).remainingDays(at: now) == 2)
}

private final class MockProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct ClientContractTests {
    func client() throws -> StoreClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        return try StoreClient(address: "http://Mac.local:8091", token: " test-token ", session: URLSession(configuration: config))
    }

    @Test func authenticatesAndDecodesSnapshot() async throws {
        MockProtocol.handler = { request in
            #expect(request.url?.path == "/v1/status")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            #expect(request.httpMethod == "GET")
            return (200, Data(#"{"protocolVersion":1,"serverName":"Mac","devices":[],"apps":[],"recentJobs":[]}"#.utf8))
        }
        let result = try await client().snapshot()
        #expect(result.serverName == "Mac")
    }

    @Test func rejectsUnsupportedProtocolVersion() async throws {
        MockProtocol.handler = { _ in
            (200, Data(#"{"protocolVersion":2,"serverName":"Mac","devices":[],"apps":[],"recentJobs":[]}"#.utf8))
        }
        await #expect(throws: StoreClientError.self) { try await client().snapshot() }
    }

    @Test func propagatesAuthenticationAndServerErrors() async throws {
        MockProtocol.handler = { _ in (401, Data(#"{"message":"secret"}"#.utf8)) }
        do { _ = try await client().snapshot(); Issue.record("Expected authentication failure") }
        catch { #expect(error.localizedDescription.contains("配对密钥无效")) }
        MockProtocol.handler = { _ in (409, Data(#"{"message":"Mac 正在刷新应用"}"#.utf8)) }
        do { _ = try await client().snapshot(); Issue.record("Expected busy error") }
        catch { #expect(error.localizedDescription == "Mac 正在刷新应用") }
    }

    @Test func rejectsInvalidJobPathBeforeNetworkRequest() async throws {
        MockProtocol.handler = { _ in Issue.record("Must not perform network request"); return (200, Data()) }
        await #expect(throws: StoreClientError.self) { try await client().job("../../v1/status") }
    }

    @Test func postsStableRequestIDForSelfRefreshRecovery() async throws {
        let requestID = UUID().uuidString
        let jobID = UUID().uuidString
        MockProtocol.handler = { request in
            #expect(request.url?.path == "/v1/refresh")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            let stream = try #require(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            let input = try StoreJSON.decoder().decode(RefreshRequest.self, from: data)
            #expect(input.requestID == requestID)
            #expect(input.appIDs == ["regular-app", "store-app"])
            let job = RefreshJob(id: jobID, requestID: requestID, deviceUDID: "phone", state: .queued,
                                 items: [], createdAt: Date(), updatedAt: Date())
            return (202, try StoreJSON.encoder().encode(job))
        }
        let result = try await client().refresh(RefreshRequest(requestID: requestID, deviceUDID: "phone", appIDs: ["regular-app", "store-app"]))
        #expect(result.requestID == requestID)
        #expect(result.id == jobID)
    }

    @Test func incompleteResponseIsNotASuccess() async throws {
        MockProtocol.handler = { _ in (200, Data(#"{"protocolVersion":1}"#.utf8)) }
        await #expect(throws: DecodingError.self) { try await client().snapshot() }
    }
}

@Test func pendingRequestSurvivesNewClientInstanceAndPreservesOtherServers() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let first = RefreshJournal(directory: folder)
    #expect(try first.load(for: "http://one.local:8091") == nil)
    let id = UUID().uuidString
    try first.save(id, for: "http://one.local:8091")
    let second = RefreshJournal(directory: folder)
    #expect(try second.load(for: "http://one.local:8091") == id)
    try second.save("another", for: "http://two.local:8091")
    #expect(try first.load(for: "http://one.local:8091") == id)
    #expect(try first.load(for: "http://two.local:8091") == "another")
}

extension ClientContractTests {
    @Test func oldServersRemainCompatibleWithoutSourceCapabilities() async throws {
        MockProtocol.handler = { _ in
            (200, Data(#"{"protocolVersion":1,"serverName":"Old Mac","devices":[],"apps":[],"recentJobs":[]}"#.utf8))
        }
        #expect(try await client().snapshot().capabilities == nil)
    }

    @Test func sourceAPIUsesAuthAndReturnsNormalizedCatalog() async throws {
        MockProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            #expect(["/v1/sources", "/v1/sources/refresh", "/v1/sources/remove"].contains(request.url?.path))
            if request.httpMethod == "POST" {
                let input = try StoreJSON.decoder().decode(StoreSourceRequest.self, from: requestData(request))
                #expect(input.url == "https://source.test/apps.json")
            }
            return (200, Data(#"[{"url":"https://source.test/apps.json","updatedAt":"2026-10-14T12:00:00Z","catalog":{"name":"Demo Source","apps":[{"name":"Demo","bundleIdentifier":"com.example.demo","versions":[{"version":"2","downloadURL":"https://source.test/demo.ipa"}]}]}}]"#.utf8))
        }
        let api = try client()
        #expect(try await api.sources().first?.catalog.name == "Demo Source")
        #expect(try await api.saveSource("https://source.test/apps.json").first?.catalog.apps.first?.latestVersion?.version == "2")
        #expect(try await api.saveSource("https://source.test/apps.json", refresh: true).count == 1)
        #expect(try await api.removeSource("https://source.test/apps.json").count == 1)
    }

    @Test func installContractPreservesRequestForRecoveryAndSendsOnlySourceSelection() async throws {
        let input = StoreInstallRequest(requestID: UUID().uuidString, deviceUDID: "phone", sourceURL: "https://source.test/apps.json", bundleIdentifier: "com.example.demo")
        MockProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/v1/install")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            #expect(try StoreJSON.decoder().decode(StoreInstallRequest.self, from: requestData(request)) == input)
            let job = RefreshJob(id: UUID().uuidString, requestID: input.requestID, deviceUDID: input.deviceUDID,
                state: .queued, items: [], createdAt: Date(), updatedAt: Date(), installRequest: input)
            return (202, try StoreJSON.encoder().encode(job))
        }
        let result = try await client().install(input)
        #expect(result.installRequest == input)
    }

    @Test func sourceAndInstallFailuresPropagateToCaller() async throws {
        MockProtocol.handler = { _ in (409, Data(#"{"message":"Mac 正在处理任务"}"#.utf8)) }
        await #expect(throws: StoreClientError.self) { try await client().saveSource("https://source.test/apps.json") }
        let input = StoreInstallRequest(requestID: UUID().uuidString, deviceUDID: "phone", sourceURL: "https://source.test/apps.json", bundleIdentifier: "com.example.demo")
        await #expect(throws: StoreClientError.self) { try await client().install(input) }
    }
}

private func requestData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try #require(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: buffer.count)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

@Test func legacyRefreshJobsDecodeAfterInstallSupportIsAdded() throws {
    let json = #"{"id":"id","requestID":"request","deviceUDID":"phone","state":"completed","items":[],"createdAt":"2026-10-14T12:00:00Z","updatedAt":"2026-10-14T12:00:00Z"}"#
    let job = try StoreJSON.decoder().decode(RefreshJob.self, from: Data(json.utf8))
    #expect(job.installRequest == nil)
    #expect(job.state == .completed)
}
