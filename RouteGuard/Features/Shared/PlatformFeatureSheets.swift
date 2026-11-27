import SwiftUI

struct VehicleDocsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let driverName: String
    let vehiclePlate: String
    let soatPolicy: String
    let soatInsurer: String
    let soatExpiresAt: String
    let licenseCategory: String
    @State private var verified = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(AppStrings.tr("docs_dialog_title"))) {
                    LabeledContent("Conductor", value: driverName)
                    LabeledContent(AppStrings.tr("field_plate"), value: vehiclePlate)
                    LabeledContent(AppStrings.tr("docs_soat_label"), value: "\(soatInsurer) · \(soatPolicy) (\(soatExpiresAt))")
                    LabeledContent(AppStrings.tr("docs_license_label"), value: "Lic. \(licenseCategory) · Vigente")
                }

                Section {
                    Button {
                        verified = true
                    } label: {
                        Label(AppStrings.tr("docs_verify_btn"), systemImage: "checkmark.shield.fill")
                            .foregroundStyle(AppTheme.primaryNavy)
                    }
                    if verified {
                        Text(AppStrings.tr("docs_verified_ok"))
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.emerald)
                    }
                }
            }
            .navigationTitle(AppStrings.tr("docs_dialog_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
        }
    }
}

struct TripHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trips: [TripHistoryItem] = []
    @State private var ratingTarget: TripHistoryItem?
    @State private var stars: Int = 5
    @State private var comment: String = ""
    let onRated: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.routeName).font(.subheadline.bold())
                            Spacer()
                            Text(item.status)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(item.status == "CANCELLED" ? AppTheme.errorRed.opacity(0.12) : AppTheme.emerald.opacity(0.12))
                                .foregroundStyle(item.status == "CANCELLED" ? AppTheme.errorRed : AppTheme.emerald)
                                .clipShape(Capsule())
                        }
                        Text("\(item.driverName) · \(item.vehiclePlate) · \(item.dateLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("\(item.boardedCount)/\(item.totalStudents)")
                                .font(.caption.bold())
                            Spacer()
                            if let r = item.myRating {
                                Text("★ \(r)/5").font(.caption.bold()).foregroundStyle(.orange)
                            } else if item.status != "CANCELLED" {
                                Button(AppStrings.tr("rate_btn")) {
                                    ratingTarget = item
                                }
                                .font(.caption.bold())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(AppStrings.tr("history_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
            .task {
                trips = await RouteGuardRepository.shared.getTripHistory()
            }
            .sheet(item: $ratingTarget) { target in
                NavigationStack {
                    Form {
                        Picker("Estrellas", selection: $stars) {
                            ForEach(1...5, id: \.self) { n in
                                Text("\(n) ★").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)
                        TextField(AppStrings.tr("rate_comment_label"), text: $comment)
                        Button(AppStrings.tr("rate_submit_btn")) {
                            Task {
                                await RouteGuardRepository.shared.submitRating(tripId: target.tripId, stars: stars, comment: comment)
                                onRated(stars)
                                trips = await RouteGuardRepository.shared.getTripHistory()
                                ratingTarget = nil
                            }
                        }
                    }
                    .navigationTitle(AppStrings.tr("rate_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppStrings.tr("common_cancel")) { ratingTarget = nil }
                        }
                    }
                }
            }
        }
    }
}

struct AnnouncementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let canPublish: Bool
    @State private var items: [AnnouncementItem] = []
    @State private var titleText = ""
    @State private var messageText = ""
    @State private var priority = "NORMAL"

    var body: some View {
        NavigationStack {
            List {
                if canPublish {
                    Section(header: Text(AppStrings.tr("announcements_publish_btn"))) {
                        TextField(AppStrings.tr("announcements_field_title"), text: $titleText)
                        TextField(AppStrings.tr("announcements_field_msg"), text: $messageText)
                        Picker("Prioridad", selection: $priority) {
                            Text("Normal").tag("NORMAL")
                            Text("Importante").tag("IMPORTANT")
                        }
                        .pickerStyle(.segmented)
                        Button(AppStrings.tr("announcements_publish_btn")) {
                            guard !titleText.isEmpty, !messageText.isEmpty else { return }
                            Task {
                                await RouteGuardRepository.shared.publishAnnouncement(title: titleText, message: messageText, priority: priority)
                                titleText = ""
                                messageText = ""
                                items = await RouteGuardRepository.shared.getAnnouncements()
                            }
                        }
                    }
                }
                Section {
                    if items.isEmpty {
                        Text(AppStrings.tr("announcements_empty")).foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { a in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(a.title) · \(a.priority)").font(.subheadline.bold())
                                Text(a.message).font(.caption)
                                Text(a.authorName).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.tr("announcements_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
            .task { items = await RouteGuardRepository.shared.getAnnouncements() }
        }
    }
}

struct PickupAndOptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let canRequest: Bool
    let canApprove: Bool
    let routeId: String
    @State private var childName = "Mateo Nery"
    @State private var newAddress = ""
    @State private var reason = ""
    @State private var requests: [PickupChangeItem] = []
    @State private var optimized: OptimizedStopsResponse?

    var body: some View {
        NavigationStack {
            List {
                if canRequest {
                    Section(header: Text(AppStrings.tr("pickup_submit_btn"))) {
                        TextField(AppStrings.tr("pickup_child_field"), text: $childName)
                        TextField(AppStrings.tr("pickup_address_field"), text: $newAddress)
                        TextField(AppStrings.tr("pickup_reason_field"), text: $reason)
                        Button(AppStrings.tr("pickup_submit_btn")) {
                            guard !newAddress.isEmpty else { return }
                            Task {
                                await RouteGuardRepository.shared.requestPickupChange(childName: childName, newAddress: newAddress, reason: reason)
                                newAddress = ""
                                reason = ""
                                await reload()
                            }
                        }
                    }
                }
                if let opt = optimized {
                    Section(header: Text(AppStrings.trf("opt_summary_fmt", [
                        "active": "\(opt.activeStopsCount)",
                        "total": "\(opt.totalOriginalStops)",
                        "absent": "\(opt.absentStudents.count)"
                    ]))) {
                        ForEach(opt.stops) { stop in
                            HStack {
                                Text("#\(stop.reassignedOrder ?? 0) \(stop.name)").font(.caption.bold())
                                Spacer()
                                Text(stop.status).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    ForEach(requests) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(r.childName) · \(r.status)").font(.caption.bold())
                                Text(r.newAddress).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if canApprove && r.status == "PENDING" {
                                Button(AppStrings.tr("pickup_approve_btn")) {
                                    Task {
                                        await RouteGuardRepository.shared.reviewPickupChange(id: r.id, status: "APPROVED")
                                        await reload()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.emerald)
                            }
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.tr("pickup_opt_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
            .task { await reload() }
        }
    }

    private func reload() async {
        requests = await RouteGuardRepository.shared.getPickupChanges()
        optimized = await RouteGuardRepository.shared.getOptimizedStops(routeId: routeId)
    }
}

struct InternalChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessageItem] = []
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    if messages.isEmpty {
                        Text(AppStrings.tr("chat_empty")).foregroundStyle(.secondary)
                    } else {
                        ForEach(messages) { m in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(m.senderName) (\(m.senderRole))")
                                    .font(.caption2.bold())
                                    .foregroundStyle(AppTheme.primaryNavy)
                                Text(m.message).font(.subheadline)
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField(AppStrings.tr("chat_hint"), text: $draft)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let msg = draft.trimmingCharacters(in: .whitespaces)
                        guard !msg.isEmpty else { return }
                        draft = ""
                        Task {
                            await RouteGuardRepository.shared.sendChatMessage(msg)
                            messages = await RouteGuardRepository.shared.getChatMessages()
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primaryNavy)
                }
                .padding()
            }
            .navigationTitle(AppStrings.tr("chat_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
            .task { messages = await RouteGuardRepository.shared.getChatMessages() }
        }
    }
}

struct MaintenanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let canAdd: Bool
    @State private var items: [MaintenanceItem] = []
    @State private var plate = "ABC-123"
    @State private var typeText = ""
    @State private var workshop = ""
    @State private var costText = ""

    var body: some View {
        NavigationStack {
            List {
                if canAdd {
                    Section {
                        TextField(AppStrings.tr("field_plate"), text: $plate)
                        TextField(AppStrings.tr("maintenances_type"), text: $typeText)
                        TextField(AppStrings.tr("maintenances_workshop"), text: $workshop)
                        TextField(AppStrings.tr("field_amount"), text: $costText).keyboardType(.decimalPad)
                        Button(AppStrings.tr("maintenances_add_btn")) {
                            guard !typeText.isEmpty else { return }
                            let cost = Double(costText) ?? 180.0
                            Task {
                                await RouteGuardRepository.shared.addMaintenance(plate: plate, type: typeText, workshop: workshop, cost: cost)
                                typeText = ""; workshop = ""; costText = ""
                                items = await RouteGuardRepository.shared.getMaintenances()
                            }
                        }
                    }
                }
                Section {
                    ForEach(items) { m in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(m.vehiclePlate) · \(m.maintenanceType)").font(.subheadline.bold())
                            Text("\(m.workshop) · S/ \(String(format: "%.2f", m.cost)) · \(m.performedAt)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.tr("maintenances_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
            .task { items = await RouteGuardRepository.shared.getMaintenances() }
        }
    }
}

struct ExpensesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ExpenseItem] = []
    @State private var plate = "ABC-123"
    @State private var category = "FUEL"
    @State private var details = ""
    @State private var amountText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(AppStrings.tr("field_plate"), text: $plate)
                    Picker("Categoría", selection: $category) {
                        Text("Combustible").tag("FUEL")
                        Text("Peaje").tag("TOLL")
                        Text("Cochera").tag("PARKING")
                    }
                    .pickerStyle(.segmented)
                    TextField(AppStrings.tr("field_details"), text: $details)
                    TextField(AppStrings.tr("field_amount"), text: $amountText).keyboardType(.decimalPad)
                    Button(AppStrings.tr("expenses_add_btn")) {
                        guard !details.isEmpty else { return }
                        let amount = Double(amountText) ?? 80.0
                        Task {
                            await RouteGuardRepository.shared.addExpense(plate: plate, category: category, details: details, amount: amount)
                            details = ""; amountText = ""
                            items = await RouteGuardRepository.shared.getExpenses()
                        }
                    }
                }
                Section {
                    ForEach(items) { e in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(e.vehiclePlate) · \(e.category)").font(.subheadline.bold())
                                Text(e.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("S/ \(String(format: "%.2f", e.amount))").font(.subheadline.bold())
                        }
                    }
                }
            }
            .navigationTitle(AppStrings.tr("expenses_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
            .task { items = await RouteGuardRepository.shared.getExpenses() }
        }
    }
}

struct SubscriptionPlansSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plans: [PlanItem] = []
    @State private var subscribedName: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(plans) { plan in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(plan.name).font(.headline)
                            Spacer()
                            Text("S/ \(String(format: "%.2f", plan.pricePen))/mes")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.primaryNavy)
                        }
                        Text(plan.description).font(.caption).foregroundStyle(.secondary)
                        Button(subscribedName == plan.name ? "✓ Activo" : "Seleccionar Plan") {
                            subscribedName = plan.name
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(subscribedName == plan.name ? AppTheme.emerald : AppTheme.primaryNavy)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(AppStrings.tr("sub_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
            .task { plans = await RouteGuardRepository.shared.getPlans() }
        }
    }
}
