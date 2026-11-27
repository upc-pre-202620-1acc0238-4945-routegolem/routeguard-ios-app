import Foundation
import MapKit
import SwiftData

@MainActor
enum RoadRoutingHelper {
    private static var cache: [String: [CLLocationCoordinate2D]] = [:]

    static func fetchRoadCoordinates(for waypoints: [CLLocationCoordinate2D]) async -> [CLLocationCoordinate2D] {
        var cleaned: [CLLocationCoordinate2D] = []
        for pt in waypoints {
            if let last = cleaned.last {
                if abs(last.latitude - pt.latitude) < 0.00001 && abs(last.longitude - pt.longitude) < 0.00001 {
                    continue
                }
            }
            cleaned.append(pt)
        }
        guard cleaned.count >= 2 else { return cleaned }

        let key = cleaned.map { String(format: "%.5f,%.5f", $0.latitude, $0.longitude) }.joined(separator: ";")
        if let hit = cache[key] { return hit }

        // Primary: native Apple MapKit MKDirections chained between consecutive stops
        var stitched: [CLLocationCoordinate2D] = []
        var usedDirections = true
        for i in 0..<(cleaned.count - 1) {
            let src = MKPlacemark(coordinate: cleaned[i])
            let dst = MKPlacemark(coordinate: cleaned[i + 1])
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: src)
            request.destination = MKMapItem(placemark: dst)
            request.transportType = .automobile

            do {
                let response = try await MKDirections(request: request).calculate()
                if let route = response.routes.first, route.polyline.pointCount >= 2 {
                    let count = route.polyline.pointCount
                    var coords = Array(repeating: CLLocationCoordinate2D(), count: count)
                    route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
                    if !stitched.isEmpty && !coords.isEmpty {
                        coords.removeFirst()
                    }
                    stitched.append(contentsOf: coords)
                } else {
                    usedDirections = false
                    break
                }
            } catch {
                usedDirections = false
                break
            }
        }
        if usedDirections && stitched.count >= 2 {
            cache[key] = stitched
            return stitched
        }

        // Secondary: OSRM driving router fallback
        let osrmCoords = cleaned.map { "\($0.longitude),\($0.latitude)" }.joined(separator: ";")
        if let url = URL(string: "https://router.project-osrm.org/route/v1/driving/\(osrmCoords)?overview=full&geometries=geojson") {
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 6.0
                let (data, res) = try await URLSession.shared.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let routes = json["routes"] as? [[String: Any]],
                   let first = routes.first,
                   let geometry = first["geometry"] as? [String: Any],
                   let coords = geometry["coordinates"] as? [[Double]] {
                    let path = coords.compactMap { pair -> CLLocationCoordinate2D? in
                        guard pair.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                    }
                    if path.count >= 2 {
                        cache[key] = path
                        return path
                    }
                }
            } catch {}
        }

        return cleaned
    }
}

@MainActor
final class RouteGuardRepository {
    static let shared = RouteGuardRepository()

    private let session: URLSession
    private let db: LocalDatabase
    private let store: SessionStore

    init(
        urlSession: URLSession? = nil,
        database: LocalDatabase? = nil,
        sessionStore: SessionStore? = nil
    ) {
        if let urlSession {
            self.session = urlSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = ApiConstants.requestTimeout
            self.session = URLSession(configuration: config)
        }
        self.db = database ?? .shared
        self.store = sessionStore ?? .shared
    }

    private func isLiveToken(_ token: String? = nil) -> Bool {
        let t = token ?? store.token
        return !t.isEmpty &&
            !t.hasPrefix("offline_ios_token_") &&
            !t.hasPrefix("ios_local_") &&
            !t.hasPrefix("mock_") &&
            !t.hasPrefix("mock-") &&
            !t.hasPrefix("demo-")
    }

    private func makeRequest(path: String, method: String = "GET", body: [String: Any]? = nil, includeAuth: Bool = true, authToken: String? = nil) -> URLRequest? {
        guard let url = URL(string: "\(ApiConstants.baseUrl)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(AppStrings.shared.currentLanguage.rawValue, forHTTPHeaderField: "Accept-Language")
        let tok = authToken ?? store.token
        if includeAuth, !tok.isEmpty {
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    private func todayIso() -> String {
        ISO8601DateFormatter().string(from: Date()).prefix(10).description
    }

    private func nowIso() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    // MARK: - Auth & Password Recovery (US-01, US-19)

    func signIn(email: String, password: String) async throws -> UserAccountDto {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let req = makeRequest(path: "/users/sign-in", method: "POST", body: ["email": cleanEmail, "password": password], includeAuth: false) {
            do {
                let (data, response) = try await session.data(for: req)
                if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode) {
                        var account = try JSONDecoder().decode(UserAccountDto.self, from: data)
                        if let photo = account.photoData {
                            saveAvatarLocally(userId: account.id, photoData: photo, pendingSync: false)
                        }
                        if isLiveToken(account.token) {
                            let roleNorm = UserRole.normalize(account.role)
                            if let pid = await resolveProfileId(role: roleNorm, userId: account.id, token: account.token) {
                                account = account.withProfileId(pid)
                            }
                        }
                        return account
                    }
                    if http.statusCode == 401 {
                        throw NSError(domain: "RouteGuardAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Credenciales incorrectas"])
                    }
                }
            } catch let err as NSError where err.domain == "RouteGuardAuth" {
                throw err
            } catch {
                // Offline fallback for demo verification
            }
        }
        guard password.count >= 6 else {
            throw NSError(domain: "RouteGuardAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Mínimo 6 caracteres"])
        }
        let demoRole: UserRole = cleanEmail.contains("admin") ? .administrator : (cleanEmail.contains("driver") ? .driver : .parent)
        let name = demoRole == .administrator ? "Administrador Flota" : (demoRole == .driver ? "Carlos Ramirez" : "Rosita Nery")
        let fallbackJson: [String: Any] = [
            "id": "usr_\(demoRole.rawValue.lowercased())",
            "fullName": name,
            "email": cleanEmail,
            "role": demoRole.rawValue,
            "token": "offline_ios_token_\(demoRole.rawValue.lowercased())",
            "organizationId": "org_school_01"
        ]
        let raw = try JSONSerialization.data(withJSONObject: fallbackJson)
        return try JSONDecoder().decode(UserAccountDto.self, from: raw)
    }

    func requestPasswordReset(email: String) async -> String? {
        guard let req = makeRequest(path: "/users/forgot-password", method: "POST", body: ["email": email.trimmingCharacters(in: .whitespaces)], includeAuth: false) else {
            return nil
        }
        do {
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj["devCode"] as? String
            }
        } catch {}
        return nil
    }

    func confirmPasswordReset(email: String, code: String, newPassword: String) async -> Bool {
        guard let req = makeRequest(
            path: "/users/reset-password",
            method: "POST",
            body: ["email": email.trimmingCharacters(in: .whitespaces), "code": code.trimmingCharacters(in: .whitespaces), "newPassword": newPassword],
            includeAuth: false
        ) else { return false }
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }

    // MARK: - Profile Photo & Language (US-10 + DB Sync)

    func saveAvatarLocally(userId: String, photoData: String?, pendingSync: Bool) {
        let desc = FetchDescriptor<CachedAvatarEntity>(predicate: #Predicate { $0.userId == userId })
        if let existing = try? db.context.fetch(desc).first {
            existing.photoData = photoData
            existing.pendingSync = pendingSync
        } else {
            db.context.insert(CachedAvatarEntity(userId: userId, photoData: photoData, pendingSync: pendingSync))
        }
        db.save()
    }

    func loadMyPhoto() async -> String? {
        let uid = store.userId.isEmpty ? "default" : store.userId
        let desc = FetchDescriptor<CachedAvatarEntity>(predicate: #Predicate { $0.userId == uid })
        let cached = try? db.context.fetch(desc).first

        if let req = makeRequest(path: "/users/me") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let remote = obj["photoData"] as? String
                    if cached?.pendingSync == true {
                        return cached?.photoData
                    }
                    saveAvatarLocally(userId: uid, photoData: remote, pendingSync: false)
                    return remote
                }
            } catch {}
        }
        return cached?.photoData
    }

    func saveMyPhoto(_ photoData: String?) async {
        let uid = store.userId.isEmpty ? "default" : store.userId
        saveAvatarLocally(userId: uid, photoData: photoData, pendingSync: true)
        var body: [String: Any] = [:]
        if let photoData { body["photoData"] = photoData }
        if let req = makeRequest(path: "/users/me/photo", method: "PUT", body: body) {
            do {
                let (_, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    saveAvatarLocally(userId: uid, photoData: photoData, pendingSync: false)
                }
            } catch {}
        }
    }

    func syncLanguage(_ code: String) async {
        guard let req = makeRequest(path: "/users/me/language", method: "PUT", body: ["language": code]) else { return }
        _ = try? await session.data(for: req)
    }

    // MARK: - Live Tracking, SOAT & History (US-06, US-12, US-15, US-09, US-14, US-21)

    func resolveProfileId(role: UserRole? = nil, userId: String? = nil, token: String? = nil) async -> String? {
        let targetRole = role ?? store.role
        let targetUid = userId ?? store.userId
        let tok = token ?? store.token
        guard isLiveToken(tok), targetRole == .parent || targetRole == .driver else { return nil }
        let path = targetRole == .parent ? "/parents" : "/drivers"
        guard let req = makeRequest(path: path, authToken: tok) else { return nil }
        do {
            let (data, res) = try await session.data(for: req)
            guard let http = res as? HTTPURLResponse, http.statusCode == 200,
                  let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }
            if !targetUid.isEmpty,
               let matched = list.first(where: { ($0["userId"] as? String) == targetUid }),
               let pid = matched["id"] as? String {
                return pid
            }
            if list.count == 1, let pid = list.first?["id"] as? String {
                return pid
            }
        } catch {}
        return nil
    }

    func getParentActiveTrip() async -> ParentActiveTripResult {
        guard isLiveToken() else {
            return ParentActiveTripResult(hasActiveTrip: true, telemetry: LiveTripTelemetryDto(), isOfflineFallback: true)
        }
        var pid = store.profileId
        if pid.isEmpty, let resolved = await resolveProfileId(role: .parent) {
            pid = resolved
            store.setProfileId(resolved)
        }
        guard !pid.isEmpty, let req = makeRequest(path: "/parents/\(pid)/active-trip") else {
            return ParentActiveTripResult(hasActiveTrip: true, telemetry: LiveTripTelemetryDto(), isOfflineFallback: true)
        }
        do {
            let (data, res) = try await session.data(for: req)
            if let http = res as? HTTPURLResponse {
                if http.statusCode == 204 {
                    return ParentActiveTripResult(hasActiveTrip: false, telemetry: nil, isOfflineFallback: false)
                }
                if http.statusCode == 200, !data.isEmpty,
                   let parsed = try? JSONDecoder().decode(LiveTripTelemetryDto.self, from: data) {
                    return ParentActiveTripResult(hasActiveTrip: true, telemetry: parsed, isOfflineFallback: false)
                }
            }
        } catch {}
        return ParentActiveTripResult(hasActiveTrip: true, telemetry: LiveTripTelemetryDto(), isOfflineFallback: true)
    }

    func getLiveTrips() async -> [LiveTripTelemetryDto] {
        if isLiveToken(), let req = makeRequest(path: "/trips/live") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                    if let list = try? JSONDecoder().decode([LiveTripTelemetryDto].self, from: data) {
                        return list
                    }
                    if let single = try? JSONDecoder().decode(LiveTripTelemetryDto.self, from: data) {
                        return [single]
                    }
                }
            } catch {}
        }
        return [LiveTripTelemetryDto()]
    }

    func getActiveTrip() async -> LiveTripTelemetryDto {
        if store.role == .parent {
            let res = await getParentActiveTrip()
            return res.telemetry ?? LiveTripTelemetryDto()
        }
        let trips = await getLiveTrips()
        return trips.first ?? LiveTripTelemetryDto()
    }

    func getDriverActiveTrip() async -> DriverActiveTripResult {
        guard isLiveToken() else {
            return DriverActiveTripResult(
                hasActiveTrip: true, tripId: "TRP-2026-08", routeId: "f0000000-0000-0000-0000-000000000001",
                routeName: "Ruta San Martín", vehiclePlate: "ABC-123",
                latitude: -12.0920, longitude: -77.0280, speedKmh: 32.0,
                stops: [], passengers: [], assignedRoutes: [], isOfflineFallback: true
            )
        }
        var drvId = store.profileId
        if drvId.isEmpty, let resolved = await resolveProfileId(role: .driver) {
            drvId = resolved
            store.setProfileId(resolved)
        }
        let allRoutes = await getRoutes()
        let assigned = drvId.isEmpty ? allRoutes : allRoutes.filter { $0.driverId == drvId }
        let routesForDriver = assigned.isEmpty ? allRoutes : assigned

        if let req = makeRequest(path: "/trips") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let trips = try? JSONDecoder().decode([DriverTripApiDto].self, from: data) {
                    let active = trips.filter { t in
                        t.tripState == "IN_PROGRESS" && (drvId.isEmpty || t.driverId == nil || t.driverId == drvId)
                    }.sorted { ($0.startTime ?? "") > ($1.startTime ?? "") }

                    if let first = active.first {
                        let matchedRoute = routesForDriver.first(where: { $0.id == first.routeId })
                            ?? allRoutes.first(where: { $0.id == first.routeId })
                        let stops = matchedRoute?.stops ?? []
                        var lat = stops.first?.latitude ?? -12.0920
                        var lng = stops.first?.longitude ?? -77.0280
                        var spd = 28.0
                        if let locReq = makeRequest(path: "/trips/\(first.id)/locations/latest") {
                            if let (locData, locRes) = try? await session.data(for: locReq),
                               let locHttp = locRes as? HTTPURLResponse, locHttp.statusCode == 200,
                               let obj = try? JSONSerialization.jsonObject(with: locData) as? [String: Any] {
                                lat = (obj["latitude"] as? Double) ?? lat
                                lng = (obj["longitude"] as? Double) ?? lng
                                spd = (obj["speedKmh"] as? Double) ?? spd
                            }
                        }
                        return DriverActiveTripResult(
                            hasActiveTrip: true,
                            tripId: first.id,
                            routeId: first.routeId,
                            routeName: matchedRoute?.name ?? "Ruta Escolar",
                            vehiclePlate: matchedRoute?.vehiclePlate ?? "ABC-123",
                            latitude: lat,
                            longitude: lng,
                            speedKmh: spd,
                            stops: stops,
                            passengers: [],
                            assignedRoutes: routesForDriver,
                            isOfflineFallback: false
                        )
                    }
                    return DriverActiveTripResult(
                        hasActiveTrip: false,
                        tripId: nil,
                        routeId: routesForDriver.first?.id,
                        routeName: routesForDriver.first?.name ?? "Ruta Escolar",
                        vehiclePlate: routesForDriver.first?.vehiclePlate ?? "ABC-123",
                        latitude: routesForDriver.first?.stops.first?.latitude ?? -12.0920,
                        longitude: routesForDriver.first?.stops.first?.longitude ?? -77.0280,
                        speedKmh: 0,
                        stops: routesForDriver.first?.stops ?? [],
                        passengers: [],
                        assignedRoutes: routesForDriver,
                        isOfflineFallback: false
                    )
                }
            } catch {}
        }
        return DriverActiveTripResult(
            hasActiveTrip: true, tripId: "TRP-2026-08", routeId: "f0000000-0000-0000-0000-000000000001",
            routeName: "Ruta San Martín", vehiclePlate: "ABC-123",
            latitude: -12.0920, longitude: -77.0280, speedKmh: 32.0,
            stops: [], passengers: [], assignedRoutes: [], isOfflineFallback: true
        )
    }

    func startDriverTrip(routeId: String) async -> Bool {
        var drvId = store.profileId
        if drvId.isEmpty, let resolved = await resolveProfileId(role: .driver) {
            drvId = resolved
            store.setProfileId(resolved)
        }
        guard isLiveToken(), !drvId.isEmpty,
              let createReq = makeRequest(path: "/trips", method: "POST", body: [
                  "organizationId": store.organizationId,
                  "routeId": routeId,
                  "driverId": drvId
              ]) else { return false }
        do {
            let (data, res) = try await session.data(for: createReq)
            guard let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tripId = obj["id"] as? String else { return false }
            if let startReq = makeRequest(path: "/trips/\(tripId)/start", method: "POST") {
                let (_, startRes) = try await session.data(for: startReq)
                return (startRes as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
            }
        } catch {}
        return false
    }

    func setBoardingStatus(tripId: String, childId: String, boardingState: String) async {
        guard isLiveToken(), !tripId.hasPrefix("TRP-"),
              let req = makeRequest(path: "/trips/\(tripId)/boarding", method: "POST", body: [
                  "childId": childId,
                  "boardingState": boardingState
              ]) else { return }
        _ = try? await session.data(for: req)
    }

    func completeTrip(tripId: String) async {
        guard isLiveToken(), !tripId.hasPrefix("TRP-"),
              let req = makeRequest(path: "/trips/\(tripId)/complete", method: "POST") else { return }
        _ = try? await session.data(for: req)
    }

    // MARK: - Notifications & Stakeholders Parity

    func getNotifications() async -> [SafetyAlertItem] {
        if !store.userId.isEmpty && store.cacheOwner != store.userId {
            db.clearUserScopedCaches()
            AlertCenterStore.shared.setAlerts([])
            store.setCacheOwner(store.userId)
        }
        guard isLiveToken() else {
            return AlertCenterStore.shared.alerts
        }

        var query = ""
        if store.role == .parent {
            var pid = store.profileId
            if pid.isEmpty, let resolved = await resolveProfileId(role: .parent) {
                pid = resolved
                store.setProfileId(resolved)
            }
            if !pid.isEmpty {
                query = "?parentId=\(pid)"
            }
        }

        guard let req = makeRequest(path: "/notifications\(query)") else {
            return AlertCenterStore.shared.alerts
        }
        do {
            let (data, res) = try await session.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200,
               let list = try? JSONDecoder().decode([NotificationApiDto].self, from: data) {
                let items = list.map { Self.mapNotification($0) }
                    .sorted { ($0.sentAtDate ?? .distantPast) > ($1.sentAtDate ?? .distantPast) }
                AlertCenterStore.shared.setAlerts(items)
                return items
            }
        } catch {}
        return AlertCenterStore.shared.alerts
    }

    func markNotificationsDelivered(_ items: [SafetyAlertItem]) async {
        guard isLiveToken() else { return }
        for item in items where item.deliveryState != "DELIVERED" && !item.id.hasPrefix("alt_") {
            if let req = makeRequest(path: "/notifications/\(item.id)/delivered", method: "POST") {
                _ = try? await session.data(for: req)
            }
        }
    }

    func getDrivers() async -> [DriverProfileDto] {
        guard isLiveToken(), let req = makeRequest(path: "/drivers") else { return [] }
        do {
            let (data, res) = try await session.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                return (try? JSONDecoder().decode([DriverProfileDto].self, from: data)) ?? []
            }
        } catch {}
        return []
    }

    func getParents() async -> [ParentProfileDto] {
        guard isLiveToken(), let req = makeRequest(path: "/parents") else { return [] }
        do {
            let (data, res) = try await session.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                return (try? JSONDecoder().decode([ParentProfileDto].self, from: data)) ?? []
            }
        } catch {}
        return []
    }

    private static func mapNotification(_ dto: NotificationApiDto) -> SafetyAlertItem {
        let isEn = AppStrings.shared.currentLanguage == .english
        let cat = dto.category.uppercased()
        let lowerMsg = dto.message.lowercased()
        let title: String
        if cat == "GEOFENCE_BREACHED" && (lowerMsg.contains("llegada al colegio") || lowerMsg.contains("school arrival")) {
            title = isEn ? "Arrived at school" : "Llegada al colegio"
        } else {
            switch cat {
            case "PANIC", "PANIC_ALERT":
                title = isEn ? "Panic alert!" : "¡Alerta de pánico!"
            case "TRIP_STARTED":
                title = isEn ? "Trip started" : "Viaje iniciado"
            case "GEOFENCE_BREACHED":
                title = isEn ? "Vehicle approaching" : "El vehículo está cerca"
            case "ARRIVED":
                title = isEn ? "Arrived at school" : "Llegada al colegio"
            case "STUDENT_BOARDED", "BOARDING":
                title = isEn ? "Student boarded" : "Estudiante a bordo"
            case "INCIDENT_REPORTED", "TRAFFIC":
                title = isEn ? "Route incident" : "Incidencia en el viaje"
            case "ANNOUNCEMENT":
                title = isEn ? "Driver announcement" : "Aviso del conductor"
            default:
                title = isEn ? "Notification" : "Notificación"
            }
        }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoStd = ISO8601DateFormatter()
        let parsedDate = dto.sentAt.flatMap { isoFrac.date(from: $0) ?? isoStd.date(from: $0) }
        let tsLabel: String
        if let parsedDate {
            let diffMins = Int(Date().timeIntervalSince(parsedDate) / 60)
            if diffMins >= 0 && diffMins < 1 {
                tsLabel = isEn ? "Now" : "Ahora"
            } else if diffMins >= 1 && diffMins < 60 {
                tsLabel = isEn ? "\(diffMins)m ago" : "Hace \(diffMins) min"
            } else {
                let df = DateFormatter()
                df.dateFormat = Calendar.current.isDateInToday(parsedDate) ? (isEn ? "'Today,' HH:mm" : "'Hoy,' HH:mm") : "dd/MM/yyyy · HH:mm"
                tsLabel = df.string(from: parsedDate)
            }
        } else {
            tsLabel = isEn ? "Today" : "Hoy"
        }

        let panicFlag = dto.alerts?.contains(where: { $0.panic == true }) == true
        return SafetyAlertItem(
            id: dto.id,
            title: title,
            message: dto.message,
            type: cat,
            timestamp: tsLabel,
            tripId: dto.tripId,
            deliveryState: dto.deliveryState,
            hasPanicAlert: panicFlag,
            sentAtDate: parsedDate
        )
    }

    func getPrimaryVehicleDocs() async -> VehicleDto {
        if let req = makeRequest(path: "/vehicles") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([VehicleDto].self, from: data), !list.isEmpty {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedVehicleDocEntity>())) ?? []
                    old.forEach { db.context.delete($0) }
                    for v in list {
                        db.context.insert(CachedVehicleDocEntity(
                            id: v.id, plate: v.plate, brand: v.brand, model: v.model, capacity: v.capacity,
                            soatPolicy: v.soatPolicy, soatInsurer: v.soatInsurer, soatExpiresAt: v.soatExpiresAt, soatValid: v.soatValid
                        ))
                    }
                    db.save()
                    return list[0]
                }
            } catch {}
        }
        if let cached = try? db.context.fetch(FetchDescriptor<CachedVehicleDocEntity>()).first {
            return VehicleDto(
                id: cached.id, plate: cached.plate, brand: cached.brand, model: cached.model, capacity: cached.capacity,
                soatPolicy: cached.soatPolicy, soatInsurer: cached.soatInsurer, soatExpiresAt: cached.soatExpiresAt, soatValid: cached.soatValid
            )
        }
        return VehicleDto(
            id: "veh_01", plate: "ABC-123", brand: "Mercedes-Benz", model: "Mercedes-Benz Sprinter 416",
            capacity: 20, soatPolicy: "SOAT-2026-88412", soatInsurer: "Rímac Seguros", soatExpiresAt: "2026-12-15", soatValid: true
        )
    }

    func getTripHistory() async -> [TripHistoryItem] {
        if let req = makeRequest(path: "/trips/history") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([TripHistoryItem].self, from: data), !list.isEmpty {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedTripHistoryEntity>())) ?? []
                    old.forEach { db.context.delete($0) }
                    for item in list {
                        db.context.insert(CachedTripHistoryEntity(
                            tripId: item.tripId, routeName: item.routeName, driverName: item.driverName,
                            vehiclePlate: item.vehiclePlate, status: item.status, boardedCount: item.boardedCount,
                            totalStudents: item.totalStudents, dateLabel: item.dateLabel, myRating: item.myRating,
                            cancellationReason: item.cancellationReason
                        ))
                    }
                    db.save()
                    return list
                }
            } catch {}
        }
        let cached = (try? db.context.fetch(FetchDescriptor<CachedTripHistoryEntity>())) ?? []
        if !cached.isEmpty {
            return cached.map {
                TripHistoryItem(
                    tripId: $0.tripId, routeName: $0.routeName, driverName: $0.driverName,
                    vehiclePlate: $0.vehiclePlate, status: $0.status, boardedCount: $0.boardedCount,
                    totalStudents: $0.totalStudents, dateLabel: $0.dateLabel, myRating: $0.myRating,
                    cancellationReason: $0.cancellationReason
                )
            }
        }
        return [
            TripHistoryItem(tripId: "TRP-2026-07", routeName: "Ruta San Martín - Turno Mañana", driverName: "Carlos Ramirez", vehiclePlate: "ABC-123", status: "COMPLETED", boardedCount: 14, totalStudents: 14, dateLabel: "Ayer, 07:50 AM", myRating: 5),
            TripHistoryItem(tripId: "TRP-2026-06", routeName: "Ruta 02 - Turno Mañana", driverName: "Carlos Ramirez", vehiclePlate: "ABC-123", status: "CANCELLED", boardedCount: 0, totalStudents: 14, dateLabel: "Hace 3 días", cancellationReason: "Falla mecánica")
        ]
    }

    func reportAbsence(childName: String, reason: String, notes: String) async {
        let localId = "local_\(UUID().uuidString)"
        let entity = CachedAbsenceEntity(id: localId, childName: childName, absenceDate: todayIso(), reason: reason, notes: notes, pendingSync: true)
        db.context.insert(entity)
        db.save()

        if let req = makeRequest(path: "/absences", method: "POST", body: ["childName": childName, "absenceDate": todayIso(), "reason": reason, "notes": notes]) {
            do {
                let (_, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    entity.pendingSync = false
                    db.save()
                }
            } catch {}
        }
    }

    func submitRating(tripId: String, stars: Int, comment: String) async {
        let desc = FetchDescriptor<CachedTripHistoryEntity>(predicate: #Predicate { $0.tripId == tripId })
        if let entity = try? db.context.fetch(desc).first {
            entity.myRating = stars
            db.save()
        }
        if let req = makeRequest(path: "/trips/\(tripId)/rating", method: "POST", body: ["stars": stars, "comment": comment]) {
            _ = try? await session.data(for: req)
        }
    }

    func cancelTripForceMajeure(tripId: String, reason: String, notes: String) async {
        if let req = makeRequest(path: "/trips/\(tripId)/cancel", method: "POST", body: ["reason": reason, "notes": notes]) {
            _ = try? await session.data(for: req)
        }
    }

    func reportRoadblockIncident(tripId: String, incidentType: String, delayMinutes: Int) async {
        if let req = makeRequest(path: "/trips/\(tripId)/incidents", method: "POST", body: ["incidentType": incidentType, "delayMinutes": delayMinutes]) {
            _ = try? await session.data(for: req)
        }
    }

    func triggerPanicAlert(tripId: String) async {
        if let req = makeRequest(path: "/trips/\(tripId)/panic", method: "POST", body: ["source": "IOS_PARENT"]) {
            _ = try? await session.data(for: req)
        }
    }

    // MARK: - Caregivers & Support Tickets (US-23)

    func getCaregivers() async -> [CaregiverItem] {
        if let req = makeRequest(path: "/caregivers") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([CaregiverItem].self, from: data) {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedCaregiverEntity>())) ?? []
                    old.filter { !$0.pendingSync }.forEach { db.context.delete($0) }
                    for c in list {
                        db.context.insert(CachedCaregiverEntity(id: c.id, fullName: c.fullName, relationship: c.relationship, phoneNumber: c.phoneNumber, createdAt: c.createdAt, pendingSync: false))
                    }
                    db.save()
                }
            } catch {}
        }
        let rows = (try? db.context.fetch(FetchDescriptor<CachedCaregiverEntity>())) ?? []
        return rows.map { CaregiverItem(id: $0.id, fullName: $0.fullName, relationship: $0.relationship, phoneNumber: $0.phoneNumber, createdAt: $0.createdAt) }
    }

    func addCaregiver(fullName: String, relationship: String, phone: String) async {
        let localId = "local_\(UUID().uuidString)"
        let entity = CachedCaregiverEntity(id: localId, fullName: fullName, relationship: relationship, phoneNumber: phone, createdAt: nowIso(), pendingSync: true)
        db.context.insert(entity)
        db.save()
        if let req = makeRequest(path: "/caregivers", method: "POST", body: ["fullName": fullName, "relationship": relationship, "phoneNumber": phone]) {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let created = try? JSONDecoder().decode(CaregiverItem.self, from: data) {
                    db.context.delete(entity)
                    db.context.insert(CachedCaregiverEntity(id: created.id, fullName: created.fullName, relationship: created.relationship, phoneNumber: created.phoneNumber, createdAt: created.createdAt, pendingSync: false))
                    db.save()
                }
            } catch {}
        }
    }

    func deleteCaregiver(id: String) async {
        let desc = FetchDescriptor<CachedCaregiverEntity>(predicate: #Predicate { $0.id == id })
        if let entity = try? db.context.fetch(desc).first {
            db.context.delete(entity)
            db.save()
        }
        if !id.hasPrefix("local_"), let req = makeRequest(path: "/caregivers/\(id)", method: "DELETE") {
            _ = try? await session.data(for: req)
        }
    }

    func getSupportTickets() async -> [SupportTicketItem] {
        if let req = makeRequest(path: "/support-tickets") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([SupportTicketItem].self, from: data) {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedSupportTicketEntity>())) ?? []
                    old.filter { !$0.pendingSync }.forEach { db.context.delete($0) }
                    for t in list {
                        db.context.insert(CachedSupportTicketEntity(id: t.id, ticketCode: t.ticketCode, category: t.category, subject: t.subject, message: t.message, status: t.status, createdAt: t.createdAt, pendingSync: false))
                    }
                    db.save()
                }
            } catch {}
        }
        let rows = (try? db.context.fetch(FetchDescriptor<CachedSupportTicketEntity>())) ?? []
        return rows.map { SupportTicketItem(id: $0.id, ticketCode: $0.ticketCode, category: $0.category, subject: $0.subject, message: $0.message, status: $0.status, createdAt: $0.createdAt) }
    }

    func createSupportTicket(category: String, subject: String, message: String) async -> SupportTicketItem {
        let code = "#RG-\(Int.random(in: 1000...9999))"
        let localId = "local_\(UUID().uuidString)"
        let entity = CachedSupportTicketEntity(id: localId, ticketCode: code, category: category, subject: subject, message: message, status: "OPEN", createdAt: nowIso(), pendingSync: true)
        db.context.insert(entity)
        db.save()

        if let req = makeRequest(path: "/support-tickets", method: "POST", body: ["category": category, "subject": subject, "message": message]) {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let created = try? JSONDecoder().decode(SupportTicketItem.self, from: data) {
                    db.context.delete(entity)
                    db.context.insert(CachedSupportTicketEntity(id: created.id, ticketCode: created.ticketCode, category: created.category, subject: created.subject, message: created.message, status: created.status, createdAt: created.createdAt, pendingSync: false))
                    db.save()
                    return created
                }
            } catch {}
        }
        return SupportTicketItem(id: localId, ticketCode: code, category: category, subject: subject, message: message, status: "OPEN", createdAt: entity.createdAt)
    }

    // MARK: - Remaining 6 US (US-20, US-24, US-26, US-27, US-28, US-30)

    func getMaintenances() async -> [MaintenanceItem] {
        if let req = makeRequest(path: "/maintenances") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([MaintenanceItem].self, from: data) {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedMaintenanceEntity>())) ?? []
                    old.filter { !$0.pendingSync }.forEach { db.context.delete($0) }
                    for m in list {
                        db.context.insert(CachedMaintenanceEntity(id: m.id, vehiclePlate: m.vehiclePlate, maintenanceType: m.maintenanceType, details: m.description, workshop: m.workshop, cost: m.cost, performedAt: m.performedAt, status: m.status, pendingSync: false))
                    }
                    db.save()
                }
            } catch {}
        }
        let rows = (try? db.context.fetch(FetchDescriptor<CachedMaintenanceEntity>())) ?? []
        return rows.map { MaintenanceItem(id: $0.id, vehiclePlate: $0.vehiclePlate, maintenanceType: $0.maintenanceType, description: $0.details, workshop: $0.workshop, cost: $0.cost, performedAt: $0.performedAt, status: $0.status) }
    }

    func addMaintenance(plate: String, type: String, workshop: String, cost: Double) async {
        let localId = "local_\(UUID().uuidString)"
        let entity = CachedMaintenanceEntity(id: localId, vehiclePlate: plate, maintenanceType: type, details: type, workshop: workshop, cost: cost, performedAt: todayIso(), status: "COMPLETED", pendingSync: true)
        db.context.insert(entity)
        db.save()
        if let req = makeRequest(path: "/maintenances", method: "POST", body: ["vehiclePlate": plate, "maintenanceType": type, "description": type, "workshop": workshop, "cost": cost, "odometerKm": 45000]) {
            do {
                let (_, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    entity.pendingSync = false
                    db.save()
                }
            } catch {}
        }
    }

    func getExpenses() async -> [ExpenseItem] {
        if let req = makeRequest(path: "/expenses") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([ExpenseItem].self, from: data) {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedExpenseEntity>())) ?? []
                    old.filter { !$0.pendingSync }.forEach { db.context.delete($0) }
                    for e in list {
                        db.context.insert(CachedExpenseEntity(id: e.id, vehiclePlate: e.vehiclePlate, category: e.category, details: e.description, amount: e.amount, expenseDate: e.expenseDate, pendingSync: false))
                    }
                    db.save()
                }
            } catch {}
        }
        let rows = (try? db.context.fetch(FetchDescriptor<CachedExpenseEntity>())) ?? []
        return rows.map { ExpenseItem(id: $0.id, vehiclePlate: $0.vehiclePlate, category: $0.category, description: $0.details, amount: $0.amount, expenseDate: $0.expenseDate) }
    }

    func addExpense(plate: String, category: String, details: String, amount: Double) async {
        let localId = "local_\(UUID().uuidString)"
        let entity = CachedExpenseEntity(id: localId, vehiclePlate: plate, category: category, details: details, amount: amount, expenseDate: todayIso(), pendingSync: true)
        db.context.insert(entity)
        db.save()
        if let req = makeRequest(path: "/expenses", method: "POST", body: ["vehiclePlate": plate, "category": category, "description": details, "amount": amount, "driverName": "Carlos Ramirez"]) {
            do {
                let (_, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    entity.pendingSync = false
                    db.save()
                }
            } catch {}
        }
    }

    func getAnnouncements() async -> [AnnouncementItem] {
        if let req = makeRequest(path: "/announcements") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([AnnouncementItem].self, from: data) {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedAnnouncementEntity>())) ?? []
                    old.filter { !$0.pendingSync }.forEach { db.context.delete($0) }
                    for a in list {
                        db.context.insert(CachedAnnouncementEntity(id: a.id, title: a.title, message: a.message, priority: a.priority, authorName: a.authorName, createdAt: a.createdAt, pendingSync: false))
                    }
                    db.save()
                }
            } catch {}
        }
        let rows = (try? db.context.fetch(FetchDescriptor<CachedAnnouncementEntity>())) ?? []
        return rows.map { AnnouncementItem(id: $0.id, title: $0.title, message: $0.message, priority: $0.priority, authorName: $0.authorName, createdAt: $0.createdAt) }
    }

    func publishAnnouncement(title: String, message: String, priority: String) async {
        let localId = "local_\(UUID().uuidString)"
        let entity = CachedAnnouncementEntity(id: localId, title: title, message: message, priority: priority, authorName: store.fullName.isEmpty ? "Carlos Ramirez" : store.fullName, createdAt: nowIso(), pendingSync: true)
        db.context.insert(entity)
        db.save()
        if let req = makeRequest(path: "/announcements", method: "POST", body: ["title": title, "message": message, "priority": priority]) {
            do {
                let (_, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    entity.pendingSync = false
                    db.save()
                }
            } catch {}
        }
    }

    func getPickupChanges() async -> [PickupChangeItem] {
        if let req = makeRequest(path: "/pickup-changes") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([PickupChangeItem].self, from: data) {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedPickupChangeEntity>())) ?? []
                    old.filter { !$0.pendingSync }.forEach { db.context.delete($0) }
                    for p in list {
                        db.context.insert(CachedPickupChangeEntity(id: p.id, childName: p.childName, newAddress: p.newAddress, reason: p.reason, status: p.status, createdAt: p.createdAt, pendingSync: false))
                    }
                    db.save()
                }
            } catch {}
        }
        let rows = (try? db.context.fetch(FetchDescriptor<CachedPickupChangeEntity>())) ?? []
        return rows.map { PickupChangeItem(id: $0.id, childName: $0.childName, newAddress: $0.newAddress, reason: $0.reason, status: $0.status, createdAt: $0.createdAt) }
    }

    func requestPickupChange(childName: String, newAddress: String, reason: String) async {
        let localId = "local_\(UUID().uuidString)"
        let entity = CachedPickupChangeEntity(id: localId, childName: childName, newAddress: newAddress, reason: reason, status: "PENDING", createdAt: nowIso(), pendingSync: true)
        db.context.insert(entity)
        db.save()
        if let req = makeRequest(path: "/pickup-changes", method: "POST", body: ["childName": childName, "newAddress": newAddress, "reason": reason, "effectiveDate": todayIso()]) {
            do {
                let (_, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    entity.pendingSync = false
                    db.save()
                }
            } catch {}
        }
    }

    func reviewPickupChange(id: String, status: String) async {
        let desc = FetchDescriptor<CachedPickupChangeEntity>(predicate: #Predicate { $0.id == id })
        if let entity = try? db.context.fetch(desc).first {
            entity.status = status
            db.save()
        }
        if !id.hasPrefix("local_"), let req = makeRequest(path: "/pickup-changes/\(id)/review", method: "PATCH", body: ["status": status]) {
            _ = try? await session.data(for: req)
        }
    }

    func getOptimizedStops(routeId: String) async -> OptimizedStopsResponse? {
        guard let req = makeRequest(path: "/routes/\(routeId)/optimized-stops") else { return nil }
        do {
            let (data, res) = try await session.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                return try? JSONDecoder().decode(OptimizedStopsResponse.self, from: data)
            }
        } catch {}
        return nil
    }

    func getChatMessages() async -> [ChatMessageItem] {
        if let req = makeRequest(path: "/chat") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([ChatMessageItem].self, from: data) {
                    let old = (try? db.context.fetch(FetchDescriptor<CachedChatMessageEntity>())) ?? []
                    old.filter { !$0.pendingSync }.forEach { db.context.delete($0) }
                    for m in list {
                        db.context.insert(CachedChatMessageEntity(id: m.id, senderName: m.senderName, senderRole: m.senderRole, message: m.message, sentAt: m.sentAt, pendingSync: false))
                    }
                    db.save()
                }
            } catch {}
        }
        let rows = (try? db.context.fetch(FetchDescriptor<CachedChatMessageEntity>())) ?? []
        return rows.map { ChatMessageItem(id: $0.id, senderName: $0.senderName, senderRole: $0.senderRole, message: $0.message, sentAt: $0.sentAt) }
    }

    func sendChatMessage(_ text: String) async {
        let localId = "local_\(UUID().uuidString)"
        let sender = store.fullName.isEmpty ? "Usuario RouteGuard" : store.fullName
        let entity = CachedChatMessageEntity(id: localId, senderName: sender, senderRole: store.role.rawValue, message: text, sentAt: nowIso(), pendingSync: true)
        db.context.insert(entity)
        db.save()
        if let req = makeRequest(path: "/chat", method: "POST", body: ["message": text]) {
            do {
                let (_, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    entity.pendingSync = false
                    db.save()
                }
            } catch {}
        }
    }

    // MARK: - Routes & Plans (Admin Parity)

    func getRoutes() async -> [RouteSummaryItem] {
        if let req = makeRequest(path: "/routes") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([RouteSummaryItem].self, from: data), !list.isEmpty {
                    return list
                }
            } catch {}
        }
        return [
            RouteSummaryItem(id: "f0000000-0000-0000-0000-000000000001", name: "Ruta San Martín - Turno Mañana", status: "ACTIVE", vehiclePlate: "ABC-123", stopsCount: 3),
            RouteSummaryItem(id: "f0000000-0000-0000-0000-000000000002", name: "Ruta Surco - Secundaria", status: "ACTIVE", vehiclePlate: "XYZ-456", stopsCount: 2)
        ]
    }

    func createRoute(name: String) async -> RouteSummaryItem? {
        if let req = makeRequest(path: "/routes", method: "POST", body: ["organizationId": store.organizationId, "name": name]) {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    return try? JSONDecoder().decode(RouteSummaryItem.self, from: data)
                }
            } catch {}
        }
        return RouteSummaryItem(id: UUID().uuidString, name: name, status: "ACTIVE", vehiclePlate: "ABC-123", stopsCount: 0)
    }

    func getPlans() async -> [PlanItem] {
        if let req = makeRequest(path: "/plans") {
            do {
                let (data, res) = try await session.data(for: req)
                if let http = res as? HTTPURLResponse, http.statusCode == 200,
                   let list = try? JSONDecoder().decode([PlanItem].self, from: data), !list.isEmpty {
                    return list
                }
            } catch {}
        }
        return [
            PlanItem(id: "plan_starter", name: "Básico Familiar", pricePen: 49.99, maxRoutes: 1, description: "Seguimiento GPS en vivo y alertas para 1 estudiante."),
            PlanItem(id: "plan_growth", name: "Estándar Escolar", pricePen: 99.99, maxRoutes: 3, description: "Hasta 3 rutas, historial completo y cuidadores ilimitados."),
            PlanItem(id: "plan_enterprise", name: "Flota Institucional", pricePen: 149.99, maxRoutes: 10, description: "Flota ilimitada, control de gastos y auditoría SOAT.")
        ]
    }
}
