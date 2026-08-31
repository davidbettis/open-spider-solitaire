import Foundation

/// Reads and writes one file, replacing it **atomically** (spec §6.4): the
/// write lands in a temp file and is swapped in, so a crash mid-write leaves
/// the previous good save intact rather than a truncated one.
///
/// Stateless and `Sendable`, so it is safe to use from the persistence actor
/// and, for the rare synchronous paths, directly.
struct JSONFileStore: Sendable {
    let url: URL

    /// `Application Support/OpenSpiderSolitaire/<name>`, creating the
    /// directory on first use (spec §10).
    static func inApplicationSupport(_ name: String) -> JSONFileStore {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        let directory = base.appending(path: "OpenSpiderSolitaire", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return JSONFileStore(url: directory.appending(path: name))
    }

    /// `nil` when absent or unreadable — callers treat both as "no save".
    func read() -> Data? {
        try? Data(contentsOf: url)
    }

    @discardableResult
    func write(_ data: Data) -> Bool {
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            // A failed save must never take the app down (spec §8).
            return false
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: url)
    }

    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
}
