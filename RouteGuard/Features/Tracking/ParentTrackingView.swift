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

    @State private var activeAbsenceBanner: String?
    @State private var submittedRating: Int?

    private let routeCoords = [
        CLLocationCoordinate2D(latitude: -12.0870, longitude: -77.0350),
        CLLocationCoordinate2D(latitude: -12.0920, longitude: -77.0280),
        CLLocationCoordinate2D(latitude: -12.0980, longitude: -77.0200),
        CLLocationCoordinate2D(latitude: -12.1040, longitude: -77.0150)
    ]

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Map preview
                    Map(position: $cameraPosition) {
                        Marker(telemetry.vehiclePlate, systemImage: "bus.fill", coordinate: CLLocationCoordinate2D(latitude: telemetry.latitude, longitude: telemetry.longitude))
                            .tint(AppTheme.primaryNavy)
                        MapPolyline(coordinates: routeCoords)
                            .stroke(AppTheme.primaryNavy, lineWidth: 4)
                    }
                    .frame(height: 220)
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
                                if let tel = URL(string: "tel:+51987654321") {
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
            .navigationTitle(AppStrings.tr("tracking_title"))
            .task {
                telemetry = await RouteGuardRepository.shared.getActiveTrip()
                vehicleDocs = await RouteGuardRepository.shared.getPrimaryVehicleDocs()
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: telemetry.latitude, longitude: telemetry.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                    )
                )
            }
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
                ParentAbsenceSheet(tripId: telemetry.tripId) { child in
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
                PickupAndOptSheet(canRequest: true, canApprove: false, routeId: "f0000000-0000-0000-0000-000000000001")
            }
            .sheet(isPresented: $showChatSheet) {
                InternalChatSheet()
            }
        }
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
    let onSaved: (String) -> Void
    @State private var selectedChild = "Mateo Nery"
    @State private var reason = "Cita médica"
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker(AppStrings.tr("absence_child_label"), selection: $selectedChild) {
                    Text("Mateo Nery").tag("Mateo Nery")
                    Text("Luciana Nery").tag("Luciana Nery")
                }
                Picker(AppStrings.tr("absence_reason_label"), selection: $reason) {
                    Text("Cita médica").tag("Cita médica")
                    Text("Viaje familiar").tag("Viaje familiar")
                    Text("Otro").tag("Otro")
                }
                TextField(AppStrings.tr("absence_notes_label"), text: $notes)
                Button(AppStrings.tr("absence_confirm_btn")) {
                    Task {
                        await RouteGuardRepository.shared.reportAbsence(childName: selectedChild, reason: reason, notes: notes)
                        AlertCenterStore.shared.add(title: "Ausencia Temprana", message: "\(selectedChild) no abordará hoy (\(reason)).", type: "INFO")
                        onSaved(selectedChild)
                        dismiss()
                    }
                }
            }
            .navigationTitle(AppStrings.tr("absence_title"))
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(AppStrings.tr("common_cancel")) { dismiss() } }
            }
        }
    }
}
