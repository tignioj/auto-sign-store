import Foundation

/// Installation metadata identifies the local device; a picker selection may
/// temporarily target another device without changing that identity.
struct StoreDeviceBinding {
    static let infoKey = "AutoSignStoreDeviceUDID"
    private static let savedBindingKey = "boundDeviceUDID"

    let deviceID: String?
    private let preferences: UserDefaults

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:], preferences: UserDefaults = .standard) {
        self.preferences = preferences
        let installed = Self.nonempty(info[Self.infoKey] as? String)
        // Keep the binding through an update signed by an older Mac that does
        // not yet write installation metadata. A new installation always wins.
        deviceID = installed ?? Self.nonempty(preferences.string(forKey: Self.savedBindingKey))
        if let installed { preferences.set(installed, forKey: Self.savedBindingKey) }
    }

    func preferredSelection(for server: String) -> String {
        deviceID ?? preferences.string(forKey: "deviceID.\(server)") ?? ""
    }

    func saveSelection(_ selection: String, for server: String) {
        preferences.set(selection, forKey: "deviceID.\(server)")
    }

    func resolveSelection(_ selection: String, devices: [StoreDevice], preferLocalDevice: Bool = false) -> String {
        let available = Set(devices.map(\.id))
        if !preferLocalDevice, !selection.isEmpty, available.contains(selection) { return selection }
        if let deviceID {
            // An absent local device must never select a different phone just
            // because it is the only connected or ready device.
            return available.contains(deviceID) ? deviceID : ""
        }
        return available.contains(selection) ? selection : ""
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
