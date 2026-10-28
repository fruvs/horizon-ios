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
        if app.buttons["launcher-nav-worlds"].exists {
            app.buttons["launcher-nav-worlds"].tap()
            XCTAssertTrue(app.buttons["new-world-button"].waitForExistence(timeout: 5))
            app.buttons["launcher-nav-play"].tap()
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
        if app.buttons["launcher-nav-worlds"].exists { app.buttons["launcher-nav-worlds"].tap() }
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
        app.buttons["launcher-nav-settings"].tap()
        XCTAssertTrue(app.staticTexts["Graphics"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Render Distance"].exists)
        for _ in 0..<5 {
            if app.buttons["settings-group-sound"].isHittable && app.buttons["settings-group-sound"].frame.maxY < app.frame.maxY - 180 { break }
            app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.70))
                .press(forDuration: 0.05, thenDragTo: app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.40)))
        }
        if app.buttons["settings-group-sound"].value as? String != "Expanded" { app.buttons["settings-group-sound"].tap() }
        XCTAssertEqual(app.buttons["settings-group-sound"].value as? String, "Expanded")
        for _ in 0..<5 {
            if app.staticTexts["Master Volume"].isHittable { break }
            app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.70))
                .press(forDuration: 0.05, thenDragTo: app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.40)))
        }
        XCTAssertTrue(app.staticTexts["Master Volume"].isHittable)
        for _ in 0..<5 {
            if app.buttons["settings-group-controls"].isHittable && app.buttons["settings-group-controls"].frame.maxY < app.frame.maxY - 180 { break }
            app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.70))
                .press(forDuration: 0.05, thenDragTo: app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.40)))
        }
        if app.buttons["settings-group-controls"].value as? String != "Expanded" { app.buttons["settings-group-controls"].tap() }
        XCTAssertEqual(app.buttons["settings-group-controls"].value as? String, "Expanded")
        for _ in 0..<5 {
            if app.switches["setting-autoJump"].isHittable { break }
            app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.70))
                .press(forDuration: 0.05, thenDragTo: app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.40)))
        }
        let toggle = app.switches["setting-autoJump"]
        XCTAssertTrue(toggle.isHittable)
        let before = toggle.value as? String
        toggle.tap()
        XCTAssertNotEqual(toggle.value as? String, before)
        let after = toggle.value as? String
        app.buttons["launcher-nav-play"].tap()
        app.buttons["launcher-nav-settings"].tap()
        for _ in 0..<5 {
            if app.buttons["settings-group-controls"].isHittable && app.buttons["settings-group-controls"].frame.maxY < app.frame.maxY - 180 { break }
            app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.70))
                .press(forDuration: 0.05, thenDragTo: app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.40)))
        }
        if app.buttons["settings-group-controls"].value as? String != "Expanded" { app.buttons["settings-group-controls"].tap() }
        XCTAssertEqual(app.buttons["settings-group-controls"].value as? String, "Expanded")
        for _ in 0..<5 {
            if app.switches.matching(identifier: "setting-autoJump").firstMatch.isHittable { break }
            app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.70))
                .press(forDuration: 0.05, thenDragTo: app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.40)))
        }
        XCTAssertEqual(app.switches.matching(identifier: "setting-autoJump").firstMatch.value as? String, after)
    }

    func testSettingsEmptyResponseShowsRetry() {
        let app = launch(signedIn: false, optionsResponse: "empty")
        app.buttons["launcher-nav-settings"].tap()
        XCTAssertTrue(app.buttons["settings-retry"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Video"].exists)
        XCTAssertTrue(app.staticTexts["Settings couldn’t load"].exists)
    }

    func testFloatingDockHasBottomAndSideClearanceAndNavigates() {
        let app = launch(signedIn: false)
        let dock = app.otherElements["launcher-floating-dock"]
        XCTAssertTrue(dock.exists)
        XCTAssertGreaterThan(dock.frame.minX - app.frame.minX, 10)
        XCTAssertGreaterThan(app.frame.maxX - dock.frame.maxX, 10)
        XCTAssertGreaterThan(app.frame.maxY - dock.frame.maxY, 24)
        for page in ["worlds", "servers", "packs", "settings", "play"] {
            let button = app.buttons["launcher-nav-" + page]
            XCTAssertTrue(button.isHittable); button.tap()
            XCTAssertTrue(app.buttons["launcher-nav-" + page].isSelected)
        }
    }

}
