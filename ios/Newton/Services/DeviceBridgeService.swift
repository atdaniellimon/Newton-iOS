//
//  DeviceBridgeService.swift
//  Newton
//
//  Provides native access to Location, Calendar, Reminders, and Date/Time services for Newton Orbits.
//

import Foundation
import CoreLocation
import EventKit

public final class DeviceBridgeService: NSObject, CLLocationManagerDelegate {
    public static let shared = DeviceBridgeService()
    
    private let eventStore = EKEventStore()
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    
    @Published public private(set) var customReminders: [[String: String]] = []
    @Published public private(set) var customCalendarEvents: [[String: String]] = []
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        loadLocalData()
    }
    
    // MARK: - Location Orbit
    public func getCurrentLocation() async -> String {
        if let ipGeo = await fetchIPLocation() {
            return ipGeo
        }
        
        locationManager.requestWhenInUseAuthorization()
        
        if let loc = locationManager.location ?? lastLocation {
            let lat = String(format: "%.4f", loc.coordinate.latitude)
            let lon = String(format: "%.4f", loc.coordinate.longitude)
            let tz = TimeZone.current.identifier
            return "Current Location: Latitude \(lat), Longitude \(lon) (Timezone: \(tz))"
        }
        
        let tz = TimeZone.current.identifier
        return "Current Location: Timezone \(tz), System Locale \(Locale.current.identifier)"
    }
    
    private func fetchIPLocation() async -> String? {
        guard let url = URL(string: "http://ip-api.com/json/?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,query") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["status"] as? String == "success" else {
            return nil
        }
        
        let city = json["city"] as? String ?? ""
        let region = json["regionName"] as? String ?? ""
        let country = json["country"] as? String ?? ""
        let tz = json["timezone"] as? String ?? TimeZone.current.identifier
        let lat = json["lat"] as? Double ?? 0.0
        let lon = json["lon"] as? Double ?? 0.0
        
        return "📍 Ubicación detectada: \(city), \(region), \(country) (Lat: \(lat), Lon: \(lon), Zona Horaria: \(tz))"
    }
    
    // MARK: - Date & Time Orbit
    public func getFormattedDateTime() -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        dateFormatter.locale = Locale(identifier: Locale.preferredLanguages.first ?? "es_ES")
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone.current
        
        let tz = TimeZone.current
        let tzOffset = tz.secondsFromGMT() / 3600
        
        return """
        ⏰ Información de Fecha y Hora en Tiempo Real:
        - Fecha y Hora Local: \(dateFormatter.string(from: now))
        - Zona Horaria: \(tz.identifier) (GMT\(tzOffset >= 0 ? "+\(tzOffset)" : "\(tzOffset)"))
        - Formato ISO 8601: \(isoFormatter.string(from: now))
        - Timestamp UNIX: \(Int(now.timeIntervalSince1970))
        """
    }
    
    // MARK: - Reminders Orbit
    public func getReminders(filter: String = "all") async -> String {
        var output = "📋 Recordatorios Activos:\n"
        
        if customReminders.isEmpty {
            return "📋 No tienes recordatorios pendientes."
        }
        
        for (i, rem) in customReminders.enumerated() {
            let title = rem["title"] ?? "Sin título"
            let due = rem["dueDate"] ?? "Sin fecha límite"
            output += "\(i + 1). [ ] \(title) (Vence: \(due))\n"
        }
        return output
    }
    
    public func createReminder(title: String, dueDate: String = "") -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return "Error: El recordatorio debe tener un título." }
        
        let newReminder: [String: String] = [
            "id": UUID().uuidString,
            "title": cleanTitle,
            "dueDate": dueDate.isEmpty ? "Hoy" : dueDate,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        customReminders.append(newReminder)
        saveLocalData()
        return "✅ Recordatorio creado: \"\(cleanTitle)\" (Vence: \(newReminder["dueDate"] ?? "Hoy"))"
    }
    
    // MARK: - Calendar Events Orbit
    public func getCalendarEvents(daysAhead: Int = 7) async -> String {
        if customCalendarEvents.isEmpty {
            let df = DateFormatter()
            df.dateStyle = .medium
            return "📅 Agenda despejada para los próximos \(daysAhead) días (a partir de \(df.string(from: Date())))."
        }
        
        var output = "📅 Próximos Eventos en Calendario:\n"
        for (i, ev) in customCalendarEvents.enumerated() {
            let title = ev["title"] ?? "Evento"
            let start = ev["startDate"] ?? "Fecha por definir"
            let notes = ev["notes"] ?? ""
            output += "\(i + 1). 🗓️ **\(title)** — \(start) \(notes.isEmpty ? "" : "(\(notes))")\n"
        }
        return output
    }
    
    public func createCalendarEvent(title: String, startDate: String, endDate: String = "", notes: String = "") -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return "Error: El evento debe tener un título." }
        
        let newEvent: [String: String] = [
            "id": UUID().uuidString,
            "title": cleanTitle,
            "startDate": startDate.isEmpty ? "Hoy" : startDate,
            "endDate": endDate,
            "notes": notes
        ]
        
        customCalendarEvents.append(newEvent)
        saveLocalData()
        return "✅ Evento agendado en el calendario: \"\(cleanTitle)\" para \(newEvent["startDate"] ?? "Hoy")."
    }
    
    // MARK: - Persistence
    private func saveLocalData() {
        UserDefaults.standard.set(customReminders, forKey: "newton_user_reminders")
        UserDefaults.standard.set(customCalendarEvents, forKey: "newton_user_calendar")
    }
    
    private func loadLocalData() {
        if let r = UserDefaults.standard.array(forKey: "newton_user_reminders") as? [[String: String]] {
            self.customReminders = r
        }
        if let c = UserDefaults.standard.array(forKey: "newton_user_calendar") as? [[String: String]] {
            self.customCalendarEvents = c
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            self.lastLocation = loc
        }
    }
}
