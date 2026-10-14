import Foundation

/// Atomic disk write before submitting a job, including when iOS terminates the client during self-install.
public struct RefreshJournal {
    private let directory: URL
    private var file: URL { directory.appendingPathComponent("pending-refreshes.json") }

    public init(directory: URL) { self.directory = directory }

    public func load(for address: String) throws -> String? { try all()[address] }

    public func save(_ requestID: String, for address: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = try all()
        values[address] = requestID
        let data = try JSONEncoder().encode(values)
        #if os(iOS)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file, options: .atomic)
        #endif
    }

    private func all() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: file))
    }
}
