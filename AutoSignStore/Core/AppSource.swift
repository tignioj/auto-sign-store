import Foundation

struct AppSourceCatalog: Codable, Sendable {
    let name: String
    let apps: [SourceApp]
}

struct SourceApp: Codable, Identifiable, Sendable {
    let name: String
    let bundleIdentifier: String
    let developerName: String?
    let localizedDescription: String?
    let iconURL: URL?
    let versions: [SourceAppVersion]

    var id: String { bundleIdentifier }
    // AltStore defines the first entry as the latest release, regardless of its date/version number.
    var latestVersion: SourceAppVersion? { versions.first }

    private enum CodingKeys: String, CodingKey {
        case name, bundleIdentifier, developerName, localizedDescription, iconURL, versions
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        bundleIdentifier = try values.decode(String.self, forKey: .bundleIdentifier)
        developerName = try values.decodeIfPresent(String.self, forKey: .developerName)
        localizedDescription = try values.decodeIfPresent(String.self, forKey: .localizedDescription)
        iconURL = try values.decodeIfPresent(URL.self, forKey: .iconURL)
        if let releases = try values.decodeIfPresent([SourceAppVersion].self, forKey: .versions) {
            versions = releases
        } else {
            let legacy = try LegacyVersion(from: decoder)
            versions = [SourceAppVersion(
                version: legacy.version, buildVersion: legacy.buildVersion,
                date: legacy.versionDate, localizedDescription: legacy.versionDescription,
                downloadURL: legacy.downloadURL, size: legacy.size,
                minOSVersion: legacy.minOSVersion, maxOSVersion: legacy.maxOSVersion
            )]
        }
    }

    private struct LegacyVersion: Decodable {
        let version: String
        let buildVersion: String?
        let versionDate: String?
        let versionDescription: String?
        let downloadURL: URL
        let size: Int64?
        let minOSVersion: String?
        let maxOSVersion: String?
    }
}

struct SourceAppVersion: Codable, Sendable {
    let version: String
    let buildVersion: String?
    let date: String?
    let localizedDescription: String?
    let downloadURL: URL
    let size: Int64?
    let minOSVersion: String?
    let maxOSVersion: String?

    var displayVersion: String {
        buildVersion.map { "\(version) (\($0))" } ?? version
    }
}

struct SavedAppSource: Codable, Identifiable, Sendable {
    let url: URL
    var catalog: AppSourceCatalog
    var updatedAt: Date
    var id: String { url.absoluteString }
}

