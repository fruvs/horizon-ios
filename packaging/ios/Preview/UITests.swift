import XCTest

final class LauncherLayoutTests: XCTestCase {
    private func launch(signedIn: Bool, optionsResponse: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let root = NSTemporaryDirectory() + "horizon-native-" + UUID().uuidString
        app.launchEnvironment = ["PREVIEW_SIGNED_IN": signedIn ? "1" : "0",
            "HORIZON_HOME": root + "/game", "HORIZON_LAUNCHER_HOME": root + "/launcher",
            "XDG_DATA_HOME": root + "/data", "XDG_CONFIG_HOME": root + "/config",
            "HORIZON_LAUNCHER_TRASH": root + "/trash", "HORIZON_LAUNCHER_CLIPBOARD": root + "/clipboard",
            "HORIZON_LAUNCHER_DESKTOP": root + "/desktop", "HORIZON_LAUNCHER_NO_SELF_UPDATE": "1", "HORIZON_NO_AUDIO": "1"]
        if let optionsResponse { app.launchEnvironment["PREVIEW_OPTIONS_RESPONSE"] = optionsResponse }
        app.launch()
        XCTAssertTrue(app.buttons["launcher-play-button"].waitForExistence(timeout: 15))
        return app
    }
    func testPhoneLayoutAndSignedInIdentity() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(signedIn: true)
        XCTAssertTrue(app.staticTexts["Meadow Valley"].waitForExistence(timeout: 10))
        let play = app.buttons["launcher-play-button"]
        XCTAssertTrue(play.isHittable)
        XCTAssertLessThanOrEqual(play.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThanOrEqual(play.frame.minX, 0)
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        app.buttons["launcher-account-button"].tap()
        XCTAssertTrue(app.staticTexts["Microsoft account"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Change Offline Name"].exists)
        app.buttons["Done"].tap()
        if app.tabBars.buttons["Worlds"].exists {
            app.tabBars.buttons["Worlds"].tap()
            XCTAssertTrue(app.buttons["new-world-button"].waitForExistence(timeout: 5))
            app.tabBars.buttons["Play"].tap()
        }
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Native-launcher"; shot.lifetime = .keepAlways; add(shot)
    }
    func testOfflineNameEditing() {
        let app = launch(signedIn: false)
        app.buttons["launcher-account-button"].tap()
        let edit = app.buttons["Change Offline Name"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        let alert = app.alerts["Offline player name"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields.firstMatch.tap()
        alert.buttons["Cancel"].tap()
    }
    func testWorldLibraryAndHardcoreOptions() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(signedIn: true)
        if app.tabBars.buttons["Worlds"].exists { app.tabBars.buttons["Worlds"].tap() }
        else { app.buttons["All Worlds"].tap() }
        let newWorld = app.buttons["new-world-button"]
        XCTAssertTrue(newWorld.waitForExistence(timeout: 5)); newWorld.tap()
        let mode = app.descendants(matching: .any).matching(identifier: "creation-mode").firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 5)); mode.tap()
        app.buttons["Hardcore"].tap()
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "creation-difficulty").firstMatch.isEnabled)
        XCTAssertFalse(app.switches["creation-cheats"].isEnabled)
        XCTAssertTrue(app.staticTexts["World generation"].exists)
        XCTAssertTrue(app.buttons["creation-confirm"].isHittable)
        app.buttons["Cancel"].tap()
    }

    func testSettingsControlsLoadAndTogglePersistsAcrossNavigation() {
        let app = launch(signedIn: false)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Graphics"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Render Distance"].exists)
        for _ in 0..<5 {
            if app.staticTexts["Master Volume"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Master Volume"].isHittable)
        for _ in 0..<5 {
            if app.switches["Auto-Jump"].isHittable { break }
            app.swipeUp()
        }
        let toggle = app.switches["Auto-Jump"]
        XCTAssertTrue(toggle.isHittable)
        let before = toggle.value as? String
        toggle.tap()
        XCTAssertNotEqual(toggle.value as? String, before)
        let after = toggle.value as? String
        app.tabBars.buttons["Play"].tap()
        app.tabBars.buttons["Settings"].tap()
        for _ in 0..<5 {
            if toggle.isHittable { break }
            app.swipeUp()
        }
        XCTAssertEqual(toggle.value as? String, after)
    }

    func testSettingsEmptyResponseShowsRetry() {
        let app = launch(signedIn: false, optionsResponse: "empty")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings-retry"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Video"].exists)
        XCTAssertTrue(app.staticTexts["Settings couldn’t load"].exists)
    }

}
