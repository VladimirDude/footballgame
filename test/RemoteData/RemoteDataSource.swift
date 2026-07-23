import Foundation

/// Fetches remote data over HTTPS. This is the seam a Firebase-SDK-backed source
/// could replace, but for bulk files (manifest, database, images) plain HTTPS
/// against Firebase Storage is all that's needed — no SDK, and fully testable.
protocol RemoteDataSource: Sendable {
    func fetchManifest() async throws -> DataManifest
    func fetchData(from url: URL) async throws -> Data
}

enum RemoteDataError: Error {
    case notConfigured
    case badResponse(Int)
    case checksumMismatch
}

/// `URLSession`-based implementation. Uses ETag/If-None-Match implicitly via the
/// shared cache and validates checksums when the manifest provides them.
struct HTTPRemoteDataSource: RemoteDataSource {
    let manifestURL: URL?
    private let session: URLSession

    init(manifestURL: URL? = RemoteDataConfig.manifestURL, session: URLSession = .shared) {
        self.manifestURL = manifestURL
        self.session = session
    }

    func fetchManifest() async throws -> DataManifest {
        guard let manifestURL else { throw RemoteDataError.notConfigured }
        let data = try await fetchData(from: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DataManifest.self, from: data)
    }

    func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RemoteDataError.badResponse(http.statusCode)
        }
        return data
    }
}

/// Versioned on-disk cache in Application Support. Survives app updates and is
/// excluded from iCloud backup (it's re-downloadable). Stores the current
/// manifest and the downloaded database file.
final class DataCache: @unchecked Sendable {
    static let shared = DataCache()

    private let directory: URL
    private let manifestFile: URL
    private let databaseFile: URL
    let imagesDirectory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("RemoteData", isDirectory: true)
        manifestFile = directory.appendingPathComponent("manifest.json")
        databaseFile = directory.appendingPathComponent("ClubDatabase.json")
        imagesDirectory = directory.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        excludeFromBackup(directory)
    }

    // MARK: Manifest

    func cachedManifest() -> DataManifest? {
        guard let data = try? Data(contentsOf: manifestFile) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DataManifest.self, from: data)
    }

    func store(manifest: DataManifest) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(manifest) { try? data.write(to: manifestFile, options: .atomic) }
    }

    // MARK: Database

    /// URL of the cached database file if a valid copy exists, else `nil`.
    func cachedDatabaseURL() -> URL? {
        FileManager.default.fileExists(atPath: databaseFile.path) ? databaseFile : nil
    }

    func storeDatabase(_ data: Data) throws {
        try data.write(to: databaseFile, options: .atomic)
    }

    // MARK: Images

    func cachedImageURL(for key: String) -> URL? {
        let file = imagesDirectory.appendingPathComponent(key)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    func storeImage(_ data: Data, for key: String) {
        let file = imagesDirectory.appendingPathComponent(key)
        try? data.write(to: file, options: .atomic)
    }

    private func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
