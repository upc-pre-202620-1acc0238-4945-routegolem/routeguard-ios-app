import Foundation
import SwiftData
import XCTest
@testable import RouteGuard

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class RouteGuardTests: XCTestCase {

    func testSpanishAndEnglishDictionariesHaveFullKeyParity() {
        let esKeys = AppStrings.keys(for: .spanish)
        let enKeys = AppStrings.keys(for: .english)

        XCTAssertFalse(esKeys.isEmpty)
        XCTAssertEqual(esKeys.subtracting(enKeys), [], "Missing English localization keys")
        XCTAssertEqual(enKeys.subtracting(esKeys), [], "Missing Spanish localization keys")
    }

    func testLanguageToggleSwitchesStringsDynamically() {
        AppStrings.shared.setLanguage(.spanish)
        XCTAssertEqual(AppStrings.tr("profile_title"), "Mi Perfil")

        AppStrings.shared.setLanguage(.english)
        XCTAssertEqual(AppStrings.tr("profile_title"), "My Profile")

        AppStrings.shared.setLanguage(.spanish)
    }

    func testSessionStorePersistsThemeRoleAndTokenInUserDefaults() {
        let suiteName = "RouteGuardUnitTestSuite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SessionStore(defaults: defaults)

        store.saveSession(
            token: "jwt_123",
            userId: "usr_1",
            fullName: "Rosita Nery",
            email: "parent@routeguard.pe",
            role: UserRole.normalize("ADMIN"),
            organizationId: "org_school_01"
        )
        store.setDarkMode(true)

        let reloaded = SessionStore(defaults: defaults)
        XCTAssertTrue(reloaded.isAuthenticated)
        XCTAssertEqual(reloaded.role, .administrator)
        XCTAssertTrue(reloaded.isDarkMode)

        reloaded.clearSession()
        XCTAssertFalse(reloaded.isAuthenticated)
    }

    @MainActor
    func testOfflinePersistenceAndMockApiRepository() async throws {
        let db = LocalDatabase(inMemory: true)
        let suiteName = "RouteGuardRepoTest_\(UUID().uuidString)"
        let store = SessionStore(defaults: UserDefaults(suiteName: suiteName)!)

        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: cfg)

        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            if url.path.hasSuffix("/users/sign-in") {
                let json = """
                {"id":"u1","firstName":"Rosita","lastName":"Nery","email":"parent@routeguard.pe","roleTier":"PARENT","token":"tok_ok","organizationId":"org_school_01"}
                """
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
            }
            if url.path.hasSuffix("/vehicles") {
                let json = """
                [{"id":"v1","plate":"ABC-123","brand":"Mercedes-Benz","model":"Mercedes-Benz Sprinter 416","capacity":20,"soatPolicy":"SOAT-2026-88412","soatInsurer":"Rímac Seguros","soatExpiresAt":"2026-12-15","soatValid":true}]
                """
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
            }
            return (HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!, Data())
        }

        let repo = RouteGuardRepository(urlSession: mockSession, database: db, sessionStore: store)
        let account = try await repo.signIn(email: "parent@routeguard.pe", password: "parent123")
        XCTAssertEqual(account.fullName, "Rosita Nery")
        XCTAssertEqual(account.token, "tok_ok")

        let vehicle = await repo.getPrimaryVehicleDocs()
        XCTAssertEqual(vehicle.plate, "ABC-123")
        XCTAssertEqual(vehicle.soatPolicy, "SOAT-2026-88412")

        // Offline write queues into SwiftData when server returns 503
        await repo.addCaregiver(fullName: "Carmen López", relationship: "Abuela", phone: "987123456")
        let caregivers = await repo.getCaregivers()
        XCTAssertEqual(caregivers.count, 1)
        XCTAssertEqual(caregivers.first?.fullName, "Carmen López")

        await repo.addMaintenance(plate: "ABC-123", type: "Frenos", workshop: "Taller Central", cost: 250.0)
        let maintenances = await repo.getMaintenances()
        XCTAssertEqual(maintenances.count, 1)

        await repo.sendChatMessage("Unidad saliendo a tiempo")
        let chat = await repo.getChatMessages()
        XCTAssertEqual(chat.count, 1)
    }
}
