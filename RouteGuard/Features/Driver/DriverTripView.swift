import MapKit
import SwiftUI
import UIKit

struct DriverTripView: View {
    @Environment(\.openURL) private var openURL
    @State private var strings = AppStrings.shared
    @State private var activeTripId = "TRP-2026-08"
    @State private var activeRouteId: String? = "f0000000-0000-0000-0000-000000000001"
    @State private var routeName = "Ruta San Martín"
    @State private var vehiclePlate = "ABC-123"
    @State private var busCoordinate = CLLocationCoordinate2D(latitude: -12.0920, longitude: -77.0280)
    @State private var stops: [StopDto] = []
    @State private var roadCoords: [CLLocationCoordinate2D] = []
    @State private var assignedRoutes: [RouteSummaryItem] = []
    @State private var selectedRouteId = ""
    @State private var awaitingTripStart = false
    @State private var passengers: [DriverPassengerItem] = [
        DriverPassengerItem(id: "p1", name: "Mateo Nery", grade: "Primaria • 4to B", stopAddress: "Av. Javier Prado Este 2450", scheduledTime: "07:15 AM", status: .pending),
        DriverPassengerItem(id: "p2", name: "Luciana Nery", grade: "Primaria • 5to A", stopAddress: "Calle Las Flores 302", scheduledTime: "07:22 AM", status: .boarded),
        DriverPassengerItem(id: "p3", name: "Jorge Salas", grade: "Primaria • 3ro B", stopAddress: "Av. Arequipa 1890", scheduledTime: "07:30 AM", status: .pending),
        DriverPassengerItem(id: "p4", name: "Camila Quispe", grade: "Primaria • 6to A", stopAddress: "Calle Los Pinos 180", scheduledTime: "07:36 AM", status: .pending)
    ]
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -12.0920, longitude: -77.0280),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    )
    @State private var isCancelled = false
    @State private var isFinished = false
    @State private var cancelReason: String?
    @State private var csvFeedback: String?

    @State private var showDocs = false
    @State private var showCancelDialog = false
    @State private var showAnnouncements = false
    @State private var showPickupOpt = false
    @State private var showChat = false
    @State private var showMaintenances = false
    @State private var showExpenses = false
    @State private var cancelSelectedReason = "Falla mecánica grave"

    private var boardedCount: Int { passengers.filter { $0.status == .boarded }.count }

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if awaitingTripStart && !assignedRoutes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppStrings.tr("driver_pick_route"))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.primaryNavy)
                            Picker(AppStrings.tr("driver_pick_route"), selection: $selectedRouteId) {
                                ForEach(assignedRoutes) { r in
                                    Text("\(r.name) (\(r.vehiclePlate))").tag(r.id)
                                }
                            }
                            .pickerStyle(.menu)
                            Button {
                                Task {
                                    let chosen = selectedRouteId.isEmpty ? (assignedRoutes.first?.id ?? "") : selectedRouteId
                                    if await RouteGuardRepository.shared.startDriverTrip(routeId: chosen) {
                                        await loadDriverTrip()
                                    }
                                }
                            } label: {
                                Label(AppStrings.tr("driver_start_trip"), systemImage: "play.fill")
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primaryNavy)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(14)
                        .background(AppTheme.primaryNavy.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(routeName) · \(vehiclePlate)").font(.headline)
                            Spacer()
                            Text(isCancelled ? "CANCELADO" : (isFinished ? "FINALIZADO" : (awaitingTripStart ? "LISTO" : "EN CURSO")))
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isCancelled ? AppTheme.errorRed.opacity(0.15) : AppTheme.emerald.opacity(0.15))
                                .foregroundStyle(isCancelled ? AppTheme.errorRed : AppTheme.emerald)
                                .clipShape(Capsule())
                        }
                        if let cancelReason {
                            Text("Motivo: \(cancelReason)")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.errorRed)
                        }
                        ProgressView(value: Double(boardedCount), total: Double(max(passengers.count, 1)))
                            .tint(AppTheme.primaryTeal)
                        HStack {
                            Text("\(boardedCount)/\(passengers.count) \(AppStrings.tr("driver_status_boarded").lowercased())")
                                .font(.caption.bold())
                            Spacer()
                            Button(AppStrings.tr("docs_view_verify_btn")) { showDocs = true }
                                .font(.caption.bold())
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Map + External Maps Navigation
                    Map(position: $cameraPosition) {
                        if roadCoords.count >= 2 {
                            MapPolyline(coordinates: roadCoords)
                                .stroke(AppTheme.primaryNavy, lineWidth: 4.5)
                        }
                        ForEach(stops) { stop in
                            let isSchool = stop.name.localizedCaseInsensitiveContains("colegio")
                                || stop.name.localizedCaseInsensitiveContains("school")
                            Marker(stop.name, systemImage: isSchool ? "building.columns.fill" : "mappin.circle.fill", coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
                                .tint(isSchool ? AppTheme.errorRed : AppTheme.primaryTeal)
                        }
                        Marker("Van \(vehiclePlate)", systemImage: "bus.fill", coordinate: busCoordinate)
                            .tint(AppTheme.primaryNavy)
                    }
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    HStack(spacing: 10) {
                        Button {
                            let target = stops.first(where: { !$0.isReached }) ?? stops.first
                            let lat = target?.latitude ?? busCoordinate.latitude
                            let lng = target?.longitude ?? busCoordinate.longitude
                            if let url = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=d") {
                                openURL(url)
                            }
                        } label: {
                            Label(AppStrings.tr("driver_nav_maps"), systemImage: "location.north.fill")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppTheme.primaryNavy)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Button {
                            let header = "Estudiante,Grado,Paradero,Hora,Estado"
                            let rows = passengers.map { "\($0.name),\($0.grade),\($0.stopAddress),\($0.scheduledTime),\($0.status.rawValue)" }
                            UIPasteboard.general.string = ([header] + rows).joined(separator: "\n")
                            csvFeedback = AppStrings.tr("driver_attendance_copied")
                        } label: {
                            Label(AppStrings.tr("driver_attendance_btn"), systemImage: "doc.on.doc")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .foregroundStyle(AppTheme.primaryNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if let csvFeedback {
                        Text(csvFeedback).font(.caption.bold()).foregroundStyle(AppTheme.emerald)
                    }

                    // Checklist
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppStrings.tr("driver_checklist_header")).font(.headline)
                        ForEach($passengers) { $p in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.subheadline.bold())
                                    Text("\(p.stopAddress) · \(p.scheduledTime)").font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if p.status == .pending {
                                    Button(AppStrings.tr("driver_status_absent")) {
                                        p.status = .absent
                                        Task { await RouteGuardRepository.shared.setBoardingStatus(tripId: activeTripId, childId: p.id, boardingState: "ABSENT") }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isCancelled || isFinished)
                                    Button(AppStrings.tr("driver_status_boarded")) {
                                        p.status = .boarded
                                        Task { await RouteGuardRepository.shared.setBoardingStatus(tripId: activeTripId, childId: p.id, boardingState: "BOARDED") }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.primaryNavy)
                                    .disabled(isCancelled || isFinished)
                                } else {
                                    Text(p.status == .boarded ? AppStrings.tr("driver_status_boarded") : AppStrings.tr("driver_status_absent"))
                                        .font(.caption.bold())
                                        .foregroundStyle(p.status == .boarded ? AppTheme.emerald : AppTheme.errorRed)
                                    Button(AppStrings.tr("driver_btn_undo")) {
                                        p.status = .pending
                                        Task { await RouteGuardRepository.shared.setBoardingStatus(tripId: activeTripId, childId: p.id, boardingState: "MISSING") }
                                    }
                                    .font(.caption2)
                                    .disabled(isCancelled || isFinished)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                        }
                    }

                    // Roadblock, Finish & Cancel
                    HStack(spacing: 10) {
                        Button(AppStrings.tr("driver_roadblock_btn")) {
                            Task {
                                await RouteGuardRepository.shared.reportRoadblockIncident(tripId: activeTripId, incidentType: "ROADBLOCK", delayMinutes: 25)
                                AlertCenterStore.shared.add(title: "⚠️ Bloqueo de Vía", message: "Retraso estimado +25 min en Av. Javier Prado.", type: "INCIDENT")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .disabled(isCancelled || isFinished)

                        Button(AppStrings.tr("driver_finish_trip")) {
                            isFinished = true
                            Task {
                                await RouteGuardRepository.shared.completeTrip(tripId: activeTripId)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primaryNavy)
                        .disabled(isCancelled || isFinished || awaitingTripStart)
                    }

                    Button(AppStrings.tr("driver_cancel_btn")) {
                        showCancelDialog = true
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.errorRed)
                    .disabled(isCancelled || isFinished)

                    // Driver Tools (US-20, 24, 26, 27, 28, 30)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppStrings.tr("driver_tools_title")).font(.subheadline.bold())
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            toolBtn(AppStrings.tr("announcements_btn")) { showAnnouncements = true }
                            toolBtn(AppStrings.tr("pickup_opt_btn")) { showPickupOpt = true }
                            toolBtn(AppStrings.tr("chat_btn")) { showChat = true }
                            toolBtn(AppStrings.tr("maintenances_btn")) { showMaintenances = true }
                            toolBtn(AppStrings.tr("expenses_btn")) { showExpenses = true }
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .navigationTitle(AppStrings.tr("driver_trip_title"))
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadDriverTrip() }
            .refreshable { await loadDriverTrip() }
            .alert(AppStrings.tr("driver_cancel_title"), isPresented: $showCancelDialog) {
                Button("Falla mecánica grave", role: .destructive) { confirmCancel("Falla mecánica grave") }
                Button("Bloqueo total de vía", role: .destructive) { confirmCancel("Bloqueo total de vía") }
                Button(AppStrings.tr("common_cancel"), role: .cancel) {}
            } message: {
                Text(AppStrings.tr("driver_cancel_reason"))
            }
            .sheet(isPresented: $showDocs) {
                VehicleDocsSheet(driverName: SessionStore.shared.fullName.isEmpty ? "Carlos Ramirez" : SessionStore.shared.fullName, vehiclePlate: vehiclePlate, soatPolicy: "SOAT-2026-88412", soatInsurer: "Rímac Seguros", soatExpiresAt: "15/12/2026", licenseCategory: "A-IIIa")
            }
            .sheet(isPresented: $showAnnouncements) { AnnouncementsSheet(canPublish: true) }
            .sheet(isPresented: $showPickupOpt) { PickupAndOptSheet(canRequest: false, canApprove: true, routeId: activeRouteId ?? "f0000000-0000-0000-0000-000000000001") }
            .sheet(isPresented: $showChat) { InternalChatSheet() }
            .sheet(isPresented: $showMaintenances) { MaintenanceSheet(canAdd: true) }
            .sheet(isPresented: $showExpenses) { ExpensesSheet() }
        }
    }

    private func loadDriverTrip() async {
        let res = await RouteGuardRepository.shared.getDriverActiveTrip()
        guard !res.isOfflineFallback else { return }
        routeName = res.routeName
        vehiclePlate = res.vehiclePlate
        activeRouteId = res.routeId
        assignedRoutes = res.assignedRoutes
        if selectedRouteId.isEmpty { selectedRouteId = res.assignedRoutes.first?.id ?? "" }
        stops = res.stops
        busCoordinate = CLLocationCoordinate2D(latitude: res.latitude, longitude: res.longitude)
        if res.hasActiveTrip, let tid = res.tripId {
            activeTripId = tid
            awaitingTripStart = false
            isFinished = false
        } else {
            awaitingTripStart = !res.assignedRoutes.isEmpty
        }
        let coords = ([busCoordinate] + res.stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
        if res.stops.count >= 2 {
            roadCoords = await RoadRoutingHelper.fetchRoadCoordinates(for: res.stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
        } else if coords.count >= 2 {
            roadCoords = await RoadRoutingHelper.fetchRoadCoordinates(for: coords)
        }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: busCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            )
        )
    }

    private func toolBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .foregroundStyle(AppTheme.primaryNavy)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func confirmCancel(_ reason: String) {
        isCancelled = true
        cancelReason = reason
        Task {
            await RouteGuardRepository.shared.cancelTripForceMajeure(tripId: activeTripId, reason: reason, notes: "")
            AlertCenterStore.shared.add(title: "🚨 Viaje Cancelado", message: "Fuerza mayor: \(reason)", type: "PANIC")
        }
    }
}
