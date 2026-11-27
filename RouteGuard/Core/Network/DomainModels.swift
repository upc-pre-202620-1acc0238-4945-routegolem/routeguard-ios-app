import Foundation

struct UserAccountDto: Codable {
    let id: String
    let fullName: String
    let email: String
    let role: String
    let token: String
    let organizationId: String
    let profileId: String?
    let photoData: String?
    let preferredLanguage: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? "usr_01"
        let first = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        let last = (try? c.decode(String.self, forKey: .lastName)) ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        fullName = (try? c.decode(String.self, forKey: .fullName)) ?? (combined.isEmpty ? "Usuario RouteGuard" : combined)
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        role = (try? c.decode(String.self, forKey: .roleTier))
            ?? (try? c.decode(String.self, forKey: .role))
            ?? "PARENT"
        token = (try? c.decode(String.self, forKey: .token)) ?? ""
        organizationId = (try? c.decode(String.self, forKey: .organizationId)) ?? "org_school_01"
        profileId = try? c.decodeIfPresent(String.self, forKey: .profileId)
        photoData = try? c.decodeIfPresent(String.self, forKey: .photoData)
        preferredLanguage = try? c.decodeIfPresent(String.self, forKey: .preferredLanguage)
    }

    init(
        id: String,
        fullName: String,
        email: String,
        role: String,
        token: String,
        organizationId: String,
        profileId: String? = nil,
        photoData: String? = nil,
        preferredLanguage: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.role = role
        self.token = token
        self.organizationId = organizationId
        self.profileId = profileId
        self.photoData = photoData
        self.preferredLanguage = preferredLanguage
    }

    func withProfileId(_ pid: String?) -> UserAccountDto {
        UserAccountDto(
            id: id,
            fullName: fullName,
            email: email,
            role: role,
            token: token,
            organizationId: organizationId,
            profileId: pid ?? profileId,
            photoData: photoData,
            preferredLanguage: preferredLanguage
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fullName, forKey: .fullName)
        try c.encode(email, forKey: .email)
        try c.encode(role, forKey: .role)
        try c.encode(token, forKey: .token)
        try c.encode(organizationId, forKey: .organizationId)
        try c.encodeIfPresent(profileId, forKey: .profileId)
        try c.encodeIfPresent(photoData, forKey: .photoData)
        try c.encodeIfPresent(preferredLanguage, forKey: .preferredLanguage)
    }

    enum CodingKeys: String, CodingKey {
        case id, fullName, firstName, lastName, email, role, roleTier, token, organizationId, profileId, photoData, preferredLanguage
    }
}

struct StopDto: Identifiable, Decodable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let order: Int
    let isReached: Bool

    init(
        id: String,
        name: String,
        address: String = "",
        latitude: Double,
        longitude: Double,
        order: Int,
        isReached: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address.isEmpty ? name : address
        self.latitude = latitude
        self.longitude = longitude
        self.order = order
        self.isReached = isReached
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let ord = (try? c.decode(Int.self, forKey: .order))
            ?? (try? c.decode(Int.self, forKey: .orderIndex))
            ?? 1
        id = (try? c.decode(String.self, forKey: .id)) ?? "stp_\(ord)"
        let decodedName = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .studentName))
            ?? "Parada #\(ord)"
        name = decodedName
        let decodedAddr = (try? c.decode(String.self, forKey: .address)) ?? ""
        address = decodedAddr.isEmpty ? decodedName : decodedAddr
        latitude = (try? c.decode(Double.self, forKey: .latitude)) ?? -12.0920
        longitude = (try? c.decode(Double.self, forKey: .longitude)) ?? -77.0280
        order = ord
        isReached = (try? c.decode(Bool.self, forKey: .reached))
            ?? (try? c.decode(Bool.self, forKey: .isPickedUp))
            ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, studentName, address, latitude, longitude, order, orderIndex, reached, isPickedUp
    }
}

struct LiveChildDto: Identifiable, Decodable {
    var id: String { childId }
    let childId: String
    let name: String
    let boardingState: String

    init(childId: String, name: String, boardingState: String = "MISSING") {
        self.childId = childId
        self.name = name
        self.boardingState = boardingState
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        childId = (try? c.decode(String.self, forKey: .childId))
            ?? (try? c.decode(String.self, forKey: .id))
            ?? UUID().uuidString
        let first = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        let last = (try? c.decode(String.self, forKey: .lastName)) ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .fullName))
            ?? (combined.isEmpty ? "Estudiante" : combined)
        boardingState = ((try? c.decode(String.self, forKey: .boardingState)) ?? "MISSING").uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case childId, id, name, fullName, firstName, lastName, boardingState
    }
}

struct LiveTripTelemetryDto: Decodable {
    let tripId: String
    let routeId: String?
    let routeName: String
    let driverName: String
    let vehiclePlate: String
    let latitude: Double
    let longitude: Double
    let speedKmh: Double
    let status: String
    let boardedCount: Int
    let totalStudents: Int
    let nextStopName: String?
    let vehicleModel: String?
    let driverPhone: String?
    let driverLicense: String?
    let driverLicenseCategory: String?
    let soatPolicy: String?
    let soatInsurer: String?
    let soatExpiresAt: String?
    let stops: [StopDto]
    let children: [LiveChildDto]

    init(
        tripId: String = "TRP-2026-08",
        routeId: String? = "f0000000-0000-0000-0000-000000000001",
        routeName: String = "Ruta San Martín - Turno Mañana",
        driverName: String = "Carlos Ramirez",
        vehiclePlate: String = "ABC-123",
        latitude: Double = -12.0920,
        longitude: Double = -77.0280,
        speedKmh: Double = 32.5,
        status: String = "EN_RUTA",
        boardedCount: Int = 6,
        totalStudents: Int = 14,
        nextStopName: String? = nil,
        vehicleModel: String? = "Mercedes-Benz Sprinter 416",
        driverPhone: String? = "+51 987 654 321",
        driverLicense: String? = "Q-44556677",
        driverLicenseCategory: String? = "A-IIIa",
        soatPolicy: String? = "SOAT-2026-88412",
        soatInsurer: String? = "Rímac Seguros",
        soatExpiresAt: String? = "15/12/2026",
        stops: [StopDto] = [
            StopDto(id: "s1", name: "Colegio San Martín", latitude: -12.0464, longitude: -77.0428, order: 1, isReached: true),
            StopDto(id: "s2", name: "Parque Kennedy", latitude: -12.1211, longitude: -77.0297, order: 2, isReached: false),
            StopDto(id: "s3", name: "Plaza San Miguel", latitude: -12.0776, longitude: -77.0824, order: 3, isReached: false)
        ],
        children: [LiveChildDto] = []
    ) {
        self.tripId = tripId
        self.routeId = routeId
        self.routeName = routeName
        self.driverName = driverName
        self.vehiclePlate = vehiclePlate
        self.latitude = latitude
        self.longitude = longitude
        self.speedKmh = speedKmh
        self.status = status
        self.boardedCount = boardedCount
        self.totalStudents = totalStudents
        self.nextStopName = nextStopName
        self.vehicleModel = vehicleModel
        self.driverPhone = driverPhone
        self.driverLicense = driverLicense
        self.driverLicenseCategory = driverLicenseCategory
        self.soatPolicy = soatPolicy
        self.soatInsurer = soatInsurer
        self.soatExpiresAt = soatExpiresAt
        self.stops = stops
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tripId = (try? c.decode(String.self, forKey: .tripId))
            ?? (try? c.decode(String.self, forKey: .id))
            ?? "TRP-2026-08"
        routeId = try? c.decodeIfPresent(String.self, forKey: .routeId)
        routeName = (try? c.decode(String.self, forKey: .routeName)) ?? "Ruta San Martín - Turno Mañana"
        driverName = (try? c.decode(String.self, forKey: .driverName)) ?? "Carlos Ramirez"
        vehiclePlate = (try? c.decode(String.self, forKey: .vehiclePlate)) ?? "ABC-123"
        let decodedStops = ((try? c.decode([StopDto].self, forKey: .stops)) ?? []).sorted { $0.order < $1.order }
        stops = decodedStops
        children = (try? c.decode([LiveChildDto].self, forKey: .children)) ?? []

        if let loc = try? c.decodeIfPresent(LocationSubDto.self, forKey: .location) {
            latitude = loc.latitude
            longitude = loc.longitude
            speedKmh = loc.speedKmh
        } else {
            latitude = (try? c.decode(Double.self, forKey: .latitude))
                ?? decodedStops.first?.latitude
                ?? -12.0920
            longitude = (try? c.decode(Double.self, forKey: .longitude))
                ?? decodedStops.first?.longitude
                ?? -77.0280
            speedKmh = (try? c.decode(Double.self, forKey: .speedKmh)) ?? 28.0
        }
        status = (try? c.decode(String.self, forKey: .status)) ?? "IN_PROGRESS"
        boardedCount = (try? c.decode(Int.self, forKey: .boardedCount))
            ?? (try? c.decode(Int.self, forKey: .onboardStudents))
            ?? children.filter { $0.boardingState == "BOARDED" }.count
        totalStudents = (try? c.decode(Int.self, forKey: .totalStudents))
            ?? (try? c.decode(Int.self, forKey: .totalChildren))
            ?? max(children.count, 1)
        nextStopName = (try? c.decodeIfPresent(String.self, forKey: .nextStopName))
            ?? decodedStops.first(where: { !$0.isReached })?.name
        vehicleModel = try? c.decodeIfPresent(String.self, forKey: .vehicleModel)
        driverPhone = try? c.decodeIfPresent(String.self, forKey: .driverPhone)
        driverLicense = try? c.decodeIfPresent(String.self, forKey: .driverLicense)
        driverLicenseCategory = try? c.decodeIfPresent(String.self, forKey: .driverLicenseCategory)
        soatPolicy = try? c.decodeIfPresent(String.self, forKey: .soatPolicy)
        soatInsurer = try? c.decodeIfPresent(String.self, forKey: .soatInsurer)
        soatExpiresAt = try? c.decodeIfPresent(String.self, forKey: .soatExpiresAt)
    }

    struct LocationSubDto: Decodable {
        let latitude: Double
        let longitude: Double
        let speedKmh: Double
    }

    enum CodingKeys: String, CodingKey {
        case id, tripId, routeId, routeName, driverName, vehiclePlate, latitude, longitude, speedKmh, location, status
        case boardedCount, onboardStudents, totalStudents, totalChildren, nextStopName
        case vehicleModel, driverPhone, driverLicense, driverLicenseCategory, soatPolicy, soatInsurer, soatExpiresAt
        case stops, children
    }
}

struct ParentActiveTripResult {
    let hasActiveTrip: Bool
    let telemetry: LiveTripTelemetryDto?
    let isOfflineFallback: Bool
}

struct DriverActiveTripResult {
    let hasActiveTrip: Bool
    let tripId: String?
    let routeId: String?
    let routeName: String
    let vehiclePlate: String
    let latitude: Double
    let longitude: Double
    let speedKmh: Double
    let stops: [StopDto]
    let passengers: [DriverPassengerItem]
    let assignedRoutes: [RouteSummaryItem]
    let isOfflineFallback: Bool
}

struct VehicleDto: Codable, Identifiable {
    let id: String
    let plate: String
    let brand: String
    let model: String
    let capacity: Int
    let soatPolicy: String
    let soatInsurer: String
    let soatExpiresAt: String
    let soatValid: Bool
}

struct CaregiverItem: Identifiable, Codable {
    let id: String
    let fullName: String
    let relationship: String
    let phoneNumber: String
    let createdAt: String
}

struct SupportTicketItem: Identifiable, Codable {
    let id: String
    let ticketCode: String
    let category: String
    let subject: String
    let message: String
    let status: String
    let createdAt: String
}

struct TripHistoryItem: Identifiable, Decodable {
    var id: String { tripId }
    let tripId: String
    let routeName: String
    let driverName: String
    let vehiclePlate: String
    let status: String
    let boardedCount: Int
    let totalStudents: Int
    let dateLabel: String
    var myRating: Int?
    let cancellationReason: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tripId = (try? c.decode(String.self, forKey: .tripId)) ?? UUID().uuidString
        routeName = (try? c.decode(String.self, forKey: .routeName)) ?? "Ruta Escolar"
        driverName = (try? c.decode(String.self, forKey: .driverName)) ?? "Carlos Ramirez"
        vehiclePlate = (try? c.decode(String.self, forKey: .vehiclePlate)) ?? "ABC-123"
        status = (try? c.decode(String.self, forKey: .status)) ?? "COMPLETED"
        boardedCount = (try? c.decode(Int.self, forKey: .boardedCount)) ?? 14
        totalStudents = (try? c.decode(Int.self, forKey: .totalStudents)) ?? 14
        dateLabel = (try? c.decode(String.self, forKey: .dateEs))
            ?? (try? c.decode(String.self, forKey: .startTime))
            ?? "Hoy"
        myRating = try? c.decodeIfPresent(Int.self, forKey: .myRating)
        cancellationReason = try? c.decodeIfPresent(String.self, forKey: .cancellationReason)
    }

    init(
        tripId: String,
        routeName: String,
        driverName: String,
        vehiclePlate: String,
        status: String,
        boardedCount: Int,
        totalStudents: Int,
        dateLabel: String,
        myRating: Int? = nil,
        cancellationReason: String? = nil
    ) {
        self.tripId = tripId
        self.routeName = routeName
        self.driverName = driverName
        self.vehiclePlate = vehiclePlate
        self.status = status
        self.boardedCount = boardedCount
        self.totalStudents = totalStudents
        self.dateLabel = dateLabel
        self.myRating = myRating
        self.cancellationReason = cancellationReason
    }

    enum CodingKeys: String, CodingKey {
        case tripId, routeName, driverName, vehiclePlate, status, boardedCount, totalStudents, dateEs, startTime, myRating, cancellationReason
    }
}

struct MaintenanceItem: Identifiable, Codable {
    let id: String
    let vehiclePlate: String
    let maintenanceType: String
    let description: String
    let workshop: String
    let cost: Double
    let performedAt: String
    let status: String
}

struct ExpenseItem: Identifiable, Codable {
    let id: String
    let vehiclePlate: String
    let category: String
    let description: String
    let amount: Double
    let expenseDate: String
}

struct AnnouncementItem: Identifiable, Codable {
    let id: String
    let title: String
    let message: String
    let priority: String
    let authorName: String
    let createdAt: String
}

struct PickupChangeItem: Identifiable, Codable {
    let id: String
    let childName: String
    let newAddress: String
    let reason: String
    let status: String
    let createdAt: String
}

struct OptimizedStopsResponse: Codable {
    let activeStopsCount: Int
    let totalOriginalStops: Int
    let absentStudents: [String]
    let stops: [OptimizedStopItem]
}

struct OptimizedStopItem: Identifiable, Codable {
    var id: String { "\(stopId)-\(name)" }
    let stopId: String
    let name: String
    let status: String
    let reassignedOrder: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stopId = (try? c.decode(String.self, forKey: .stopId)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? "ACTIVE"
        reassignedOrder = try? c.decodeIfPresent(Int.self, forKey: .reassignedOrder)
    }

    enum CodingKeys: String, CodingKey {
        case stopId, name, status, reassignedOrder
    }
}

struct ChatMessageItem: Identifiable, Codable {
    let id: String
    let senderName: String
    let senderRole: String
    let message: String
    let sentAt: String
}

struct RouteSummaryItem: Identifiable, Decodable {
    let id: String
    let name: String
    let status: String
    let vehiclePlate: String
    let stopsCount: Int
    let driverId: String?
    let stops: [StopDto]

    struct VehicleSubDto: Decodable {
        let licensePlate: String?
        let plate: String?
    }

    struct AssignmentSubDto: Decodable {
        let driverId: String?
        let driverName: String?
        let childIds: [String]?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Ruta Escolar"
        status = ((try? c.decode(String.self, forKey: .state))
            ?? (try? c.decode(String.self, forKey: .status))
            ?? "ACTIVE").uppercased()
        let vehicle = try? c.decodeIfPresent(VehicleSubDto.self, forKey: .vehicle)
        let assignment = try? c.decodeIfPresent(AssignmentSubDto.self, forKey: .assignment)
        vehiclePlate = vehicle?.licensePlate
            ?? vehicle?.plate
            ?? (try? c.decode(String.self, forKey: .vehiclePlate))
            ?? "ABC-123"
        let decodedStops = ((try? c.decode([StopDto].self, forKey: .stops)) ?? []).sorted { $0.order < $1.order }
        stops = decodedStops
        stopsCount = (try? c.decode(Int.self, forKey: .stopsCount))
            ?? (decodedStops.isEmpty ? 3 : decodedStops.count)
        driverId = assignment?.driverId
    }

    init(id: String, name: String, status: String, vehiclePlate: String, stopsCount: Int, driverId: String? = nil, stops: [StopDto] = []) {
        self.id = id
        self.name = name
        self.status = status
        self.vehiclePlate = vehiclePlate
        self.stopsCount = stopsCount
        self.driverId = driverId
        self.stops = stops
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, state, vehiclePlate, vehicle, assignment, stopsCount, stops
    }
}

struct SafetyAlertItem: Identifiable {
    let id: String
    let title: String
    let message: String
    let type: String
    let timestamp: String
    let tripId: String?
    let deliveryState: String
    let hasPanicAlert: Bool
    let sentAtDate: Date?

    init(
        id: String,
        title: String,
        message: String,
        type: String,
        timestamp: String,
        tripId: String? = nil,
        deliveryState: String = "DELIVERED",
        hasPanicAlert: Bool = false,
        sentAtDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.timestamp = timestamp
        self.tripId = tripId
        self.deliveryState = deliveryState
        self.hasPanicAlert = hasPanicAlert
        self.sentAtDate = sentAtDate
    }

    var isPanic: Bool {
        let up = type.uppercased()
        return hasPanicAlert || up == "PANIC" || up == "PANIC_ALERT"
    }

    var isHighPriority: Bool {
        let up = type.uppercased()
        return isPanic || up == "INCIDENT_REPORTED" || up == "TRAFFIC"
    }
}

struct NotificationApiDto: Decodable {
    let id: String
    let tripId: String?
    let category: String
    let deliveryState: String
    let message: String
    let sentAt: String?
    let alerts: [AlertFlagDto]?

    struct AlertFlagDto: Decodable {
        let panic: Bool?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        tripId = try? c.decodeIfPresent(String.self, forKey: .tripId)
        category = ((try? c.decode(String.self, forKey: .category))
            ?? (try? c.decode(String.self, forKey: .type))
            ?? "GENERAL").uppercased()
        deliveryState = ((try? c.decode(String.self, forKey: .deliveryState)) ?? "DELIVERED").uppercased()
        message = (try? c.decode(String.self, forKey: .message))
            ?? (try? c.decode(String.self, forKey: .body))
            ?? ""
        sentAt = (try? c.decodeIfPresent(String.self, forKey: .sentAt))
            ?? (try? c.decodeIfPresent(String.self, forKey: .createdAt))
        alerts = try? c.decodeIfPresent([AlertFlagDto].self, forKey: .alerts)
    }

    enum CodingKeys: String, CodingKey {
        case id, tripId, category, type, deliveryState, message, body, sentAt, createdAt, alerts
    }
}

struct DriverTripApiDto: Decodable {
    let id: String
    let routeId: String?
    let driverId: String?
    let tripState: String
    let startTime: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id))
            ?? (try? c.decode(String.self, forKey: .tripId))
            ?? ""
        routeId = try? c.decodeIfPresent(String.self, forKey: .routeId)
        driverId = try? c.decodeIfPresent(String.self, forKey: .driverId)
        tripState = ((try? c.decode(String.self, forKey: .tripState))
            ?? (try? c.decode(String.self, forKey: .status))
            ?? "").uppercased()
        startTime = try? c.decodeIfPresent(String.self, forKey: .startTime)
    }

    enum CodingKeys: String, CodingKey {
        case id, tripId, routeId, driverId, tripState, status, startTime
    }
}

struct ParentProfileDto: Identifiable, Decodable {
    let id: String
    let userId: String?
    let fullName: String
    let children: [LiveChildDto]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        userId = try? c.decodeIfPresent(String.self, forKey: .userId)
        let first = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        let last = (try? c.decode(String.self, forKey: .lastName)) ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        fullName = (try? c.decode(String.self, forKey: .fullName)) ?? (combined.isEmpty ? "Apoderado" : combined)
        children = (try? c.decode([LiveChildDto].self, forKey: .children)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, firstName, lastName, fullName, children
    }
}

struct DriverProfileDto: Identifiable, Decodable {
    let id: String
    let userId: String?
    let fullName: String
    let licenseNumber: String
    let vehiclePlate: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        userId = try? c.decodeIfPresent(String.self, forKey: .userId)
        let first = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        let last = (try? c.decode(String.self, forKey: .lastName)) ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        fullName = (try? c.decode(String.self, forKey: .fullName)) ?? (combined.isEmpty ? "Conductor" : combined)
        licenseNumber = (try? c.decode(String.self, forKey: .licenseNumber)) ?? "Q-44556677"
        vehiclePlate = (try? c.decode(String.self, forKey: .vehiclePlate)) ?? "ABC-123"
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, firstName, lastName, fullName, licenseNumber, vehiclePlate
    }
}

enum BoardingState: String {
    case pending
    case boarded
    case absent
}

struct DriverPassengerItem: Identifiable {
    let id: String
    let name: String
    let grade: String
    let stopAddress: String
    let scheduledTime: String
    var status: BoardingState
}

struct PlanItem: Identifiable, Decodable {
    let id: String
    let name: String
    let pricePen: Double
    let maxRoutes: Int
    let description: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Plan"
        pricePen = (try? c.decode(Double.self, forKey: .price)) ?? (try? c.decode(Double.self, forKey: .monthlyPrice)) ?? 49.99
        maxRoutes = (try? c.decode(Int.self, forKey: .maxRoutes)) ?? 1
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
    }

    init(id: String, name: String, pricePen: Double, maxRoutes: Int, description: String) {
        self.id = id
        self.name = name
        self.pricePen = pricePen
        self.maxRoutes = maxRoutes
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case id, name, price, monthlyPrice, maxRoutes, description
    }
}
