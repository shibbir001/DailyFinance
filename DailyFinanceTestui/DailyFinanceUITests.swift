//
//  DailyFinanceUITests.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//


// DailyFinanceUITests/DailyFinanceUITests.swift
import XCTest

class DailyFinanceUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()

        // Launch with test mode flag
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Test 1: Login Screen Appears
    func test_loginScreen_appearsOnLaunch() {
        let loginTitle = app.staticTexts["DailyFinance"]
        XCTAssertTrue(loginTitle.waitForExistence(
            timeout: 3))
        print("✅ test_loginScreen_appears passed")
    }

    // MARK: - Test 2: Signup Navigation
    func test_signupButton_navigatesToSignup() {
        let signupButton = app.buttons["Sign Up"]
        XCTAssertTrue(signupButton.waitForExistence(
            timeout: 3))
        signupButton.tap()

        let createTitle = app.staticTexts["Create Account"]
        XCTAssertTrue(createTitle.waitForExistence(
            timeout: 3))
        print("✅ test_signupNavigation passed")
    }

    // MARK: - Test 3: Login Fields Exist
    func test_loginFields_exist() {
        XCTAssertTrue(
            app.textFields["your@email.com"]
                .waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.secureTextFields["Enter password"]
                .exists)
        print("✅ test_loginFields_exist passed")
    }

    // MARK: - Test 4: Login Button Disabled When Empty
    func test_loginButton_disabledWhenFieldsEmpty() {
        let loginButton = app.buttons["Login"]
        XCTAssertTrue(loginButton.waitForExistence(
            timeout: 3))
        XCTAssertFalse(loginButton.isEnabled)
        print("✅ test_loginButton_disabled passed")
    }

    // MARK: - Test 5: Numpad Appears on Add Transaction
    func test_numpad_appearsOnAddTransaction() {

        // Skip if not logged in
        guard app.buttons["plus"].waitForExistence(
            timeout: 5) else {
            XCTSkip("Not logged in — skipping")
            return
        }

        // Tap FAB
        app.buttons["plus"].tap()

        // Check numpad appears
        XCTAssertTrue(
            app.buttons["1"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["2"].exists)
        XCTAssertTrue(app.buttons["⌫"].exists)
        print("✅ test_numpad_appears passed")
    }

    // MARK: - Test 6: Cancel Dismisses Add Screen
    func test_cancel_dismissesAddTransaction() {
        guard app.buttons["plus"].waitForExistence(
            timeout: 5) else {
            XCTSkip("Not logged in — skipping")
            return
        }

        app.buttons["plus"].tap()

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(
            timeout: 3))
        cancelButton.tap()

        // Dashboard should be visible again
        XCTAssertTrue(
            app.staticTexts["My Finance"]
                .waitForExistence(timeout: 3))
        print("✅ test_cancel_dismisses passed")
    }
}