import Foundation

struct UserAccountDto: Codable {
    let id: String
    let fullName: String
    let email: String
    let role: String
    let token: String
    let organizationId: String
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
        photoData = try? c.decodeIfPresent(String.self, forKey: .photoData)
        preferredLanguage = try? c.decodeIfPresent(String.self, forKey: .preferredLanguage)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fullName, forKey: .fullName)
        try c.encode(email, forKey: .email)
        try c.encode(role, forKey: .role)
        try c.encode(token, forKey: .token)
        try c.encode(organizationId, forKey: .organizationId)
        try c.encodeIfPresent(photoData, forKey: .photoData)
        try c.encodeIfPresent(preferredLanguage, forKey: .preferredLanguage)
    }

    enum CodingKeys: String, CodingKey {
        case id, fullName, firstName, lastName, email, role, roleTier, token, organizationId, photoData, preferredLanguage
    }
}

struct LiveTripTelemetryDto: Codable {
    let tripId: String
    let routeName: String
    let driverName: String
    let vehiclePlate: String
    let latitude: Double
    let longitude: Double
    let speedKmh: Double
    let status: String
    let boardedCount: Int
    let totalStudents: Int
    let vehicleModel: String?
    let driverPhone: String?
    let driverLicense: String?
    let driverLicenseCategory: String?
    let soatPolicy: String?
    let soatInsurer: String?
    let soatExpiresAt: String?

    init(
        tripId: String = "TRP-2026-08",
        routeName: String = "Ruta San Martín - Turno Mañana",
        driverName: String = "Carlos Ramirez",
        vehiclePlate: String = "ABC-123",
        latitude: Double = -12.0920,
        longitude: Double = -77.0280,
        speedKmh: Double = 32.5,
        status: String = "EN_RUTA",
        boardedCount: Int = 6,
        totalStudents: Int = 14,
        vehicleModel: String? = "Mercedes-Benz Sprinter 416",
        driverPhone: String? = "+51 987 654 321",
        driverLicense: String? = "Q-44556677",
        driverLicenseCategory: String? = "A-IIIa",
        soatPolicy: String? = "SOAT-2026-88412",
        soatInsurer: String? = "Rímac Seguros",
        soatExpiresAt: String? = "15/12/2026"
    ) {
        self.tripId = tripId
        self.routeName = routeName
        self.driverName = driverName
        self.vehiclePlate = vehiclePlate
        self.latitude = latitude
        self.longitude = longitude
        self.speedKmh = speedKmh
        self.status = status
        self.boardedCount = boardedCount
        self.totalStudents = totalStudents
        self.vehicleModel = vehicleModel
        self.driverPhone = driverPhone
        self.driverLicense = driverLicense
        self.driverLicenseCategory = driverLicenseCategory
        self.soatPolicy = soatPolicy
        self.soatInsurer = soatInsurer
        self.soatExpiresAt = soatExpiresAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tripId = (try? c.decode(String.self, forKey: .tripId)) ?? "TRP-2026-08"
        routeName = (try? c.decode(String.self, forKey: .routeName)) ?? "Ruta San Martín - Turno Mañana"
        driverName = (try? c.decode(String.self, forKey: .driverName)) ?? "Carlos Ramirez"
        vehiclePlate = (try? c.decode(String.self, forKey: .vehiclePlate)) ?? "ABC-123"
        if let loc = try? c.decodeIfPresent(LocationSubDto.self, forKey: .location) {
            latitude = loc.latitude
            longitude = loc.longitude
            speedKmh = loc.speedKmh
        } else {
            latitude = (try? c.decode(Double.self, forKey: .latitude)) ?? -12.0920
            longitude = (try? c.decode(Double.self, forKey: .longitude)) ?? -77.0280
            speedKmh = (try? c.decode(Double.self, forKey: .speedKmh)) ?? 32.5
        }
        status = (try? c.decode(String.self, forKey: .status)) ?? "EN_RUTA"
        boardedCount = (try? c.decode(Int.self, forKey: .boardedCount))
            ?? (try? c.decode(Int.self, forKey: .onboardStudents))
            ?? 6
        totalStudents = (try? c.decode(Int.self, forKey: .totalStudents))
            ?? (try? c.decode(Int.self, forKey: .totalChildren))
            ?? 14
        vehicleModel = try? c.decodeIfPresent(String.self, forKey: .vehicleModel)
        driverPhone = try? c.decodeIfPresent(String.self, forKey: .driverPhone)
        driverLicense = try? c.decodeIfPresent(String.self, forKey: .driverLicense)
        driverLicenseCategory = try? c.decodeIfPresent(String.self, forKey: .driverLicenseCategory)
        soatPolicy = try? c.decodeIfPresent(String.self, forKey: .soatPolicy)
        soatInsurer = try? c.decodeIfPresent(String.self, forKey: .soatInsurer)
        soatExpiresAt = try? c.decodeIfPresent(String.self, forKey: .soatExpiresAt)
    }

    struct LocationSubDto: Codable {
        let latitude: Double
        let longitude: Double
        let speedKmh: Double
    }

    enum CodingKeys: String, CodingKey {
        case tripId, routeName, driverName, vehiclePlate, latitude, longitude, speedKmh, location, status
        case boardedCount, onboardStudents, totalStudents, totalChildren
        case vehicleModel, driverPhone, driverLicense, driverLicenseCategory, soatPolicy, soatInsurer, soatExpiresAt
    }
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

struct TripHistoryItem: Identifiable, Codable {
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

struct RouteSummaryItem: Identifiable, Codable {
    let id: String
    let name: String
    let status: String
    let vehiclePlate: String
    let stopsCount: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Ruta Escolar"
        status = (try? c.decode(String.self, forKey: .status)) ?? "ACTIVE"
        vehiclePlate = (try? c.decode(String.self, forKey: .vehiclePlate)) ?? "ABC-123"
        stopsCount = (try? c.decode(Int.self, forKey: .stopsCount)) ?? 3
    }

    init(id: String, name: String, status: String, vehiclePlate: String, stopsCount: Int) {
        self.id = id
        self.name = name
        self.status = status
        self.vehiclePlate = vehiclePlate
        self.stopsCount = stopsCount
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, vehiclePlate, stopsCount
    }
}

struct SafetyAlertItem: Identifiable {
    let id: String
    let title: String
    let message: String
    let type: String
    let timestamp: String
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

struct PlanItem: Identifiable, Codable {
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
