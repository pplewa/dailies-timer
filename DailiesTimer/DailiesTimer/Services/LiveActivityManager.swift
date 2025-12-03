import Foundation
import ActivityKit
import SwiftUI

/// Manages Live Activities for the timer on Dynamic Island and Lock Screen
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    
    @Published var currentActivity: Activity<TimerActivityAttributes>?
    
    private init() {}
    
    // MARK: - Activity Management
    
    /// Start a Live Activity for the given timer with the current elapsed time
    /// This is SYNCHRONOUS to ensure activity is created before app suspends
    func startActivity(for timer: TimerItem, currentElapsedTime: TimeInterval) {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("LiveActivityManager: ❌ Live Activities not enabled on this device")
            return
        }
        
        print("LiveActivityManager: Starting Live Activity for '\(timer.name)' with elapsed: \(currentElapsedTime)")
        
        // End any existing activities SYNCHRONOUSLY
        for activity in Activity<TimerActivityAttributes>.activities {
            print("LiveActivityManager: Ending existing activity: \(activity.id)")
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        let attributes = TimerActivityAttributes(
            timerName: timer.name,
            timerId: timer.id.uuidString,
            referenceDuration: timer.referenceDuration
        )
        
        // Calculate the "virtual" start time based on elapsed time
        // This allows Text(timerInterval:) to display the correct elapsed time
        let virtualStartTime = Date().addingTimeInterval(-currentElapsedTime)
        
        let initialState = TimerActivityAttributes.ContentState(
            elapsedTime: currentElapsedTime,
            isRunning: true,  // ALWAYS true when starting
            startTime: virtualStartTime
        )
        
        print("LiveActivityManager: Creating activity with isRunning=TRUE, startTime=\(virtualStartTime)")
        
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("LiveActivityManager: ✅ Started Live Activity: \(activity.id)")
            print("LiveActivityManager: Activity state - isRunning: \(initialState.isRunning)")
        } catch {
            print("LiveActivityManager: ❌ Failed to start Live Activity: \(error)")
        }
    }
    
    /// Update the Live Activity with new timer state
    func updateActivity(elapsedTime: TimeInterval, isRunning: Bool) {
        // Find any active activity
        guard let activity = Activity<TimerActivityAttributes>.activities.first else {
            print("LiveActivityManager: No active activity to update")
            return
        }
        
        let virtualStartTime = isRunning ? Date().addingTimeInterval(-elapsedTime) : nil
        
        let updatedState = TimerActivityAttributes.ContentState(
            elapsedTime: elapsedTime,
            isRunning: isRunning,
            startTime: virtualStartTime
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        print("LiveActivityManager: Updating activity - isRunning: \(isRunning), elapsed: \(elapsedTime)")
        
        Task {
            await activity.update(content)
        }
    }
    
    /// End the current Live Activity
    func endCurrentActivity() async {
        for activity in Activity<TimerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("LiveActivityManager: Ended Live Activity: \(activity.id)")
        }
        currentActivity = nil
    }
    
    /// End all timer activities
    func endAllActivities() async {
        for activity in Activity<TimerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
    
    /// Check if Live Activities are available
    var areActivitiesAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}
