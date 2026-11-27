import SwiftUI

struct AdminMonitorView: View {
    @State private var strings = AppStrings.shared
    @State private var liveTrip = LiveTripTelemetryDto()

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                Section(header: Text(AppStrings.tr("admin_monitor_title"))) {
                    HStack {
                        Image(systemName: "bus.doubledecker.fill").foregroundStyle(AppTheme.primaryNavy)
                        VStack(alignment: .leading) {
                            Text(liveTrip.routeName).font(.subheadline.bold())
                            Text("\(liveTrip.driverName) · \(liveTrip.vehiclePlate) · \(String(format: "%.0f km/h", liveTrip.speedKmh))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(liveTrip.status).font(.caption2.bold()).foregroundStyle(AppTheme.emerald)
                    }
                    LabeledContent("Estudiantes a bordo", value: "\(liveTrip.boardedCount)/\(liveTrip.totalStudents)")
                    LabeledContent("SOAT Póliza", value: liveTrip.soatPolicy ?? "SOAT-2026-88412")
                }
            }
            .navigationTitle(AppStrings.tr("admin_monitor_title"))
            .task { liveTrip = await RouteGuardRepository.shared.getActiveTrip() }
        }
    }
}

struct AdminRoutesView: View {
    @State private var strings = AppStrings.shared
    @State private var routes: [RouteSummaryItem] = []
    @State private var newRouteName = ""
    @State private var showMaintenances = false
    @State private var showExpenses = false
    @State private var showPickupOpt = false

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField(AppStrings.tr("admin_new_route_placeholder"), text: $newRouteName)
                        Button(AppStrings.tr("admin_create_route_btn")) {
                            let trimmed = newRouteName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            newRouteName = ""
                            Task {
                                if let created = await RouteGuardRepository.shared.createRoute(name: trimmed) {
                                    routes.insert(created, at: 0)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primaryNavy)
                    }
                }
                Section {
                    ForEach(routes) { r in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(r.name).font(.subheadline.bold())
                                Text("Unidad \(r.vehiclePlate) · \(r.stopsCount) paraderos")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(r.status).font(.caption2.bold()).foregroundStyle(AppTheme.emerald)
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.tr("admin_routes_title"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showMaintenances = true } label: { Image(systemName: "wrench.and.screwdriver") }
                    Button { showExpenses = true } label: { Image(systemName: "dollarsign.circle") }
                    Button { showPickupOpt = true } label: { Image(systemName: "arrow.triangle.swap") }
                }
            }
            .task { routes = await RouteGuardRepository.shared.getRoutes() }
            .sheet(isPresented: $showMaintenances) { MaintenanceSheet(canAdd: true) }
            .sheet(isPresented: $showExpenses) { ExpensesSheet() }
            .sheet(isPresented: $showPickupOpt) {
                PickupAndOptSheet(canRequest: false, canApprove: true, routeId: routes.first?.id ?? "f0000000-0000-0000-0000-000000000001")
            }
        }
    }
}

struct AdminStakeholdersView: View {
    @State private var strings = AppStrings.shared
    @State private var docs = VehicleDto(id: "veh_01", plate: "ABC-123", brand: "Mercedes-Benz", model: "Mercedes-Benz Sprinter 416", capacity: 20, soatPolicy: "SOAT-2026-88412", soatInsurer: "Rímac Seguros", soatExpiresAt: "15/12/2026", soatValid: true)
    @State private var showDocs = false

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                Section(header: Text(AppStrings.tr("role_driver"))) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Carlos Ramirez").font(.subheadline.bold())
                            Text("\(docs.model) · \(docs.plate) · Lic. A-IIIa").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(AppStrings.tr("docs_view_verify_btn")) { showDocs = true }
                            .font(.caption.bold())
                    }
                }
                Section(header: Text(AppStrings.tr("role_parent"))) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Rosita Nery").font(.subheadline.bold())
                        Text("Estudiantes: Mateo Nery, Luciana Nery").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(AppStrings.tr("admin_stakeholders_title"))
            .task { docs = await RouteGuardRepository.shared.getPrimaryVehicleDocs() }
            .sheet(isPresented: $showDocs) {
                VehicleDocsSheet(driverName: "Carlos Ramirez", vehiclePlate: docs.plate, soatPolicy: docs.soatPolicy, soatInsurer: docs.soatInsurer, soatExpiresAt: docs.soatExpiresAt, licenseCategory: "A-IIIa")
            }
        }
    }
}

struct AlertsView: View {
    @State private var store = AlertCenterStore.shared
    @State private var strings = AppStrings.shared

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                ForEach(store.alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(alert.title).font(.subheadline.bold())
                                .foregroundStyle(alert.type == "PANIC" ? AppTheme.errorRed : AppTheme.primaryNavy)
                            Spacer()
                            Text(alert.timestamp).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(alert.message).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
            .navigationTitle(AppStrings.tr("alerts_title"))
        }
    }
}
