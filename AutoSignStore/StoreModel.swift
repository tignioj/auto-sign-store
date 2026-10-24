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
    @Published private var latestJob: RefreshJob?
    @Published private(set) var error: String?
    @Published private(set) var sources: [SavedAppSource] = []
    @Published private(set) var isManagingSources = false
    @Published private(set) var sourceError: String?
    @Published private(set) var isCheckingUpdates = false
    @Published var selectedTab = 0
    @Published var includeSelf = true
    private var savedAddress: String
    private var client: StoreClient?
    private var connectionTask: Task<Void, Never>?
    private var connectionGeneration = UUID()
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
    private var jobStatus: StoreJobStatus {
        StoreJobStatus(recentJobs: snapshot?.recentJobs ?? [], latestJob: latestJob, devices: devices,
                       selectedDeviceID: selectedDeviceID, requestID: requestID)
    }
    var jobs: [RefreshJob] { jobStatus.jobs }
    var activeJob: RefreshJob? { jobStatus.activeJob }
    var hasCredentials: Bool { client != nil }
    var isRefreshing: Bool { isSubmitting || activeJob.map { !$0.state.isTerminal } == true }
    var isServerBusy: Bool { isSubmitting || jobStatus.isBusy }
    var currentTaskTitle: String { isSubmitting ? L10n.tr("task.submitting") : "\(activeJob?.statusTitle ?? L10n.tr("task.processing"))…" }
    var serverTaskMessage: String? {
        guard let message = jobStatus.busyMessage else { return nil }
        return isConnected ? L10n.tr("task.wait", message) : L10n.tr("task.offline", message)
    }
    var otherDeviceTaskMessage: String? { jobStatus.otherDeviceJob == nil ? nil : serverTaskMessage }
    var refreshableApps: [StoreApp] { apps.filter { includeSelf || !$0.isStore } }
    var needsAttention: Int { apps.filter { $0.remainingDays() <= 1 }.count }
    var serverName: String { snapshot?.serverName ?? L10n.tr("connection.yourMac") }
    var supportsSources: Bool { snapshot?.capabilities?.contains("sources") == true }
    var supportsUpdates: Bool { snapshot?.capabilities?.contains("updates") == true }
    var supportsProfileRefresh: Bool { snapshot?.capabilities?.contains("profile-refresh") == true }
    var updates: [StoreAppUpdate] {
        (snapshot?.availableUpdates ?? []).filter { $0.deviceUDID == selectedDeviceID }
    }
    var canManageSources: Bool { isConnected && supportsSources && !isLoading && !isManagingSources && !isServerBusy && !isCheckingUpdates }
    var canInstall: Bool { canRefresh && snapshot?.capabilities?.contains("install") == true }
    var canRefresh: Bool { isConnected && currentDevice?.isReady == true && !isLoading && !isServerBusy && !isManagingSources && !isCheckingUpdates }
    var canUpdate: Bool { canRefresh && supportsUpdates }
    var canChangeConnection: Bool { !isLoading && !isSubmitting && !isManagingSources && !isCheckingUpdates && (!isServerBusy || !isConnected) }

    func pair() async {
        guard canChangeConnection else { return }
        error = nil
        await runConnection { [self] generation in
            do {
                let canonical = try ServerAddress.parse(address).absoluteString
                let token = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty else { throw StoreClientError.response(L10n.tr("error.emptyToken")) }
                let candidate = try StoreClient(address: canonical, token: token)
                let value = try await candidate.snapshot()
                guard isCurrentConnection(generation) else { return }
                try CredentialStore.save(token, for: canonical)
                stopPolling()
                client = candidate
                savedAddress = canonical
                address = canonical
                UserDefaults.standard.set(canonical, forKey: "serverAddress")
                selectedDeviceID = UserDefaults.standard.string(forKey: "deviceID.\(canonical)") ?? ""
                requestID = try? journal.load(for: canonical)
                latestJob = nil
                sources = []; sourceError = nil
                pairingToken = ""
                accept(value)
                await loadSources()
                guard isCurrentConnection(generation) else { return }
                resumePolling()
            } catch {
                guard isCurrentConnection(generation) else { return }
                self.error = error.localizedDescription
            }
        }
    }

    func sync(reportErrors: Bool = true) async {
        guard let client, !isLoading, !isManagingSources, !isCheckingUpdates, !isSubmitting || reportErrors else { return }
        await runConnection { [self] generation in
            do {
                let value = try await client.snapshot()
                guard isCurrentConnection(generation) else { return }
                accept(value)
                if reportErrors { error = nil }
                await loadSources()
                guard isCurrentConnection(generation) else { return }
                resumePolling()
            } catch {
                guard isCurrentConnection(generation) else { return }
                isConnected = false
                if reportErrors { self.error = connectionMessage(error) }
            }
        }
    }

    func cancelConnection() {
        guard isLoading else { return }
        connectionGeneration = UUID()
        connectionTask?.cancel()
        connectionTask = nil
        stopPolling()
        isLoading = false
        isManagingSources = false
    }

    private func runConnection(_ operation: @escaping @MainActor (UUID) async -> Void) async {
        let generation = UUID()
        connectionGeneration = generation
        isLoading = true
        let task = Task {
            defer {
                // A cancelled attempt must not clear a newer attempt's loading state.
                if connectionGeneration == generation {
                    connectionTask = nil
                    isLoading = false
                }
            }
            await operation(generation)
        }
        connectionTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func isCurrentConnection(_ generation: UUID) -> Bool {
        connectionGeneration == generation && !Task.isCancelled
    }

    func checkUpdates() async {
        guard let client, supportsUpdates, canManageSources, !isLoading else { return }
        isCheckingUpdates = true; error = nil
        defer { isCheckingUpdates = false }
        do {
            accept(try await client.checkUpdates())
            await loadSources()
            resumePolling()
        } catch { self.error = connectionMessage(error) }
    }

    func updateApps(_ selection: [StoreAppUpdate]) async {
        guard let client, canUpdate, !selection.isEmpty,
              selection.allSatisfy({ $0.deviceUDID == selectedDeviceID }) else { return }
        isSubmitting = true; error = nil
        defer { isSubmitting = false }
        let id = UUID().uuidString
        do { try journal.save(id, for: savedAddress) }
        catch { self.error = L10n.tr("error.saveUpdate", error.localizedDescription); return }
        requestID = id
        let request = RefreshRequest(requestID: id, deviceUDID: selectedDeviceID, appIDs: selection.map(\.id))
        selectedTab = 1
        do { latestJob = try await client.updateApps(request); stopPolling(); resumePolling() }
        catch {
            let message = L10n.tr("error.uncertainUpdate", connectionMessage(error))
            await sync()
            self.error = message
        }
    }

    func refresh(_ selection: [StoreApp]) async {
        guard let client, canRefresh, !selection.isEmpty,
              selection.allSatisfy({ $0.deviceUDID == selectedDeviceID }) else { return }
        isSubmitting = true; error = nil
        let id = UUID().uuidString
        // This is written before the HTTP request: a self-install can close the app before the response arrives.
        do { try journal.save(id, for: savedAddress) }
        catch {
            self.error = L10n.tr("error.saveRefresh", error.localizedDescription)
            isSubmitting = false
            return
        }
        requestID = id
        let request = RefreshRequest(requestID: id, deviceUDID: selectedDeviceID, appIDs: selection.map(\.id))
        do {
            latestJob = try await client.refresh(request)
            stopPolling()
            resumePolling()
        } catch {
            let message = L10n.tr("error.uncertainRefresh", connectionMessage(error))
            // An uncertain response never causes an automatic duplicate refresh.
            await sync()
            self.error = message
        }
        isSubmitting = false
    }

    func loadSources() async {
        guard let client, isConnected, supportsSources, !isManagingSources else { return }
        let generation = connectionGeneration
        isManagingSources = true
        defer { if connectionGeneration == generation { isManagingSources = false } }
        do {
            let value = try await client.sources()
            guard isCurrentConnection(generation) else { return }
            acceptSources(value)
            sourceError = nil
        } catch {
            guard isCurrentConnection(generation) else { return }
            sourceError = connectionMessage(error)
        }
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
        catch { self.error = L10n.tr("error.saveInstall", error.localizedDescription); return }
        requestID = id
        let request = StoreInstallRequest(requestID: id, deviceUDID: selectedDeviceID,
                                          sourceURL: source.id, bundleIdentifier: app.id)
        selectedTab = 1
        do { latestJob = try await client.install(request); stopPolling(); resumePolling() }
        catch {
            let message = L10n.tr("error.uncertainInstall", connectionMessage(error))
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
        client = nil; snapshot = nil; latestJob = nil
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
        latestJob = nil
    }

    private func resumePolling() {
        guard isForeground, pollTask == nil, let client else { return }
        let expectedAddress = savedAddress
        let generation = UUID()
        pollGeneration = generation
        pollTask = Task { [weak self] in
            defer { if self?.pollGeneration == generation { self?.pollTask = nil } }
            while !Task.isCancelled {
                do {
                    let busy = self?.isServerBusy == true && self?.isConnected == true
                    try await Task.sleep(for: .seconds(busy ? 2 : 30))
                    guard let self, !Task.isCancelled, self.savedAddress == expectedAddress,
                          self.pollGeneration == generation else { return }
                    if let job = self.jobStatus.busyJob {
                        let updated = try await client.job(job.id)
                        guard !Task.isCancelled, self.pollGeneration == generation else { return }
                        self.latestJob = updated
                        self.isConnected = true
                        if updated.state.isTerminal { await self.sync(reportErrors: false) }
                    } else {
                        await self.sync(reportErrors: false)
                    }
                } catch is CancellationError { return }
                catch {
                    guard let self, !Task.isCancelled, self.pollGeneration == generation else { return }
                    if self.isConnected { self.error = self.connectionMessage(error) }
                    self.isConnected = false
                    // Stay alive while foreground so a returning Mac reconnects automatically.
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
                return L10n.tr("error.connection")
            }
        }
        return error.localizedDescription
    }
}
