import Foundation

/// Shared UserDefaults for app and widget communication
class SharedDefaults {
    static let suiteName = "group.com.dailies.timer"
    
    static var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    // Keys
    static let timersKey = "timers"
    static let activeTimerIdKey = "activeTimerId"
    static let widgetStateKey = "widgetState"
    
    // MARK: - Timers
    
    static func saveTimers(_ timers: [TimerItem]) {
        guard let defaults = shared else {
            print("SharedDefaults: Failed to get shared UserDefaults")
            return
        }
        do {
            let encoded = try JSONEncoder().encode(timers)
            defaults.set(encoded, forKey: timersKey)
            defaults.synchronize()
            print("SharedDefaults: Saved \(timers.count) timers")
        } catch {
            print("SharedDefaults: Failed to encode timers: \(error)")
        }
    }
    
    static func loadTimers() -> [TimerItem] {
        guard let defaults = shared else {
            print("SharedDefaults: Failed to get shared UserDefaults")
            return []
        }
        
        guard let data = defaults.data(forKey: timersKey) else {
            print("SharedDefaults: No timer data found")
            return []
        }
        
        do {
            let timers = try JSONDecoder().decode([TimerItem].self, from: data)
            print("SharedDefaults: Loaded \(timers.count) timers")
            return timers
        } catch {
            print("SharedDefaults: Failed to decode timers: \(error)")
            return []
        }
    }
    
    // MARK: - Active Timer ID
    
    static func saveActiveTimerId(_ id: UUID?) {
        guard let defaults = shared else { return }
        if let id = id {
            defaults.set(id.uuidString, forKey: activeTimerIdKey)
        } else {
            defaults.removeObject(forKey: activeTimerIdKey)
        }
        defaults.synchronize()
    }
    
    static func loadActiveTimerId() -> UUID? {
        guard let defaults = shared,
              let idString = defaults.string(forKey: activeTimerIdKey) else {
            return nil
        }
        return UUID(uuidString: idString)
    }
    
    // MARK: - Widget State
    
    static func saveWidgetState(_ state: TimerWidgetState) {
        guard let defaults = shared else {
            print("SharedDefaults: Failed to get shared UserDefaults for widget state")
            return
        }
        do {
            let encoded = try JSONEncoder().encode(state)
            defaults.set(encoded, forKey: widgetStateKey)
            defaults.synchronize()
            print("SharedDefaults: Saved widget state - running: \(state.isRunning), elapsed: \(state.elapsedTime)")
        } catch {
            print("SharedDefaults: Failed to encode widget state: \(error)")
        }
    }
    
    static func loadWidgetState() -> TimerWidgetState {
        guard let defaults = shared else {
            print("SharedDefaults: Failed to get shared UserDefaults for widget state")
            return .empty
        }
        
        guard let data = defaults.data(forKey: widgetStateKey) else {
            print("SharedDefaults: No widget state data found")
            return .empty
        }
        
        do {
            let state = try JSONDecoder().decode(TimerWidgetState.self, from: data)
            print("SharedDefaults: Loaded widget state - running: \(state.isRunning), elapsed: \(state.elapsedTime)")
            return state
        } catch {
            print("SharedDefaults: Failed to decode widget state: \(error)")
            return .empty
        }
    }
}
