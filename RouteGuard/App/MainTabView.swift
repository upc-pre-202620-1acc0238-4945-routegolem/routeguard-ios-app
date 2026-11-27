import SwiftUI

struct MainTabView: View {
    @State private var session = SessionStore.shared
    @State private var strings = AppStrings.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        let _ = strings.currentLanguage
        TabView(selection: $selectedTab) {
            if session.role == .administrator {
                AdminMonitorView()
                    .tabItem { Label(AppStrings.tr("nav_monitor"), systemImage: "map.fill") }
                    .tag(0)
                AdminRoutesView()
                    .tabItem { Label(AppStrings.tr("nav_routes"), systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
                    .tag(1)
                AdminStakeholdersView()
                    .tabItem { Label(AppStrings.tr("nav_stakeholders"), systemImage: "person.3.fill") }
                    .tag(2)
                AlertsView()
                    .tabItem { Label(AppStrings.tr("nav_alerts"), systemImage: "bell.fill") }
                    .tag(3)
                ProfileView()
                    .tabItem { Label(AppStrings.tr("nav_profile"), systemImage: "person.circle.fill") }
                    .tag(4)
            } else if session.role == .driver {
                DriverTripView()
                    .tabItem { Label(AppStrings.tr("nav_driver_trip"), systemImage: "bus.fill") }
                    .tag(0)
                AlertsView()
                    .tabItem { Label(AppStrings.tr("nav_alerts"), systemImage: "bell.fill") }
                    .tag(1)
                ProfileView()
                    .tabItem { Label(AppStrings.tr("nav_profile"), systemImage: "person.circle.fill") }
                    .tag(2)
            } else {
                ParentTrackingView()
                    .tabItem { Label(AppStrings.tr("nav_tracking"), systemImage: "location.fill") }
                    .tag(0)
                AlertsView()
                    .tabItem { Label(AppStrings.tr("nav_alerts"), systemImage: "bell.fill") }
                    .tag(1)
                ProfileView()
                    .tabItem { Label(AppStrings.tr("nav_profile"), systemImage: "person.circle.fill") }
                    .tag(2)
            }
        }
        .tint(AppTheme.primaryNavy)
    }
}
