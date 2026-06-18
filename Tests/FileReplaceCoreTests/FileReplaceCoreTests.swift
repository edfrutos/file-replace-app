import Foundation
import Testing
@testable import FileReplaceCore

@Suite("AppVersion")
struct AppVersionTests {
    @Test("parses release tags and normalizes missing components")
    func parsesVersions() throws {
        #expect(try #require(AppVersion("v1.2.3")).description == "1.2.3")
        #expect(try #require(AppVersion("2.1")).description == "2.1.0")
        #expect(AppVersion("release-1.0") == nil)
    }

    @Test("compares stable and prerelease versions")
    func comparesVersions() throws {
        let current = try #require(AppVersion("1.0.0"))
        let newer = try #require(AppVersion("1.1.0"))
        let prerelease = try #require(AppVersion("1.1.0-beta.2"))

        #expect(current < newer)
        #expect(prerelease < newer)
        #expect(try #require(AppVersion("1.1.0-beta.1")) < prerelease)
    }
}

@Suite("FileReplaceService")
struct FileReplaceServiceTests {
    @Test("search finds matching files recursively")
    func searchFindsMatchesRecursively() throws {
        let fixture = try TemporaryFixture()
        try fixture.write("root/app.py", contents: "hello root")
        try fixture.write("nested/app.py", contents: "hello nested hello")
        try fixture.write("nested/other.py", contents: "hello ignored")

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
            filename: "app.py",
            searchText: "hello",
            recursive: true,
            maxDepth: 3
        )

        #expect(report.filesScanned == 2)
        #expect(report.hits.count == 2)
        #expect(report.hits.map(\.count).sorted() == [1, 2])
    }

    @Test("replace updates only selected file")
    func replaceUpdatesSelectedFile() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.write("app.py", contents: "alpha beta alpha")

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
            filename: "app.py",
            searchText: "alpha",
            recursive: false,
            maxDepth: 1
        )

        let result = try service.replace(
            in: try #require(report.hits.first),
            searchText: "alpha",
            replacementText: "omega"
        )

        #expect(result.replacements == 2)
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "omega beta omega")
        #expect(try String(contentsOf: result.backupURL, encoding: .utf8) == "alpha beta alpha")
    }

    @Test("search rejects binary files")
    func searchRejectsBinaryFiles() throws {
        let fixture = try TemporaryFixture()
        try fixture.writeData("data.bin", data: Data([0x00, 0x01, 0x02, 0x03]))

        let service = FileReplaceService()

        #expect(throws: FileReplaceError.unsupportedFileType(fixture.url.appendingPathComponent("data.bin").path)) {
            _ = try service.search(
                directoryURL: fixture.url,
                filename: "data.bin",
                searchText: "x",
                recursive: false,
                maxDepth: 1
            )
        }
    }

    @Test("replace creates unique backup files")
    func replaceCreatesUniqueBackupFiles() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.write("app.py", contents: "alpha")

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
            filename: "app.py",
            searchText: "alpha",
            recursive: false,
            maxDepth: 1
        )
        let hit = try #require(report.hits.first)

        let first = try service.replace(in: hit, searchText: "alpha", replacementText: "beta")
        let second = try service.replace(in: hit, searchText: "beta", replacementText: "gamma")

        #expect(first.backupURL != second.backupURL)
        #expect(try String(contentsOf: first.backupURL, encoding: .utf8) == "alpha")
        #expect(try String(contentsOf: second.backupURL, encoding: .utf8) == "beta")
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "gamma")
    }
}

private struct TemporaryFixture {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReplacerTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    @discardableResult
    func write(_ relativePath: String, contents: String) throws -> URL {
        let fileURL = url.appendingPathComponent(relativePath)
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    @discardableResult
    func writeData(_ relativePath: String, data: Data) throws -> URL {
        let fileURL = url.appendingPathComponent(relativePath)
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
