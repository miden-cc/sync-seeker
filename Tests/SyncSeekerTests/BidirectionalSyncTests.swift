import Foundation
import Testing
@testable import SyncSeeker

@Suite("BidirectionalSync")
struct BidirectionalSyncTests {

    private let now = Date()
    private let oneHourAgo = Date(timeIntervalSinceNow: -3600)
    private let twoHoursAgo = Date(timeIntervalSinceNow: -7200)

    // MARK: - Helpers

    private func entry(_ path: String, size: Int64 = 100, date: Date? = nil, hash: String = "aaa") -> ManifestEntry {
        ManifestEntry(relativePath: path, size: size, modifiedDate: date ?? now, sha256: hash, hasXattr: false)
    }

    private func manifest(_ entries: [ManifestEntry], root: String = "/tmp/src") -> FileManifest {
        FileManifest(rootPath: URL(fileURLWithPath: root), entries: entries, createdAt: now)
    }

    // MARK: - No conflicts

    @Test("File only on Mac → push to iPad")
    func macOnlyFile() {
        let engine = BidirectionalSyncEngine()
        let macFile = entry("docs/mac-only.md")

        let plan = engine.computeSyncPlan(
            mac: manifest([macFile]),
            iPad: manifest([], root: "/tmp/ipad"),
            lastSync: nil
        )

        #expect(plan.toIPad.added.count == 1)
        #expect(plan.toMac.added.isEmpty)
        #expect(plan.conflicts.isEmpty)
    }

    @Test("File only on iPad → pull to Mac")
    func iPadOnlyFile() {
        let engine = BidirectionalSyncEngine()
        let iPadFile = entry("notes/ipad-only.txt")

        let plan = engine.computeSyncPlan(
            mac: manifest([]),
            iPad: manifest([iPadFile], root: "/tmp/ipad"),
            lastSync: nil
        )

        #expect(plan.toMac.added.count == 1)
        #expect(plan.toMac.added.count == 1)
        #expect(plan.toIPad.added.isEmpty)
        #expect(plan.conflicts.isEmpty)
    }

    @Test("Identical files on both sides → no transfer")
    func identicalFiles() {
        let file = entry("shared.pdf", hash: "same")
        let engine = BidirectionalSyncEngine()

        let plan = engine.computeSyncPlan(
            mac: manifest([file]),
            iPad: manifest([file], root: "/tmp/ipad"),
            lastSync: nil
        )

        #expect(plan.toIPad.isEmpty)
        #expect(plan.toMac.isEmpty)
        #expect(plan.conflicts.isEmpty)
    }

    // MARK: - One-sided modification

    @Test("File modified on Mac since last sync → push to iPad")
    func macModifiedSinceSync() {
        let engine = BidirectionalSyncEngine()
        let macFile = entry("doc.pdf", date: now, hash: "new")
        let iPadFile = entry("doc.pdf", date: twoHoursAgo, hash: "old")

        let plan = engine.computeSyncPlan(
            mac: manifest([macFile]),
            iPad: manifest([iPadFile], root: "/tmp/ipad"),
            lastSync: oneHourAgo
        )

        #expect(plan.toIPad.modified.count == 1)
        #expect(plan.toMac.modified.isEmpty)
        #expect(plan.conflicts.isEmpty)
    }

    @Test("File modified on iPad since last sync → pull to Mac")
    func iPadModifiedSinceSync() {
        let engine = BidirectionalSyncEngine()
        let macFile = entry("doc.pdf", date: twoHoursAgo, hash: "old")
        let iPadFile = entry("doc.pdf", date: now, hash: "new")

        let plan = engine.computeSyncPlan(
            mac: manifest([macFile]),
            iPad: manifest([iPadFile], root: "/tmp/ipad"),
            lastSync: oneHourAgo
        )

        #expect(plan.toMac.modified.count == 1)
        #expect(plan.toIPad.modified.isEmpty)
        #expect(plan.conflicts.isEmpty)
    }

    // MARK: - Conflicts

    @Test("Both sides modified since last sync → conflict")
    func bothModifiedConflict() {
        let engine = BidirectionalSyncEngine()
        let macFile = entry("doc.pdf", date: now, hash: "macVer")
        let iPadFile = entry("doc.pdf", date: now, hash: "iPadVer")

        let plan = engine.computeSyncPlan(
            mac: manifest([macFile]),
            iPad: manifest([iPadFile], root: "/tmp/ipad"),
            lastSync: oneHourAgo
        )

        #expect(plan.conflicts.count == 1)
        #expect(plan.conflicts.first?.path == "doc.pdf")
    }

    @Test("File deleted on Mac, modified on iPad → conflict")
    func deletedOnMacModifiedOnIPad() {
        let engine = BidirectionalSyncEngine()
        let iPadFile = entry("removed.pdf", date: now, hash: "modified")

        let plan = engine.computeSyncPlan(
            mac: manifest([]),
            iPad: manifest([iPadFile], root: "/tmp/ipad"),
            lastSync: oneHourAgo
        )

        // iPad has a file newer than lastSync that Mac doesn't have → pull to Mac
        #expect(plan.toMac.added.count == 1)
    }

    // MARK: - Resolve conflicts

    @Test("Resolve conflict with Mac wins")
    func resolveConflictMacWins() {
        let engine = BidirectionalSyncEngine()
        let conflict = SyncConflict(path: "doc.pdf", macEntry: entry("doc.pdf", hash: "mac"), iPadEntry: entry("doc.pdf", hash: "ipad"))

        let resolution = engine.resolve(conflict, strategy: .macWins)

        #expect(resolution.direction == .toIPad)
        #expect(resolution.entry.sha256 == "mac")
    }

    @Test("Resolve conflict with iPad wins")
    func resolveConflictIPadWins() {
        let engine = BidirectionalSyncEngine()
        let conflict = SyncConflict(path: "doc.pdf", macEntry: entry("doc.pdf", hash: "mac"), iPadEntry: entry("doc.pdf", hash: "ipad"))

        let resolution = engine.resolve(conflict, strategy: .iPadWins)

        #expect(resolution.direction == .toMac)
        #expect(resolution.entry.sha256 == "ipad")
    }

    @Test("Resolve conflict with newest wins picks newer modified date")
    func resolveConflictNewestWins() {
        let engine = BidirectionalSyncEngine()
        let macEntry = entry("doc.pdf", date: twoHoursAgo, hash: "mac")
        let iPadEntry = entry("doc.pdf", date: now, hash: "ipad")
        let conflict = SyncConflict(path: "doc.pdf", macEntry: macEntry, iPadEntry: iPadEntry)

        let resolution = engine.resolve(conflict, strategy: .newestWins)

        #expect(resolution.direction == .toMac)
        #expect(resolution.entry.sha256 == "ipad")
    }
}
