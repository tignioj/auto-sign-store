import Foundation
import UIKit

@MainActor
final class StoreModel: ObservableObject {
    @Published var address: String
    @Published var pairingToken = ""
    @Published var selectedDeviceID: String {
        didSet { UserDefaults.standard.set(selectedDeviceID, forKey: "deviceID.\(savedAddress)") }
    }
    @Published private(set) var snapshot: StoreSnapshot?
    @Published private(set) var isConnected = false
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var activeJob: RefreshJob?
    @Published private(set) var error: String?
    @Published private(set) var sources: [SavedAppSource] = []
    @Published private(set) var isManagingSources = false
    @Published private(set) var sourceError: String?
    @Published var selectedTab = 0
    @Published var includeSelf = true
    private var savedAddress: String
    private var client: StoreClient?
    private var pollTask: Task<Void, Never>?
    private var pollGeneration = UUID()
    private var isForeground = true
    private var requestID: String?
    private let journal = RefreshJournal(directory: URL.applicationSupportDirectory.appendingPathComponent("AutoSignStore"))

    init() {
        let address = UserDefaults.standard.string(forKey: "serverAddress") ?? ""
        self.address = address
        self.savedAddress = address
        self.selectedDeviceID = UserDefaults.standard.string(forKey: "deviceID.\(address)") ?? ""
        if let token = CredentialStore.load(for: address), !address.isEmpty {
            client = try? StoreClient(address: address, token: token)
        }
        if let data = UserDefaults.standard.data(forKey: "cachedSources.\(address)"),
           let cached = try? StoreJSON.decoder().decode([SavedAppSource].self, from: data) { sources = cached }
        requestID = try? journal.load(for: address)
        if let data = UserDefaults.standard.data(forKey: "cachedSnapshot.\(address)"),
           let value = try? StoreJSON.decoder().decode(StoreSnapshot.self, from: data) {
            snapshot = value
            activeJob = value.recentJobs.first { $0.requestID == requestID }
        }
    }

    var devices: [StoreDevice] { snapshot?.devices ?? [] }
    var currentDevice: StoreDevice? { devices.first { $0.id == selectedDeviceID } }
    var apps: [StoreApp] {
        (snapshot?.apps ?? []).filter { $0.deviceUDID == selectedDeviceID }
            .sorted { lhs, rhs in
                if lhs.isStore != rhs.isStore { return lhs.isStore }
                return lhs.expiration < rhs.expiration
            }
    }
    var jobs: [RefreshJob] { (snapshot?.recentJobs ?? []).filter { $0.deviceUDID == selectedDeviceID } }
    var hasCredentials: Bool { client != nil }
    var isRefreshing: Bool { isSubmitting || activeJob.map { !$0.state.isTerminal } == true }
    var refreshableApps: [StoreApp] { apps.filter { includeSelf || !$0.isStore } }
    var needsAttention: Int { apps.filter { $0.remainingDays() <= 1 }.count }
    var serverName: String { snapshot?.serverName ?? "你的 Mac" }
    var supportsSources: Bool { snapshot?.capabilities?.contains("sources") == true }
    var canManageSources: Bool { isConnected && supportsSources && !isManagingSources && !isRefreshing }
    var canInstall: Bool { canRefresh && snapshot?.capabilities?.contains("install") == true }
    var canRefresh: Bool { isConnected && currentDevice?.isReady == true && !isRefreshing && !isManagingSources }
    var canChangeConnection: Bool { !isLoading && !isSubmitting && !isManagingSources && (!isRefreshing || !isConnected) }

    func pair() async {
        guard canChangeConnection else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let canonical = try ServerAddress.parse(address).absoluteString
            let token = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { throw StoreClientError.response("请输入 Mac 上显示的配对密钥。") }
            let candidate = try StoreClient(address: canonical, token: token)
            let value = try await candidate.snapshot()
            try CredentialStore.save(token, for: canonical)
            stopPolling()
            client = candidate
            savedAddress = canonical
            address = canonical
            UserDefaults.standard.set(canonical, forKey: "serverAddress")
            selectedDeviceID = UserDefaults.standard.string(forKey: "deviceID.\(canonical)") ?? ""
            requestID = try? journal.load(for: canonical)
            activeJob = nil
            sources = []; sourceError = nil
            pairingToken = ""
            accept(value)
            await loadSources()
            resumePolling()
        } catch { self.error = error.localizedDescription }
    }

    func sync() async {
        guard let client, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do { accept(try await client.snapshot()); error = nil; await loadSources(); resumePolling() }
        catch { isConnected = false; self.error = connectionMessage(error) }
    }

    func refresh(_ selection: [StoreApp]) async {
        guard let client, canRefresh, !selection.isEmpty else { return }
        isSubmitting = true; error = nil
        let id = UUID().uuidString
        // This is written before the HTTP request: a self-install can close the app before the response arrives.
        do { try journal.save(id, for: savedAddress) }
        catch {
            self.error = "无法保存刷新任务：\(error.localizedDescription)"
            isSubmitting = false
            return
        }
        requestID = id
        let request = RefreshRequest(requestID: id, deviceUDID: selectedDeviceID, appIDs: selection.map(\.id))
        do {
            activeJob = try await client.refresh(request)
            resumePolling()
        } catch {
            let message = "\(connectionMessage(error)) 如果请求已送达，Mac 会继续执行；重新连接后可在活动中查看。"
            // An uncertain response never causes an automatic duplicate refresh.
            await sync()
            self.error = message
        }
        isSubmitting = false
    }

    func loadSources() async {
        guard let client, isConnected, supportsSources, !isManagingSources else { return }
        isManagingSources = true
        defer { isManagingSources = false }
        do { acceptSources(try await client.sources()); sourceError = nil }
        catch { sourceError = connectionMessage(error) }
    }

    @discardableResult
    func saveSource(_ input: String, refresh: Bool = false) async -> Bool {
        guard let client, canManageSources else { return false }
        isManagingSources = true; sourceError = nil
        defer { isManagingSources = false }
        do { acceptSources(try await client.saveSource(input, refresh: refresh)); return true }
        catch { sourceError = connectionMessage(error); return false }
    }

    func removeSource(_ source: SavedAppSource) async {
        guard let client, canManageSources else { return }
        isManagingSources = true; sourceError = nil
        defer { isManagingSources = false }
        do { acceptSources(try await client.removeSource(source.id)) }
        catch { sourceError = connectionMessage(error) }
    }

    func install(_ app: SourceApp, from source: SavedAppSource) async {
        guard let client, canInstall, app.latestVersion != nil else { return }
        isSubmitting = true; error = nil
        defer { isSubmitting = false }
        let id = UUID().uuidString
        do { try journal.save(id, for: savedAddress) }
        catch { self.error = "无法保存安装任务：\(error.localizedDescription)"; return }
        requestID = id
        let request = StoreInstallRequest(requestID: id, deviceUDID: selectedDeviceID,
                                          sourceURL: source.id, bundleIdentifier: app.id)
        selectedTab = 1
        do { activeJob = try await client.install(request); resumePolling() }
        catch {
            let message = "\(connectionMessage(error)) 如果请求已送达，Mac 会继续安装；重新连接后可在活动中查看。"
            await sync()
            self.error = message
        }
    }

    private func acceptSources(_ value: [SavedAppSource]) {
        sources = value
        if let data = try? StoreJSON.encoder().encode(value) {
            UserDefaults.standard.set(data, forKey: "cachedSources.\(savedAddress)")
        }
    }

    func sceneChanged(active: Bool) async {
        isForeground = active
        if active { await sync() }
        else { stopPolling() }
    }

    func disconnect() {
        guard canChangeConnection else { return }
        stopPolling()
        CredentialStore.remove(for: savedAddress)
        UserDefaults.standard.removeObject(forKey: "serverAddress")
        client = nil; snapshot = nil; activeJob = nil
        isConnected = false; error = nil; pairingToken = ""
        sources = []; sourceError = nil
    }

    func clearError() { error = nil }

    private func accept(_ value: StoreSnapshot) {
        snapshot = value
        if let data = try? StoreJSON.encoder().encode(value) {
            UserDefaults.standard.set(data, forKey: "cachedSnapshot.\(savedAddress)")
        }
        isConnected = true
        if let job = value.recentJobs.first(where: { !$0.state.isTerminal }) {
            activeJob = job
        } else if let id = requestID, let job = value.recentJobs.first(where: { $0.requestID == id }) {
            activeJob = job
        } else { activeJob = nil }
    }

    private func resumePolling() {
        guard isForeground, pollTask == nil, let client, let job = activeJob, !job.state.isTerminal else { return }
        let expectedAddress = savedAddress
        let generation = UUID()
        pollGeneration = generation
        pollTask = Task { [weak self] in
            defer { if self?.pollGeneration == generation { self?.pollTask = nil } }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(2))
                    let updated = try await client.job(job.id)
                    guard let self, !Task.isCancelled, self.savedAddress == expectedAddress,
                          self.pollGeneration == generation else { return }
                    self.activeJob = updated
                    self.isConnected = true
                    if updated.state.isTerminal {
                        self.accept(try await client.snapshot())
                        return
                    }
                } catch is CancellationError { return }
                catch {
                    guard let self, !Task.isCancelled, self.pollGeneration == generation else { return }
                    self.isConnected = false
                    self.error = self.connectionMessage(error)
                    return
                }
            }
        }
    }

    private func stopPolling() {
        pollGeneration = UUID()
        pollTask?.cancel()
        pollTask = nil
    }

    private func connectionMessage(_ error: Error) -> String {
        if let value = error as? URLError {
            if value.code == .notConnectedToInternet || value.code == .cannotConnectToHost || value.code == .cannotFindHost || value.code == .timedOut {
                return "暂时无法连接 Mac。请确认同一 Wi-Fi、AutoSign 局域网服务已开启，并允许本地网络访问。"
            }
        }
        return error.localizedDescription
    }
}
