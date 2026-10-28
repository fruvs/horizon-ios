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
