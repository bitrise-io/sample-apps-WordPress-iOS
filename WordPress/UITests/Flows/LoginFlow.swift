import UITestsFoundation
import XCTest

class LoginFlow {

    @discardableResult
    static func login(email: String, siteAddress: String? = nil) throws -> MySiteScreen {
        return try PrologueScreen()
            .selectContinue()
            .proceedWith(email: email)
            .proceedWithValidPassword()
    }

    // Login with self-hosted site via Site Address.
    @discardableResult
    static func login(siteAddress: String, username: String, password: String) throws -> MySiteScreen {
        return try PrologueScreen()
            .selectSiteAddress()
            .proceedWith(siteAddress: siteAddress)
            .proceedWith(username: username, password: password)
    }

    // Login with WP site via Site Address.
    @discardableResult
    static func login(email: String, siteAddress: String) throws -> MySiteScreen {
        return try PrologueScreen()
            .selectSiteAddress()
            .proceedWithWordPress(siteAddress)
            .proceedWith(email: email)
            .proceedWithValidPassword()
    }
}
