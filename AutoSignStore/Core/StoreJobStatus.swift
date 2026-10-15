import Foundation

/// Keeps device progress separate from the Mac's shared task worker.
struct StoreJobStatus {
    let allJobs: [RefreshJob]
    let devices: [StoreDevice]
    let selectedDeviceID: String
    let requestID: String?

    init(recentJobs: [RefreshJob], latestJob: RefreshJob?, devices: [StoreDevice],
         selectedDeviceID: String, requestID: String?) {
        // A polled result takes precedence over an older status snapshot, including completion.
        if let latestJob {
            allJobs = [latestJob] + recentJobs.filter { $0.id != latestJob.id }
        } else {
            allJobs = recentJobs
        }
        self.devices = devices
        self.selectedDeviceID = selectedDeviceID
        self.requestID = requestID
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
            ?? "设备 \(job.deviceUDID)"
        let queued = job.state == .queued ? "（等待执行）" : ""
        return "Mac 正在为「\(deviceName)」\(job.operationTitle)应用\(queued)"
    }
}

extension RefreshJob {
    var operationTitle: String {
        if updateRequest != nil { return "更新" }
        return installRequest == nil ? "刷新" : "安装"
    }

    var statusTitle: String {
        switch state {
        case .queued: "等待\(operationTitle)"
        case .running: "正在\(operationTitle)"
        case .completed: "已完成"
        case .failed: "需要处理"
        }
    }
}
