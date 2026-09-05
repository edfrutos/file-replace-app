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
    @Test("search without a name pattern scans every readable file in scope")
    func searchScansAllFiles() throws {
        let fixture = try TemporaryFixture()
        try fixture.write("notes.txt", contents: "hello here")
        try fixture.write("src/main.swift", contents: "print(\"hello\")")
        try fixture.write("src/readme.md", contents: "nothing to see")
        try fixture.writeData("assets/logo.bin", data: Data([0x00, 0x01, 0x02]))

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
            namePattern: "",
            searchText: "hello",
            recursive: true,
            maxDepth: 5
        )

        #expect(report.hits.count == 2)
        #expect(report.hits.map(\.relativePath).sorted() == ["notes.txt", "src/main.swift"])
        #expect(report.filesWithoutMatch.contains { $0.hasSuffix("src/readme.md") })
        #expect(report.skippedFiles.contains { $0.hasSuffix("assets/logo.bin") })
    }

    @Test("search honors a glob name filter")
    func searchHonorsGlobFilter() throws {
        let fixture = try TemporaryFixture()
        try fixture.write("app.py", contents: "alpha")
        try fixture.write("lib/util.py", contents: "alpha alpha")
        try fixture.write("lib/notes.txt", contents: "alpha")

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
            namePattern: "*.py",
            searchText: "alpha",
            recursive: true,
            maxDepth: 5
        )

        #expect(report.hits.count == 2)
        #expect(report.hits.allSatisfy { $0.relativePath.hasSuffix(".py") })
    }

    @Test("search skips files above the size limit")
    func searchSkipsLargeFiles() throws {
        let fixture = try TemporaryFixture()
        try fixture.write("small.txt", contents: "needle")
        try fixture.write("big.txt", contents: String(repeating: "needle ", count: 2000))

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
            namePattern: "",
            searchText: "needle",
            recursive: false,
            maxDepth: 1,
            maxFileSizeBytes: 64
        )

        #expect(report.hits.map(\.relativePath) == ["small.txt"])
        #expect(report.skippedFiles.contains { $0.hasSuffix("big.txt") })
    }

    @Test("search throws when the name filter matches nothing")
    func searchThrowsWhenFilterMatchesNothing() throws {
        let fixture = try TemporaryFixture()
        try fixture.write("app.py", contents: "alpha")

        let service = FileReplaceService()
        #expect(throws: FileReplaceError.self) {
            _ = try service.search(
                directoryURL: fixture.url,
                namePattern: "*.rs",
                searchText: "alpha",
                recursive: true,
                maxDepth: 5
            )
        }
    }

    @Test("replace updates a matched file and keeps a backup")
    func replaceUpdatesFile() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.write("app.py", contents: "alpha beta alpha")

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
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

    @Test("replace creates unique backup files")
    func replaceCreatesUniqueBackupFiles() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.write("app.py", contents: "alpha")

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
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

    @Test("replace refuses read-only files without creating a backup")
    func replaceRefusesReadOnlyFiles() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.write("locked.txt", contents: "alpha")

        let service = FileReplaceService()
        let report = try service.search(
            directoryURL: fixture.url,
            searchText: "alpha",
            recursive: false,
            maxDepth: 1
        )
        let hit = try #require(report.hits.first)

        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: fileURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fileURL.path) }

        do {
            _ = try service.replace(in: hit, searchText: "alpha", replacementText: "omega")
            Issue.record("replace debería haber lanzado un error para un archivo de solo lectura")
        } catch let error as FileReplaceError {
            guard case .notWritable = error else {
                Issue.record("Se esperaba .notWritable, se obtuvo \(error)")
                return
            }
        }

        let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("locked.txt.replacer-backup")
        #expect(FileManager.default.fileExists(atPath: backupURL.path) == false)
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "alpha")
    }

    @Test("readFullContent returns the entire file, not just the match neighborhood")
    func readFullContentReturnsWholeFile() throws {
        let fixture = try TemporaryFixture()
        let contents = "alpha\n" + String(repeating: "relleno\n", count: 50) + "alpha otra vez\n"
        let fileURL = try fixture.write("app.py", contents: contents)

        let service = FileReplaceService()
        let read = try service.readFullContent(at: fileURL)

        #expect(read == contents)
    }

    @Test("readFullContent throws readFailed when the file no longer exists")
    func readFullContentThrowsWhenFileMissing() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.write("app.py", contents: "alpha")
        try FileManager.default.removeItem(at: fileURL)

        let service = FileReplaceService()
        #expect(throws: FileReplaceError.self) {
            _ = try service.readFullContent(at: fileURL)
        }
    }

    @Test("readFullContent throws unsupportedFileType for binary content")
    func readFullContentThrowsForBinaryContent() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.writeData("assets/logo.bin", data: Data([0x00, 0x01, 0x02]))

        let service = FileReplaceService()
        do {
            _ = try service.readFullContent(at: fileURL)
            Issue.record("readFullContent debería haber lanzado un error para contenido binario")
        } catch let error as FileReplaceError {
            guard case .unsupportedFileType = error else {
                Issue.record("Se esperaba .unsupportedFileType, se obtuvo \(error)")
                return
            }
        }
    }

    @Test("readFullContent throws fileTooLarge above the given byte limit")
    func readFullContentThrowsWhenTooLarge() throws {
        let fixture = try TemporaryFixture()
        let fileURL = try fixture.write("big.txt", contents: String(repeating: "needle ", count: 2000))

        let service = FileReplaceService()
        do {
            _ = try service.readFullContent(at: fileURL, maxBytes: 64)
            Issue.record("readFullContent debería haber lanzado un error por tamaño")
        } catch let error as FileReplaceError {
            guard case .fileTooLarge = error else {
                Issue.record("Se esperaba .fileTooLarge, se obtuvo \(error)")
                return
            }
        }
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
