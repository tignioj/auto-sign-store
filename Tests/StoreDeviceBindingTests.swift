import Foundation
import Testing
@testable import AutoSignStoreCore

private struct BindingPreferences {
    let suite = "AutoSignStoreTests.Binding.\(UUID().uuidString)"
    let preferences: UserDefaults

    init() { preferences = UserDefaults(suiteName: suite)! }
    func close() { preferences.removePersistentDomain(forName: suite) }
}

private func bindingDevice(_ id: String, ready: Bool = true) -> StoreDevice {
    StoreDevice(id: id, name: "Same name", model: "iPhone", isConnected: ready, isReady: ready)
}

@Test func installationBindingOverridesLegacySelectionOnConnectionAndPersistsAcrossUpdates() {
    let storage = BindingPreferences()
    defer { storage.close() }
    let server = "http://mac.local:8091"
    storage.preferences.set("other", forKey: "deviceID.\(server)")
    let installed = StoreDeviceBinding(info: ["AutoSignStoreDeviceUDID": "phone"], preferences: storage.preferences)
    let devices = [bindingDevice("other"), bindingDevice("phone")]
    #expect(installed.preferredSelection(for: server) == "phone")
    #expect(installed.resolveSelection("other", devices: devices, preferLocalDevice: true) == "phone")
    // An older Mac may overwrite the bundle without adding installation metadata.
    let updated = StoreDeviceBinding(info: [:], preferences: storage.preferences)
    #expect(updated.deviceID == "phone")
    #expect(updated.preferredSelection(for: "http://new-address.local:8091") == "phone")
    let reinstalled = StoreDeviceBinding(info: ["AutoSignStoreDeviceUDID": "ipad"], preferences: storage.preferences)
    #expect(reinstalled.deviceID == "ipad")
    #expect(StoreDeviceBinding(info: [:], preferences: storage.preferences).deviceID == "ipad")
}

@Test func manualDeviceSwitchSurvivesPollingWithoutChangingTheLocalBinding() {
    let storage = BindingPreferences()
    defer { storage.close() }
    let binding = StoreDeviceBinding(info: ["AutoSignStoreDeviceUDID": "phone"], preferences: storage.preferences)
    let devices = [bindingDevice("phone"), bindingDevice("ipad")]
    binding.saveSelection("ipad", for: "mac")
    #expect(binding.resolveSelection("ipad", devices: devices) == "ipad")
    #expect(binding.resolveSelection("ipad", devices: devices, preferLocalDevice: true) == "phone")
    #expect(binding.preferredSelection(for: "mac") == "phone")
    #expect(StoreDeviceBinding(info: [:], preferences: storage.preferences).deviceID == "phone")
}

@Test func missingLocalDeviceDoesNotSelectAnUnrelatedReadyDeviceAndRecoversWhenItReturns() {
    let storage = BindingPreferences()
    defer { storage.close() }
    let binding = StoreDeviceBinding(info: ["AutoSignStoreDeviceUDID": "phone"], preferences: storage.preferences)
    #expect(binding.resolveSelection("phone", devices: [bindingDevice("other")]) == "")
    #expect(binding.resolveSelection("other", devices: [bindingDevice("other")], preferLocalDevice: true) == "")
    #expect(binding.resolveSelection("phone", devices: []) == "")
    #expect(binding.resolveSelection("", devices: [bindingDevice("other"), bindingDevice("phone", ready: false)]) == "phone")
    #expect(binding.resolveSelection("other", devices: [bindingDevice("other")]) == "other")
}

@Test func legacyInstallationsRestoreManualSelectionsPerMacWithoutGuessingIdentity() {
    let storage = BindingPreferences()
    defer { storage.close() }
    storage.preferences.set("phone", forKey: "deviceID.mac-one")
    let binding = StoreDeviceBinding(info: [:], preferences: storage.preferences)
    #expect(binding.deviceID == nil)
    #expect(binding.preferredSelection(for: "mac-one") == "phone")
    #expect(binding.preferredSelection(for: "mac-two") == "")
    #expect(binding.resolveSelection("phone", devices: [bindingDevice("phone")], preferLocalDevice: true) == "phone")
    #expect(binding.resolveSelection("", devices: [bindingDevice("phone")]) == "")
    #expect(binding.resolveSelection("removed", devices: [bindingDevice("phone")]) == "")
    #expect(binding.resolveSelection("phone", devices: []) == "")
    #expect(binding.resolveSelection(binding.preferredSelection(for: "mac-one"), devices: [bindingDevice("phone")]) == "phone")
    binding.saveSelection("ipad", for: "mac-two")
    let reopened = StoreDeviceBinding(info: [:], preferences: storage.preferences)
    #expect(reopened.preferredSelection(for: "mac-one") == "phone")
    #expect(reopened.preferredSelection(for: "mac-two") == "ipad")
}

@Test func blankAndMalformedInstallationMetadataUseTheSavedBindingOrManualFallback() {
    let storage = BindingPreferences()
    defer { storage.close() }
    for invalid: Any in ["", " \n ", 42, ["phone"]] {
        #expect(StoreDeviceBinding(info: ["AutoSignStoreDeviceUDID": invalid], preferences: storage.preferences).deviceID == nil)
    }
    let installed = StoreDeviceBinding(info: ["AutoSignStoreDeviceUDID": " phone\n"], preferences: storage.preferences)
    #expect(installed.deviceID == "phone")
    #expect(StoreDeviceBinding(info: ["AutoSignStoreDeviceUDID": ""], preferences: storage.preferences).deviceID == "phone")
}
