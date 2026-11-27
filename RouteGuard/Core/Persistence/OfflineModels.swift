import Foundation
import SwiftData

@Model
final class CachedAvatarEntity {
    @Attribute(.unique) var userId: String
    var photoData: String?
    var pendingSync: Bool

    init(userId: String, photoData: String?, pendingSync: Bool = false) {
        self.userId = userId
        self.photoData = photoData
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedVehicleDocEntity {
    @Attribute(.unique) var id: String
    var plate: String
    var brand: String
    var model: String
    var capacity: Int
    var soatPolicy: String
    var soatInsurer: String
    var soatExpiresAt: String
    var soatValid: Bool

    init(
        id: String,
        plate: String,
        brand: String,
        model: String,
        capacity: Int,
        soatPolicy: String,
        soatInsurer: String,
        soatExpiresAt: String,
        soatValid: Bool
    ) {
        self.id = id
        self.plate = plate
        self.brand = brand
        self.model = model
        self.capacity = capacity
        self.soatPolicy = soatPolicy
        self.soatInsurer = soatInsurer
        self.soatExpiresAt = soatExpiresAt
        self.soatValid = soatValid
    }
}

@Model
final class CachedCaregiverEntity {
    @Attribute(.unique) var id: String
    var fullName: String
    var relationship: String
    var phoneNumber: String
    var createdAt: String
    var pendingSync: Bool

    init(id: String, fullName: String, relationship: String, phoneNumber: String, createdAt: String, pendingSync: Bool) {
        self.id = id
        self.fullName = fullName
        self.relationship = relationship
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedSupportTicketEntity {
    @Attribute(.unique) var id: String
    var ticketCode: String
    var category: String
    var subject: String
    var message: String
    var status: String
    var createdAt: String
    var pendingSync: Bool

    init(id: String, ticketCode: String, category: String, subject: String, message: String, status: String, createdAt: String, pendingSync: Bool) {
        self.id = id
        self.ticketCode = ticketCode
        self.category = category
        self.subject = subject
        self.message = message
        self.status = status
        self.createdAt = createdAt
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedAbsenceEntity {
    @Attribute(.unique) var id: String
    var childName: String
    var absenceDate: String
    var reason: String
    var notes: String
    var pendingSync: Bool

    init(id: String, childName: String, absenceDate: String, reason: String, notes: String, pendingSync: Bool) {
        self.id = id
        self.childName = childName
        self.absenceDate = absenceDate
        self.reason = reason
        self.notes = notes
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedTripHistoryEntity {
    @Attribute(.unique) var tripId: String
    var routeName: String
    var driverName: String
    var vehiclePlate: String
    var status: String
    var boardedCount: Int
    var totalStudents: Int
    var dateLabel: String
    var myRating: Int?
    var cancellationReason: String?

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
}

@Model
final class CachedMaintenanceEntity {
    @Attribute(.unique) var id: String
    var vehiclePlate: String
    var maintenanceType: String
    var details: String
    var workshop: String
    var cost: Double
    var performedAt: String
    var status: String
    var pendingSync: Bool

    init(id: String, vehiclePlate: String, maintenanceType: String, details: String, workshop: String, cost: Double, performedAt: String, status: String, pendingSync: Bool) {
        self.id = id
        self.vehiclePlate = vehiclePlate
        self.maintenanceType = maintenanceType
        self.details = details
        self.workshop = workshop
        self.cost = cost
        self.performedAt = performedAt
        self.status = status
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedExpenseEntity {
    @Attribute(.unique) var id: String
    var vehiclePlate: String
    var category: String
    var details: String
    var amount: Double
    var expenseDate: String
    var pendingSync: Bool

    init(id: String, vehiclePlate: String, category: String, details: String, amount: Double, expenseDate: String, pendingSync: Bool) {
        self.id = id
        self.vehiclePlate = vehiclePlate
        self.category = category
        self.details = details
        self.amount = amount
        self.expenseDate = expenseDate
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedAnnouncementEntity {
    @Attribute(.unique) var id: String
    var title: String
    var message: String
    var priority: String
    var authorName: String
    var createdAt: String
    var pendingSync: Bool

    init(id: String, title: String, message: String, priority: String, authorName: String, createdAt: String, pendingSync: Bool) {
        self.id = id
        self.title = title
        self.message = message
        self.priority = priority
        self.authorName = authorName
        self.createdAt = createdAt
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedPickupChangeEntity {
    @Attribute(.unique) var id: String
    var childName: String
    var newAddress: String
    var reason: String
    var status: String
    var createdAt: String
    var pendingSync: Bool

    init(id: String, childName: String, newAddress: String, reason: String, status: String, createdAt: String, pendingSync: Bool) {
        self.id = id
        self.childName = childName
        self.newAddress = newAddress
        self.reason = reason
        self.status = status
        self.createdAt = createdAt
        self.pendingSync = pendingSync
    }
}

@Model
final class CachedChatMessageEntity {
    @Attribute(.unique) var id: String
    var senderName: String
    var senderRole: String
    var message: String
    var sentAt: String
    var pendingSync: Bool

    init(id: String, senderName: String, senderRole: String, message: String, sentAt: String, pendingSync: Bool) {
        self.id = id
        self.senderName = senderName
        self.senderRole = senderRole
        self.message = message
        self.sentAt = sentAt
        self.pendingSync = pendingSync
    }
}
