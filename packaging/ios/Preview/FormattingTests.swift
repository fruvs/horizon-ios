import XCTest
@testable import LauncherPreview

final class FormattingTests: XCTestCase {
    func testColorsDecorationsAndReset() {
        let r = MinecraftFormatting.runs("§aGreen §lBold§oItalic§nUnder§mStrike§rPlain")
        XCTAssertEqual(r[0].style.color, 0x55FF55)
        XCTAssertTrue(r[1].style.bold)
        XCTAssertTrue(r[2].style.italic)
        XCTAssertTrue(r[3].style.underline)
        XCTAssertTrue(r[4].style.strike)
        XCTAssertEqual(r.last?.style, MinecraftFormatting.Style())
        XCTAssertEqual(MinecraftFormatting.plain("§6§lHYPIXEL§r\n§7SkyBlock"), "HYPIXEL\nSkyBlock")
    }
    func testColorResetsDecorationAndRGBIsOneColor() {
        let r = MinecraftFormatting.runs("§lBold§cRed§x§1§2§3§4§5§6Hex")
        XCTAssertFalse(r[1].style.bold)
        XCTAssertEqual(r[1].style.color, 0xFF5555)
        XCTAssertEqual(r[2].style.color, 0x123456)
    }
    func testUnicodeUnknownSequencesAndTrailingSectionSignArePreserved() {
        XCTAssertEqual(MinecraftFormatting.plain("§b世界 🧱 §z literal §"), "世界 🧱 §z literal §")
        XCTAssertTrue(MinecraftFormatting.runs("§kSecret")[0].style.obfuscated)
        XCTAssertEqual(MinecraftFormatting.plain("§LUPPER"), "UPPER")
    }
    func testWorldCreationJSONCarriesAllFields() throws {
        var settings = WorldCreationSettings()
        settings.name = "A world with spaces"; settings.seed = "hello world"; settings.mode = "hardcore"
        settings.flat = true; settings.structures = false
        let data = try JSONEncoder().encode(settings)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, settings.name)
        XCTAssertEqual(json["seed"] as? String, "hello world")
        XCTAssertEqual(json["mode"] as? String, "hardcore")
        XCTAssertEqual(json["flat"] as? Bool, true)
        XCTAssertEqual(json["structures"] as? Bool, false)
        XCTAssertEqual(json["bonus_chest"] as? Bool, false)
    }
}

@MainActor
final class SettingsModelTests: XCTestCase {
    func testEmptyAndFailedResponsesAreVisibleFailures() async {
        let empty = GameOptions(request: { _ in ["ok": true] })
        await empty.load()
        XCTAssertNotNil(empty.issue)
        XCTAssertTrue(empty.options.isEmpty)
        XCTAssertFalse(empty.loading)
        let failed = GameOptions(request: { _ in ["error": "Disconnected"] })
        await failed.load()
        XCTAssertEqual(failed.issue, "Disconnected")
    }
    func testPartialOptionsRemainUsableAndIdentifyMissingControls() async {
        let model = GameOptions(request: { _ in ["options": ["autoJump": ["type": "bool", "value": false]]] })
        await model.load()
        XCTAssertNil(model.issue)
        XCTAssertNotNil(model.options["autoJump"])
        XCTAssertTrue(model.unavailable.contains("Graphics"))
    }
    func testToggleUpdatesOnlyAfterAcknowledgement() async {
        var value = false
        let model = GameOptions(request: { line in
            if line.hasPrefix("options-set autoJump ") {
                value = line.hasSuffix("true")
                return ["option": ["type": "bool", "value": value]]
            }
            return ["options": ["autoJump": ["type": "bool", "value": value]]]
        })
        await model.load()
        let issue = await model.set("autoJump", "true")
        XCTAssertNil(issue)
        XCTAssertTrue(model.options["autoJump"]?.flag == true)
        await model.load()
        XCTAssertTrue(model.options["autoJump"]?.flag == true)
        let noAck = GameOptions(request: { _ in ["ok": true] })
        let noAckIssue = await noAck.set("autoJump", "true")
        XCTAssertNotNil(noAckIssue)
    }
    func testPreviewFixtureCoversEveryLauncherSetting() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "EngineOptions", withExtension: "json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let options = try XCTUnwrap(object["options"] as? [String: Any])
        XCTAssertEqual(Set(options.keys), Set(GameOptions.groups.flatMap { $0.rows.map(\.key) }))
    }
}

@MainActor
final class LauncherAsyncTests: XCTestCase {
    private func hits(_ id: String) -> [String: Any] { ["hits": [["project_id": id, "title": id]]] }

    func testOldPackSearchCannotOverwriteNewResults() async {
        var pending: [String: CheckedContinuation<Any?, Never>] = [:]
        let store = PackStore(fetch: { url in
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "query" }?.value ?? ""
            return await withCheckedContinuation { pending[query] = $0 }
        })
        let old = Task { await store.search(.resource, query: "old") }
        while pending["old"] == nil { await Task.yield() }
        let new = Task { await store.search(.shader, query: "new") }
        while pending["new"] == nil { await Task.yield() }
        pending.removeValue(forKey: "new")?.resume(returning: hits("new"))
        await new.value
        pending.removeValue(forKey: "old")?.resume(returning: hits("old"))
        await old.value
        XCTAssertEqual(store.results.map(\.id), ["new"])
        XCTAssertFalse(store.searching)
        XCTAssertNil(store.failed)
    }

    func testOldPackFailureCannotEndNewSearchOrSetError() async {
        var pending: [String: CheckedContinuation<Any?, Never>] = [:]
        let store = PackStore(fetch: { url in
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "query" }?.value ?? ""
            return await withCheckedContinuation { pending[query] = $0 }
        })
        let old = Task { await store.search(.resource, query: "old") }
        while pending["old"] == nil { await Task.yield() }
        let new = Task { await store.search(.shader, query: "new") }
        while pending["new"] == nil { await Task.yield() }
        pending.removeValue(forKey: "old")?.resume(returning: nil)
        await old.value
        XCTAssertTrue(store.searching)
        XCTAssertNil(store.failed)
        pending.removeValue(forKey: "new")?.resume(returning: hits("new"))
        await new.value
        XCTAssertEqual(store.results.map(\.id), ["new"])
    }

    func testDuplicatePackInstallDoesNotStartAnotherRequest() async {
        var resume: CheckedContinuation<Any?, Never>?
        let store = PackStore(fetch: { _ in await withCheckedContinuation { resume = $0 } })
        let project = ModrinthProject(id: "test", title: "Test", summary: "", author: "", downloads: 0, icon: nil, gameVersions: [])
        let first = Task { await store.install(project, kind: .resource, version: "26.3") }
        while resume == nil { await Task.yield() }
        if case .success = await store.install(project, kind: .resource, version: "26.3") { XCTFail("Duplicate install succeeded") }
        XCTAssertNotNil(store.downloading[project.id])
        resume?.resume(returning: [])
        _ = await first.value
        XCTAssertNil(store.downloading[project.id])
    }

    func testStaleGameFileCompletionDoesNotImportOrReplaceSharedArchive() async throws {
        let shared = GameFolder.documents.appendingPathComponent("horizon-download.zip")
        let previous = try? Data(contentsOf: shared)
        let sentinel = Data("keep-current-download".utf8)
        try sentinel.write(to: shared)
        defer { if let previous { try? previous.write(to: shared) } else { try? FileManager.default.removeItem(at: shared) } }
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("stale-download".utf8).write(to: source)
        let imported = expectation(description: "Stale completion must not import")
        imported.isInverted = true
        let model = GameFilesDownload(importArchive: { _ in imported.fulfill(); return ["ok": true] })
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.downloadTask(with: URL(string: "https://example.invalid/test.zip")!)
        model.urlSession(session, downloadTask: task, didFinishDownloadingTo: source)
        await fulfillment(of: [imported], timeout: 0.15)
        XCTAssertEqual(model.state, .idle)
        XCTAssertEqual(try Data(contentsOf: shared), sentinel)
    }
}
