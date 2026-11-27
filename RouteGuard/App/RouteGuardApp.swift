import Observation
import SwiftData
import SwiftUI

@Observable
final class AlertCenterStore {
    static let shared = AlertCenterStore()

    var alerts: [SafetyAlertItem] = [
        SafetyAlertItem(
            id: "alt_01",
            title: "Estudiante a bordo",
            message: "Mateo Nery abordó la unidad ABC-123 en Av. Javier Prado Este 2450.",
            type: "BOARDING",
            timestamp: "07:25 AM"
        ),
        SafetyAlertItem(
            id: "alt_02",
            title: "Unidad en aproximación",
            message: "La van ABC-123 se encuentra a 500 metros del Colegio San Juan.",
            type: "INFO",
            timestamp: "07:40 AM"
        )
    ]

    func add(title: String, message: String, type: String) {
        let fmt = DateFormatter()
        fmt.dateFormat = "hh:mm a"
        let item = SafetyAlertItem(
            id: UUID().uuidString,
            title: title,
            message: message,
            type: type,
            timestamp: fmt.string(from: Date())
        )
        alerts.insert(item, at: 0)
    }
}

@main
struct RouteGuardApp: App {
    @State private var session = SessionStore.shared
    @State private var strings = AppStrings.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .preferredColorScheme(session.isDarkMode ? .dark : .light)
            .environment(\.locale, Locale(identifier: strings.currentLanguage.rawValue))
        }
        .modelContainer(LocalDatabase.shared.container)
    }
}
