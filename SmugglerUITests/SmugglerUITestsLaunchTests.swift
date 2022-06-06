//
//  SmugglerUITestsLaunchTests.swift
//  SmugglerUITests
//
//  Created by mk.pwnz on 07/05/2022.
//

import XCTest

class SmugglerUITestsLaunchTests: XCTestCase {
    // swiftlint:disable overridden_super_call
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    // swiftlint:enable vertical_whitespace_opening_braces
}
