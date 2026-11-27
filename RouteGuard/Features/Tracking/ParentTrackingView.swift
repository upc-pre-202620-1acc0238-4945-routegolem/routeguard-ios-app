import MapKit
import SwiftUI

struct ParentTrackingView: View {
    @Environment(\.openURL) private var openURL
    @State private var strings = AppStrings.shared
    @State private var telemetry = LiveTripTelemetryDto()
    @State private var vehicleDocs = VehicleDto(
        id: "veh_01", plate: "ABC-123", brand: "Mercedes-Benz", model: "Mercedes-Benz Sprinter 416",
        capacity: 20, soatPolicy: "SOAT-2026-88412", soatInsurer: "Rímac Seguros", soatExpiresAt: "15/12/2026", soatValid: true
    )
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -12.0920, longitude: -77.0280),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    )

    @State private var showDocsSheet = false
    @State private var showHistorySheet = false
    @State private var showAbsenceSheet = false
    @State private var showRateSheet = false
    @State private var showAnnouncementsSheet = false
    @State private var showPickupSheet = false
    @State private var showChatSheet = false
    @State private var showPanicAlert = false
    @State private var panicDispatched = false

    @State private var hasActiveTrip = true
    @State private var isLoadingTrip = false
    @State private var roadCoords: [CLLocationCoordinate2D] = []
    @State private var activeAbsenceBanner: String?
    @State private var submittedRating: Int?

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            ScrollView {
                if !hasActiveTrip && !isLoadingTrip {
                    VStack(spacing: 14) {
                        Image(systemName: "bus")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.primaryNavy)
                            .padding(.top, 40)
                        Text(AppStrings.tr("tracking_no_trip_title"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.primaryNavy)
                        Text(AppStrings.tr("tracking_no_trip_subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button {
                            Task { await loadParentTrip() }
                        } label: {
                            Label(AppStrings.tr("common_loading").replacingOccurrences(of: "…", with: ""), systemImage: "arrow.clockwise")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                VStack(spacing: 14) {
                    // Map preview
                    Map(position: $cameraPosition) {
                        if roadCoords.count >= 2 {
                            MapPolyline(coordinates: roadCoords)
                                .stroke(AppTheme.primaryNavy, lineWidth: 4.5)
                        }
                        ForEach(telemetry.stops) { stop in
                            let isSchool = stop.name.localizedCaseInsensitiveContains("colegio")
                                || stop.name.localizedCaseInsensitiveContains("school")
                            Marker(
                                stop.name,
                                systemImage: isSchool ? "building.columns.fill" : (stop.isReached ? "checkmark.circle.fill" : "mappin.circle.fill"),
                                coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                            )
                            .tint(isSchool ? AppTheme.errorRed : (stop.isReached ? AppTheme.emerald : AppTheme.warningAmber))
                        }
                        Marker(telemetry.vehiclePlate, systemImage: "bus.fill", coordinate: CLLocationCoordinate2D(latitude: telemetry.latitude, longitude: telemetry.longitude))
                            .tint(AppTheme.primaryNavy)
                    }
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // Telemetry status banner
                    HStack {
                        Label(telemetry.routeName, systemImage: "bus")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.primaryNavy)
                        Spacer()
                        Text(AppStrings.trf("tracking_speed_fmt", ["speed": String(format: "%.0f", telemetry.speedKmh)]))
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.emerald.opacity(0.15))
                            .foregroundStyle(AppTheme.emerald)
                            .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if let absence = activeAbsenceBanner {
                        Text(AppStrings.trf("absence_saved_banner", ["child": absence]))
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Driver + SOAT card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primaryNavy)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(telemetry.driverName).font(.headline)
                                Text("\(vehicleDocs.model) · \(telemetry.vehiclePlate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                let rawPhone = (telemetry.driverPhone ?? "+51987654321").filter { $0.isNumber || $0 == "+" }
                                if let tel = URL(string: "tel:\(rawPhone)") {
                                    openURL(tel)
                                }
                            } label: {
                                Image(systemName: "phone.fill")
                                    .padding(8)
                                    .background(AppTheme.emerald.opacity(0.15))
                                    .foregroundStyle(AppTheme.emerald)
                                    .clipShape(Circle())
                            }
                        }

                        HStack {
                            Text(AppStrings.trf("docs_summary_chip", ["date": telemetry.soatExpiresAt ?? "12/2026", "cat": telemetry.driverLicenseCategory ?? "A-IIIa"]))
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.emerald.opacity(0.12))
                                .foregroundStyle(AppTheme.emerald)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Spacer()
                            Button(AppStrings.tr("docs_view_verify_btn")) {
                                showDocsSheet = true
                            }
                            .font(.caption.bold())
                        }

                        Text(AppStrings.trf("tracking_child_boarded", ["plate": telemetry.vehiclePlate]))
                            .font(.caption)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.emerald.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)

                    // Quick Action Grid (US-15, US-09, US-14, US-24, US-27, US-30)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        actionButton(AppStrings.tr("history_btn"), icon: "clock.arrow.circlepath") { showHistorySheet = true }
                        actionButton(AppStrings.tr("absence_btn"), icon: "calendar.badge.minus") { showAbsenceSheet = true }
                        actionButton(
                            submittedRating.map { AppStrings.trf("rate_chip_fmt", ["stars": "\($0)"]) } ?? AppStrings.tr("rate_btn"),
                            icon: "star.fill"
                        ) { showRateSheet = true }
                        actionButton(AppStrings.tr("announcements_btn"), icon: "megaphone.fill") { showAnnouncementsSheet = true }
                        actionButton(AppStrings.tr("pickup_opt_btn"), icon: "location.magnifyingglass") { showPickupSheet = true }
                        actionButton(AppStrings.tr("chat_btn"), icon: "bubble.left.and.bubble.right.fill") { showChatSheet = true }
                    }

                    // Panic Button
                    Button {
                        showPanicAlert = true
                    } label: {
                        Label(AppStrings.tr("tracking_panic_btn"), systemImage: "exclamationmark.triangle.fill")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.errorRed)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    if panicDispatched {
                        Text(AppStrings.tr("tracking_panic_sent"))
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.errorRed)
                    }
                }
                .padding()
                }
            }
            .refreshable { await loadParentTrip() }
            .navigationTitle(AppStrings.tr("tracking_title"))
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadParentTrip() }
            .alert(AppStrings.tr("tracking_panic_title"), isPresented: $showPanicAlert) {
                Button(AppStrings.tr("common_cancel"), role: .cancel) {}
                Button(AppStrings.tr("tracking_panic_confirm"), role: .destructive) {
                    Task {
                        await RouteGuardRepository.shared.triggerPanicAlert(tripId: telemetry.tripId)
                        AlertCenterStore.shared.add(title: "🚨 Alerta de Pánico", message: "Emergencia activada en unidad \(telemetry.vehiclePlate).", type: "PANIC")
                        panicDispatched = true
                    }
                }
            } message: {
                Text(AppStrings.tr("tracking_panic_msg"))
            }
            .sheet(isPresented: $showDocsSheet) {
                VehicleDocsSheet(
                    driverName: telemetry.driverName,
                    vehiclePlate: telemetry.vehiclePlate,
                    soatPolicy: telemetry.soatPolicy ?? vehicleDocs.soatPolicy,
                    soatInsurer: telemetry.soatInsurer ?? vehicleDocs.soatInsurer,
                    soatExpiresAt: telemetry.soatExpiresAt ?? vehicleDocs.soatExpiresAt,
                    licenseCategory: telemetry.driverLicenseCategory ?? "A-IIIa"
                )
            }
            .sheet(isPresented: $showHistorySheet) {
                TripHistorySheet { stars in submittedRating = stars }
            }
            .sheet(isPresented: $showAbsenceSheet) {
                ParentAbsenceSheet(
                    tripId: telemetry.tripId,
                    childOptions: telemetry.children.isEmpty ? ["Mateo Nery", "Luciana Nery"] : telemetry.children.map(\.name)
                ) { child in
                    activeAbsenceBanner = child
                }
            }
            .sheet(isPresented: $showRateSheet) {
                ParentRateSheet(tripId: telemetry.tripId) { stars in
                    submittedRating = stars
                }
            }
            .sheet(isPresented: $showAnnouncementsSheet) {
                AnnouncementsSheet(canPublish: false)
            }
            .sheet(isPresented: $showPickupSheet) {
                PickupAndOptSheet(canRequest: true, canApprove: false, routeId: telemetry.routeId ?? "f0000000-0000-0000-0000-000000000001")
            }
            .sheet(isPresented: $showChatSheet) {
                InternalChatSheet()
            }
        }
    }

    private func loadParentTrip() async {
        isLoadingTrip = true
        let res = await RouteGuardRepository.shared.getParentActiveTrip()
        hasActiveTrip = res.hasActiveTrip
        if let active = res.telemetry {
            telemetry = active
            let stopCoords = active.stops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            if stopCoords.count >= 2 {
                roadCoords = await RoadRoutingHelper.fetchRoadCoordinates(for: stopCoords)
            } else {
                roadCoords = []
            }
            let pts = stopCoords + [CLLocationCoordinate2D(latitude: active.latitude, longitude: active.longitude)]
            if let region = Self.regionFitting(pts) {
                cameraPosition = .region(region)
            }
        }
        vehicleDocs = await RouteGuardRepository.shared.getPrimaryVehicleDocs()
        isLoadingTrip = false
    }

    private static func regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coords.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLng = first.longitude, maxLng = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max(0.025, (maxLat - minLat) * 1.45), longitudeDelta: max(0.025, (maxLng - minLng) * 1.45))
        return MKCoordinateRegion(center: center, span: span)
    }

    private func actionButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption.bold()).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(AppTheme.primaryNavy)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ParentAbsenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tripId: String
    let childOptions: [String]
    let onSaved: (String) -> Void
    @State private var selectedChild = ""
    @State private var reason = "Cita médica"
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker(AppStrings.tr("absence_child_label"), selection: $selectedChild) {
                    ForEach(childOptions, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Picker(AppStrings.tr("absence_reason_label"), selection: $reason) {
                    Text("Cita médica").tag("Cita médica")
                    Text("Viaje familiar").tag("Viaje familiar")
                    Text("Otro").tag("Otro")
                }
                TextField(AppStrings.tr("absence_notes_label"), text: $notes)
                Button(AppStrings.tr("absence_confirm_btn")) {
                    let chosen = selectedChild.isEmpty ? (childOptions.first ?? "Estudiante") : selectedChild
                    Task {
                        await RouteGuardRepository.shared.reportAbsence(childName: chosen, reason: reason, notes: notes)
                        AlertCenterStore.shared.add(title: "Ausencia Temprana", message: "\(chosen) no abordará hoy (\(reason)).", type: "INFO")
                        onSaved(chosen)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedChild.isEmpty { selectedChild = childOptions.first ?? "Mateo Nery" }
            }
            .navigationTitle(AppStrings.tr("absence_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(AppStrings.tr("common_cancel")) { dismiss() } }
            }
        }
    }
}

private struct ParentRateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tripId: String
    let onSaved: (Int) -> Void
    @State private var stars = 5
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Estrellas", selection: $stars) {
                    ForEach(1...5, id: \.self) { Text("\($0) ★").tag($0) }
                }
                .pickerStyle(.segmented)
                TextField(AppStrings.tr("rate_comment_label"), text: $comment)
                Button(AppStrings.tr("rate_submit_btn")) {
                    Task {
                        await RouteGuardRepository.shared.submitRating(tripId: tripId, stars: stars, comment: comment)
                        onSaved(stars)
                        dismiss()
                    }
                }
            }
            .navigationTitle(AppStrings.tr("rate_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(AppStrings.tr("common_cancel")) { dismiss() } }
            }
        }
    }
}
