import Foundation

enum WakeDuration: String, Codable, CaseIterable {
    case indefinite = "Indefinite"
    case fifteenMinutes = "15 Minutes"
    case thirtyMinutes = "30 Minutes"
    case oneHour = "1 Hour"
    case twoHours = "2 Hours"
    case fourHours = "4 Hours"
    case eightHours = "8 Hours"
    case scheduled = "Scheduled"

    var timeInterval: TimeInterval? {
        switch self {
        case .indefinite, .scheduled: return nil
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .eightHours: return 8 * 60 * 60
        }
    }
}

class WakeState: Identifiable, Codable, ObservableObject, Hashable {
    var id = UUID()
    var name: String
    var isEnabled: Bool = false
    var schedule: Schedule?
    var options: StateOptions
    var duration: WakeDuration
    var enabledAt: Date?
    
    init(name: String, isEnabled: Bool = false, schedule: Schedule? = nil, options: StateOptions, duration: WakeDuration = .indefinite) {
        self.name = name
        self.isEnabled = isEnabled
        self.schedule = schedule
        self.options = options
        self.duration = duration
        self.enabledAt = nil
    }
    
    static func == (lhs: WakeState, rhs: WakeState) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    struct Schedule: Codable {
        var days: [Weekday]
        var startTime: Date
        var endTime: Date
    }
    
    struct StateOptions: Codable {
        var allowScreenDim: Bool
        var allowSystemLock: Bool
        var sleepAtEnd: Bool

        init(allowScreenDim: Bool, allowSystemLock: Bool, sleepAtEnd: Bool = false) {
            self.allowScreenDim = allowScreenDim
            self.allowSystemLock = allowSystemLock
            self.sleepAtEnd = sleepAtEnd
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            allowScreenDim = try container.decode(Bool.self, forKey: .allowScreenDim)
            allowSystemLock = try container.decode(Bool.self, forKey: .allowSystemLock)
            // Presets saved before this option existed default to no sleep
            sleepAtEnd = try container.decodeIfPresent(Bool.self, forKey: .sleepAtEnd) ?? false
        }
    }
}

enum Weekday: String, Codable, CaseIterable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    
    var shortName: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }
}