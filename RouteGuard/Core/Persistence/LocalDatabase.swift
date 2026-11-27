import Foundation
import SwiftData

/// Structured offline persistence engine powered by Apple SwiftData (SQLite backed),
/// supporting full offline read/write queues and an isolated in-memory mode for XCTest.
@MainActor
final class LocalDatabase {
    static let shared = LocalDatabase(inMemory: false)

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init(inMemory: Bool) {
        let schema = Schema([
            CachedAvatarEntity.self,
            CachedVehicleDocEntity.self,
            CachedCaregiverEntity.self,
            CachedSupportTicketEntity.self,
            CachedAbsenceEntity.self,
            CachedTripHistoryEntity.self,
            CachedMaintenanceEntity.self,
            CachedExpenseEntity.self,
            CachedAnnouncementEntity.self,
            CachedPickupChangeEntity.self,
            CachedChatMessageEntity.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }

    func save() {
        try? context.save()
    }
}
