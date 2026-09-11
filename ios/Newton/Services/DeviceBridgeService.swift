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
        
        return "Location detected: \(city), \(region), \(country) (Lat: \(lat), Lon: \(lon), Time Zone: \(tz))"
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
        Real time Date & Time information:
        - Date & time: \(dateFormatter.string(from: now))
        - Timezone: \(tz.identifier) (GMT\(tzOffset >= 0 ? "+\(tzOffset)" : "\(tzOffset)"))
        - ISO 8601: \(isoFormatter.string(from: now))
        - Timestamp UNIX: \(Int(now.timeIntervalSince1970))
        """
    }
    
    // MARK: - Reminders Orbit
    public func getReminders(filter: String = "all") async -> String {
        var output = "Active reminders:\n"
        
        if customReminders.isEmpty {
            return "No active reminders"
        }
        
        for (i, rem) in customReminders.enumerated() {
            let title = rem["title"] ?? "Untitled"
            let due = rem["dueDate"] ?? "No limit date"
            output += "\(i + 1). [ ] \(title) (Vence: \(due))\n"
        }
        return output
    }
    
    public func createReminder(title: String, dueDate: String = "") -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return "Error: Reminder must have a title" }
        
        let newReminder: [String: String] = [
            "id": UUID().uuidString,
            "title": cleanTitle,
            "dueDate": dueDate.isEmpty ? "Today" : dueDate,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        customReminders.append(newReminder)
        saveLocalData()
        return "Reminder created succesfully: \"\(cleanTitle)\" (Ends: \(newReminder["dueDate"] ?? "Today"))"
    }
    
    // MARK: - Calendar Events Orbit
    public func getCalendarEvents(daysAhead: Int = 7) async -> String {
        if customCalendarEvents.isEmpty {
            let df = DateFormatter()
            df.dateStyle = .medium
            return "Agenda free for the next \(daysAhead) days (starting from \(df.string(from: Date())))."
        }
        
        var output = "Following calendar events:\n"
        for (i, ev) in customCalendarEvents.enumerated() {
            let title = ev["title"] ?? "Event"
            let start = ev["startDate"] ?? "Date not specified"
            let notes = ev["notes"] ?? ""
            output += "\(i + 1). **\(title)** — \(start) \(notes.isEmpty ? "" : "(\(notes))")\n"
        }
        return output
    }
    
    public func createCalendarEvent(title: String, startDate: String, endDate: String = "", notes: String = "") -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return "Error: Event must have a title." }
        
        let newEvent: [String: String] = [
            "id": UUID().uuidString,
            "title": cleanTitle,
            "startDate": startDate.isEmpty ? "Today" : startDate,
            "endDate": endDate,
            "notes": notes
        ]
        
        customCalendarEvents.append(newEvent)
        saveLocalData()
        return "Event added to the calendar: \"\(cleanTitle)\" for \(newEvent["startDate"] ?? "Today")."
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
