import MapKit
import SwiftUI

struct AdminMonitorView: View {
    @State private var strings = AppStrings.shared
    @State private var liveTrips: [LiveTripTelemetryDto] = []
    @State private var selectedTripId: String?
    @State private var selectedRoadCoords: [CLLocationCoordinate2D] = []
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -12.0920, longitude: -77.0280),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                if !liveTrips.isEmpty {
                    Section {
                        Map(position: $cameraPosition) {
                            if selectedRoadCoords.count >= 2 {
                                MapPolyline(coordinates: selectedRoadCoords)
                                    .stroke(AppTheme.primaryNavy, lineWidth: 4)
                            }
                            ForEach(liveTrips, id: \.tripId) { trip in
                                Marker("\(trip.vehiclePlate)", systemImage: "bus.fill", coordinate: CLLocationCoordinate2D(latitude: trip.latitude, longitude: trip.longitude))
                                    .tint(trip.tripId == selectedTripId ? AppTheme.primaryNavy : AppTheme.primaryTeal)
                            }
                        }
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section(header: Text("\(AppStrings.tr("admin_monitor_title")) (\(liveTrips.count))")) {
                    ForEach(liveTrips, id: \.tripId) { trip in
                        Button {
                            Task { await selectTrip(trip) }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "bus.doubledecker.fill").foregroundStyle(AppTheme.primaryNavy)
                                    VStack(alignment: .leading) {
                                        Text(trip.routeName).font(.subheadline.bold()).foregroundStyle(.primary)
                                        Text("\(trip.driverName) · \(trip.vehiclePlate) · \(String(format: "%.0f km/h", trip.speedKmh))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(trip.status).font(.caption2.bold()).foregroundStyle(AppTheme.emerald)
                                }
                                HStack {
                                    Text("Estudiantes a bordo: \(trip.boardedCount)/\(trip.totalStudents)")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("SOAT: \(trip.soatPolicy ?? "SOAT-2026-88412")")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.tr("admin_monitor_title"))
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await loadFleet() }
            .task { await loadFleet() }
        }
    }

    private func loadFleet() async {
        let fetched = await RouteGuardRepository.shared.getLiveTrips()
        liveTrips = fetched
        if let chosen = fetched.first(where: { $0.tripId == selectedTripId }) ?? fetched.first {
            await selectTrip(chosen)
        }
    }

    private func selectTrip(_ trip: LiveTripTelemetryDto) async {
        selectedTripId = trip.tripId
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: trip.latitude, longitude: trip.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
        if trip.stops.count >= 2 {
            selectedRoadCoords = await RoadRoutingHelper.fetchRoadCoordinates(
                for: trip.stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            )
        } else {
            selectedRoadCoords = []
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
            .navigationBarTitleDisplayMode(.inline)
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
    @State private var drivers: [DriverProfileDto] = []
    @State private var parents: [ParentProfileDto] = []
    @State private var docs = VehicleDto(id: "veh_01", plate: "ABC-123", brand: "Mercedes-Benz", model: "Mercedes-Benz Sprinter 416", capacity: 20, soatPolicy: "SOAT-2026-88412", soatInsurer: "Rímac Seguros", soatExpiresAt: "15/12/2026", soatValid: true)
    @State private var selectedDriverName = "Carlos Ramirez"
    @State private var selectedPlate = "ABC-123"
    @State private var selectedLicense = "A-IIIa"
    @State private var showDocs = false

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                Section(header: Text(AppStrings.tr("role_driver"))) {
                    if drivers.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Carlos Ramirez").font(.subheadline.bold())
                                Text("\(docs.model) · \(docs.plate) · Lic. A-IIIa").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(AppStrings.tr("docs_view_verify_btn")) {
                                selectedDriverName = "Carlos Ramirez"
                                selectedPlate = docs.plate
                                showDocs = true
                            }
                            .font(.caption.bold())
                        }
                    } else {
                        ForEach(drivers) { d in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(d.fullName).font(.subheadline.bold())
                                    Text("\(d.vehiclePlate) · Lic. \(d.licenseNumber)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(AppStrings.tr("docs_view_verify_btn")) {
                                    selectedDriverName = d.fullName
                                    selectedPlate = d.vehiclePlate
                                    showDocs = true
                                }
                                .font(.caption.bold())
                            }
                        }
                    }
                }
                Section(header: Text(AppStrings.tr("role_parent"))) {
                    if parents.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Rosita Nery").font(.subheadline.bold())
                            Text("Estudiantes: Mateo Nery, Luciana Nery").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(parents) { p in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.fullName).font(.subheadline.bold())
                                if !p.children.isEmpty {
                                    Text("Estudiantes: \(p.children.map(\.name).joined(separator: ", "))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.tr("admin_stakeholders_title"))
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await loadStakeholders() }
            .task { await loadStakeholders() }
            .sheet(isPresented: $showDocs) {
                VehicleDocsSheet(driverName: selectedDriverName, vehiclePlate: selectedPlate, soatPolicy: docs.soatPolicy, soatInsurer: docs.soatInsurer, soatExpiresAt: docs.soatExpiresAt, licenseCategory: selectedLicense)
            }
        }
    }

    private func loadStakeholders() async {
        docs = await RouteGuardRepository.shared.getPrimaryVehicleDocs()
        drivers = await RouteGuardRepository.shared.getDrivers()
        parents = await RouteGuardRepository.shared.getParents()
    }
}

enum AlertFilterTab: String, CaseIterable {
    case all, priority, trip, notices
}

struct AlertsView: View {
    @State private var store = AlertCenterStore.shared
    @State private var session = SessionStore.shared
    @State private var strings = AppStrings.shared
    @State private var filter: AlertFilterTab = .all
    @State private var isLoading = false

    private var filteredAlerts: [SafetyAlertItem] {
        switch filter {
        case .all:
            return store.alerts
        case .priority:
            return store.alerts.filter { $0.isHighPriority }
        case .trip:
            return store.alerts.filter {
                let t = $0.type.uppercased()
                return t == "TRIP_STARTED" || t == "GEOFENCE_BREACHED" || t == "ARRIVED" || t == "STUDENT_BOARDED" || t == "BOARDING"
            }
        case .notices:
            return store.alerts.filter {
                let t = $0.type.uppercased()
                return t == "ANNOUNCEMENT" || t == "GENERAL" || t == "INFO"
            }
        }
    }

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                Section {
                    Picker("", selection: $filter) {
                        Text(AppStrings.tr("alerts_filter_all")).tag(AlertFilterTab.all)
                        Text(AppStrings.tr("alerts_filter_priority")).tag(AlertFilterTab.priority)
                        Text(AppStrings.tr("alerts_filter_trip")).tag(AlertFilterTab.trip)
                        Text(AppStrings.tr("alerts_filter_notices")).tag(AlertFilterTab.notices)
                    }
                    .pickerStyle(.segmented)
                }

                if isLoading && store.alerts.isEmpty {
                    ProgressView()
                } else if filteredAlerts.isEmpty {
                    Text(AppStrings.tr("alerts_empty"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredAlerts) { alert in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(alert.title).font(.subheadline.bold())
                                    .foregroundStyle(alert.isPanic ? AppTheme.errorRed : AppTheme.primaryNavy)
                                Spacer()
                                Text(alert.timestamp).font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(alert.message).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .navigationTitle(AppStrings.tr("alerts_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadAlerts() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await loadAlerts() }
            .task { await loadAlerts() }
        }
    }

    private func loadAlerts() async {
        isLoading = true
        let list = await RouteGuardRepository.shared.getNotifications()
        isLoading = false
        if session.role != .driver {
            await RouteGuardRepository.shared.markNotificationsDelivered(list)
        }
    }
}
