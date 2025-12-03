import Foundation

/// Represents a single timer with its state and configuration
struct TimerItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var referenceDuration: TimeInterval // Reference duration in seconds (for display only)
    var elapsedTime: TimeInterval // Elapsed time in seconds
    var isRunning: Bool
    var lastStartTime: Date? // When the timer was last started (for calculating elapsed while running)
    
    init(
        id: UUID = UUID(),
        name: String,
        referenceDuration: TimeInterval = 0,
        elapsedTime: TimeInterval = 0,
        isRunning: Bool = false,
        lastStartTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.referenceDuration = referenceDuration
        self.elapsedTime = elapsedTime
        self.isRunning = isRunning
        self.lastStartTime = lastStartTime
    }
    
    /// Calculate the current elapsed time including any running period
    var currentElapsedTime: TimeInterval {
        if isRunning, let startTime = lastStartTime {
            return elapsedTime + Date().timeIntervalSince(startTime)
        }
        return elapsedTime
    }
    
    /// Format elapsed time as HH:MM:SS
    var formattedTime: String {
        let total = Int(currentElapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format reference duration as HH:MM:SS
    var formattedReferenceDuration: String {
        let total = Int(referenceDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Check if timer has exceeded reference duration
    var hasExceededReference: Bool {
        guard referenceDuration > 0 else { return false }
        return currentElapsedTime > referenceDuration
    }
    
    /// Progress towards reference duration (0.0 to 1.0+)
    var progress: Double {
        guard referenceDuration > 0 else { return 0 }
        return currentElapsedTime / referenceDuration
    }
}

/// State for widget communication
struct TimerWidgetState: Codable {
    var activeTimerId: UUID?
    var activeTimerName: String?
    var elapsedTime: TimeInterval
    var isRunning: Bool
    var lastUpdated: Date
    
    static var empty: TimerWidgetState {
        TimerWidgetState(
            activeTimerId: nil,
            activeTimerName: nil,
            elapsedTime: 0,
            isRunning: false,
            lastUpdated: Date()
        )
    }
}

