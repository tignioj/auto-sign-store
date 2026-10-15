import Foundation
import Testing
@testable import AutoSignStoreCore

private let taskDevices = [
    StoreDevice(id: "phone", name: "我的 iPhone", model: "iPhone", isConnected: true, isReady: true),
    StoreDevice(id: "ipad", name: "家里的 iPad", model: "iPad", isConnected: true, isReady: true)
]

private func task(_ id: String, device: String, state: RefreshState = .running) -> RefreshJob {
    RefreshJob(id: id, requestID: "request-\(id)", deviceUDID: device, state: state,
               items: [RefreshItem(id: "app-\(id)", name: "App", state: state, message: "progress")],
               createdAt: Date(timeIntervalSince1970: 1_000), updatedAt: Date(timeIntervalSince1970: 1_001))
}

private func status(_ jobs: [RefreshJob], device: String = "phone", latest: RefreshJob? = nil,
                    requestID: String? = nil, devices: [StoreDevice] = taskDevices) -> StoreJobStatus {
    StoreJobStatus(recentJobs: jobs, latestJob: latest, devices: devices,
                   selectedDeviceID: device, requestID: requestID)
}

@Test func otherDeviceRefreshKeepsCurrentDeviceIdleButMacBusy() throws {
    let ipad = task("ipad-refresh", device: "ipad")
    let phoneHistory = task("phone-history", device: "phone", state: .completed)
    let value = status([ipad, phoneHistory])
    #expect(value.activeJob == nil)
    #expect(value.jobs.map(\.id) == [phoneHistory.id])
    #expect(value.isBusy)
    #expect(value.busyJob?.id == ipad.id)
    #expect(value.otherDeviceJob?.id == ipad.id)
    #expect(try #require(value.busyMessage).contains("家里的 iPad"))
    #expect(try #require(value.busyMessage).contains("刷新应用"))
}

@Test func switchingDevicesReclassifiesProgressWithoutLosingTheRunningTask() {
    let ipad = task("ipad-refresh", device: "ipad")
    let initial = status([ipad])
    let switched = status([ipad], device: "ipad")
    #expect(initial.activeJob == nil)
    #expect(switched.activeJob?.id == ipad.id)
    #expect(switched.jobs.map(\.id) == [ipad.id])
    #expect(switched.otherDeviceJob == nil)
    #expect(initial.busyJob?.id == switched.busyJob?.id)
    #expect(status([ipad]).otherDeviceJob?.id == ipad.id)
}

@Test func polledProgressUpdatesOnlyTheMatchingDevicesHistory() throws {
    let queued = task("ipad-refresh", device: "ipad", state: .queued)
    var running = queued
    running.state = .running
    running.items[0].message = "正在更新描述文件"
    let phone = status([queued], latest: running)
    let ipad = status([queued], device: "ipad", latest: running)
    #expect(phone.jobs.isEmpty)
    #expect(phone.activeJob == nil)
    #expect(phone.busyJob?.state == .running)
    #expect(ipad.jobs.count == 1)
    #expect(try #require(ipad.activeJob).items[0].message == "正在更新描述文件")
}

@Test(arguments: [RefreshState.completed, .failed])
func polledCompletionClearsOtherDeviceBusyStateEvenBeforeSnapshotSync(state: RefreshState) {
    let running = task("ipad-refresh", device: "ipad")
    var finished = running
    finished.state = state
    finished.items[0].state = state
    let value = status([running], latest: finished)
    #expect(!value.isBusy)
    #expect(value.otherDeviceJob == nil)
    #expect(value.busyMessage == nil)
    #expect(value.activeJob == nil)
    #expect(status([running], device: "ipad", latest: finished).jobs.first?.state == state)
}

@Test func recoveredRequestResultNeverAppearsAsAnotherDevicesActiveJob() {
    let finished = task("phone-refresh", device: "phone", state: .completed)
    let current = status([finished], requestID: finished.requestID)
    #expect(current.activeJob?.id == finished.id)
    #expect(!current.isBusy)
    let switched = status([finished], device: "ipad", requestID: finished.requestID)
    #expect(switched.activeJob == nil)
    #expect(switched.jobs.isEmpty)
}

@Test func queuedInstallAndUpdateIdentifyTheirDeviceAndOperation() throws {
    var install = task("ipad-install", device: "ipad", state: .queued)
    install.installRequest = StoreInstallRequest(requestID: install.requestID, deviceUDID: "ipad",
        sourceURL: "https://source.test/apps.json", bundleIdentifier: "com.example.app")
    var update = task("ipad-update", device: "ipad", state: .queued)
    update.updateRequest = RefreshRequest(requestID: update.requestID, deviceUDID: "ipad", appIDs: ["app"])
    for (job, operation) in [(install, "安装"), (update, "更新")] {
        let value = status([job])
        #expect(value.isBusy)
        #expect(value.activeJob == nil)
        #expect(value.otherDeviceJob?.id == job.id)
        #expect(try #require(value.busyMessage).contains("家里的 iPad"))
        #expect(try #require(value.busyMessage).contains("\(operation)应用（等待执行）"))
        #expect(job.statusTitle == "等待\(operation)")
    }
}

@Test func missingDeviceAndUnselectedDeviceStillIdentifyTheBusyTarget() throws {
    let job = task("ipad-refresh", device: "ipad")
    let value = status([job], device: "", devices: [])
    #expect(value.activeJob == nil)
    #expect(value.jobs.isEmpty)
    #expect(value.isBusy)
    #expect(try #require(value.busyMessage).contains("设备 ipad"))
    let unnamed = StoreDevice(id: "ipad", name: "  ", model: "iPad", isConnected: false, isReady: false)
    #expect(try #require(status([job], devices: [unnamed]).busyMessage).contains("设备 ipad"))
}
