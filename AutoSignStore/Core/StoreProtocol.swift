import Foundation

public struct StoreDevice: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let model: String
    public let isConnected: Bool
    public let isReady: Bool
}

public struct StoreApp: Codable, Identifiable, Sendable {
    public let id: String
    public let deviceUDID: String
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let expiration: Date
    public let refreshedAt: Date
    public let isStore: Bool

    public func remainingDays(at date: Date = Date()) -> Int {
        max(0, Int(ceil(expiration.timeIntervalSince(date) / 86_400)))
    }
}

public enum RefreshState: String, Codable, Sendable {
    case queued, running, completed, failed
    public var isTerminal: Bool { self == .completed || self == .failed }
}

public struct RefreshItem: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var state: RefreshState
    public var message: String
    public var expiration: Date?
}

public struct RefreshJob: Codable, Identifiable, Sendable {
    public var id: String
    public var requestID: String
    public var deviceUDID: String
    public var state: RefreshState
    public var items: [RefreshItem]
    public var createdAt: Date
    public var updatedAt: Date
    public var installRequest: StoreInstallRequest? = nil
}

public struct StoreSnapshot: Codable, Sendable {
    public let protocolVersion: Int
    public let serverName: String
    public let devices: [StoreDevice]
    public let apps: [StoreApp]
    public let recentJobs: [RefreshJob]
    public var capabilities: [String]? = nil
}

public struct RefreshRequest: Codable, Sendable {
    public let requestID: String
    public let deviceUDID: String
    public let appIDs: [String]

    public init(requestID: String, deviceUDID: String, appIDs: [String]) {
        self.requestID = requestID
        self.deviceUDID = deviceUDID
        self.appIDs = appIDs
    }
}

public struct StoreSourceRequest: Codable, Sendable {
    public let url: String
}

public struct StoreInstallRequest: Codable, Equatable, Sendable {
    public let requestID: String
    public let deviceUDID: String
    public let sourceURL: String
    public let bundleIdentifier: String

    public init(requestID: String, deviceUDID: String, sourceURL: String, bundleIdentifier: String) {
        self.requestID = requestID
        self.deviceUDID = deviceUDID
        self.sourceURL = sourceURL
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct StoreAPIError: Codable, Sendable {
    public let message: String
}

public enum StoreJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
