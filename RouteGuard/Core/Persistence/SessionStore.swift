import Foundation
import Observation

enum UserRole: String, CaseIterable {
    case parent = "PARENT"
    case driver = "DRIVER"
    case administrator = "ADMINISTRATOR"

    static func normalize(_ raw: String?) -> UserRole {
        let upper = (raw ?? "PARENT").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper == "ADMIN" || upper == "ADMINISTRATOR" { return .administrator }
        if upper == "DRIVER" { return .driver }
        return .parent
    }
}

/// Lightweight preferences and session credentials persisted in UserDefaults
/// (mirrors SharedPreferences in Flutter, while structured domain data lives in SwiftData).
@Observable
final class SessionStore {
    static let shared = SessionStore()

    private enum Keys {
        static let token = "rg_auth_token"
        static let userId = "rg_user_id"
        static let fullName = "rg_full_name"
        static let email = "rg_email"
        static let role = "rg_role"
        static let orgId = "rg_org_id"
        static let darkMode = "rg_dark_mode"
        static let tutorialPrefix = "rg_tutorial_seen_"
    }

    var token: String = ""
    var userId: String = ""
    var fullName: String = ""
    var email: String = ""
    var role: UserRole = .parent
    var organizationId: String = "org_school_01"
    var isDarkMode: Bool = false

    var isAuthenticated: Bool { !token.isEmpty }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reloadFromDefaults()
    }

    func reloadFromDefaults() {
        token = defaults.string(forKey: Keys.token) ?? ""
        userId = defaults.string(forKey: Keys.userId) ?? ""
        fullName = defaults.string(forKey: Keys.fullName) ?? ""
        email = defaults.string(forKey: Keys.email) ?? ""
        role = UserRole.normalize(defaults.string(forKey: Keys.role))
        organizationId = defaults.string(forKey: Keys.orgId) ?? "org_school_01"
        isDarkMode = defaults.bool(forKey: Keys.darkMode)
    }

    func saveSession(token: String, userId: String, fullName: String, email: String, role: UserRole, organizationId: String) {
        self.token = token
        self.userId = userId
        self.fullName = fullName
        self.email = email
        self.role = role
        self.organizationId = organizationId

        defaults.set(token, forKey: Keys.token)
        defaults.set(userId, forKey: Keys.userId)
        defaults.set(fullName, forKey: Keys.fullName)
        defaults.set(email, forKey: Keys.email)
        defaults.set(role.rawValue, forKey: Keys.role)
        defaults.set(organizationId, forKey: Keys.orgId)
    }

    func switchRole(_ newRole: UserRole) {
        role = newRole
        defaults.set(newRole.rawValue, forKey: Keys.role)
    }

    func setDarkMode(_ enabled: Bool) {
        isDarkMode = enabled
        defaults.set(enabled, forKey: Keys.darkMode)
    }

    func hasSeenTutorial(for userId: String) -> Bool {
        defaults.bool(forKey: Keys.tutorialPrefix + userId)
    }

    func setTutorialSeen(for userId: String) {
        defaults.set(true, forKey: Keys.tutorialPrefix + userId)
    }

    func clearSession() {
        token = ""
        userId = ""
        fullName = ""
        email = ""
        role = .parent
        organizationId = "org_school_01"
        [Keys.token, Keys.userId, Keys.fullName, Keys.email, Keys.role, Keys.orgId].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
