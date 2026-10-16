import Foundation

/// Keeps device progress separate from the Mac's shared task worker.
struct StoreJobStatus {
    let allJobs: [RefreshJob]
    let devices: [StoreDevice]
    let selectedDeviceID: String
    let requestID: String?
    let locale: Locale

    init(recentJobs: [RefreshJob], latestJob: RefreshJob?, devices: [StoreDevice],
         selectedDeviceID: String, requestID: String?, locale: Locale = L10n.locale) {
        // A polled result takes precedence over an older status snapshot, including completion.
        if let latestJob {
            allJobs = [latestJob] + recentJobs.filter { $0.id != latestJob.id }
        } else {
            allJobs = recentJobs
        }
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.requestID = requestID
        self.locale = locale
    }

    var jobs: [RefreshJob] { allJobs.filter { $0.deviceUDID == selectedDeviceID } }
    var activeJob: RefreshJob? {
        jobs.first { !$0.state.isTerminal }
            ?? jobs.first { requestID != nil && $0.requestID == requestID }
    }
    var busyJob: RefreshJob? { allJobs.first { !$0.state.isTerminal } }
    var isBusy: Bool { busyJob != nil }
    var otherDeviceJob: RefreshJob? {
        busyJob.flatMap { $0.deviceUDID == selectedDeviceID ? nil : $0 }
    }
    var busyMessage: String? {
        guard let job = busyJob else { return nil }
        let name = devices.first { $0.id == job.deviceUDID }?.name
        let deviceName = name.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            ?? L10n.string("device.fallback", locale: locale, arguments: [job.deviceUDID])
        let queued = job.state == .queued ? L10n.string("task.queuedSuffix", locale: locale) : ""
        return L10n.string("task.busy.\(job.operationKey)", locale: locale, arguments: [deviceName]) + queued
    }
}

extension RefreshJob {
    fileprivate var operationKey: String {
        if updateRequest != nil { return "update" }
        return installRequest == nil ? "refresh" : "install"
    }

    var operationTitle: String { L10n.tr("task.operation.\(operationKey)") }
    var statusTitle: String { statusTitle(locale: L10n.locale) }

    func statusTitle(locale: Locale) -> String {
        switch state {
        case .queued: L10n.string("task.queued.\(operationKey)", locale: locale)
        case .running: L10n.string("task.running.\(operationKey)", locale: locale)
        case .completed: L10n.string("state.completed", locale: locale)
        case .failed: L10n.string("state.failed", locale: locale)
        }
    }
}
