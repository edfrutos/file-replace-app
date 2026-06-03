import Foundation
import Testing
@testable import FileReplaceCore

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

        let count = try service.replace(
            in: try #require(report.hits.first),
            searchText: "alpha",
            replacementText: "omega"
        )

        #expect(count == 2)
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "omega beta omega")
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
}
