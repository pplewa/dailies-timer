import Foundation
import ActivityKit

// Note: This file defines TimerActivityAttributes for the main app.
// The widget extension has its own definition in TimerWidget.swift
// Both must match exactly for Live Activities to work properly.

/// Attributes for the Timer Live Activity
struct TimerActivityAttributes: ActivityAttributes {
    /// Dynamic state that can change during the activity
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var isRunning: Bool
        var startTime: Date? // When the timer started (for calculating live elapsed time)
    }
    
    /// Static data that doesn't change
    var timerName: String
    var timerId: String
    var referenceDuration: TimeInterval
}
