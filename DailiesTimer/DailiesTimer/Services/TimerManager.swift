import Foundation
import SwiftUI
import Combine
import WidgetKit
import ActivityKit
import UIKit

/// Manages all timer operations and state
@MainActor
class TimerManager: ObservableObject {
    @Published var timers: [TimerItem] = []
    @Published var activeTimerId: UUID?
    @Published var selectedTimerForFullScreen: TimerItem?
    
    private var displayTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Track brightness before going to background
    private var brightnessBeforeBackground: CGFloat = 1.0
    private var resignActiveTime: Date?
    
    var activeTimer: TimerItem? {
        guard let id = activeTimerId else { return nil }
        return timers.first { $0.id == id }
    }
    
    init() {
        loadState()
        setupDisplayTimer()
        setupAppLifecycleObservers()
    }
    
    deinit {
        displayTimer?.invalidate()
    }
    
    // MARK: - Timer Management
    
    func addTimer(name: String, referenceDuration: TimeInterval) {
        let timer = TimerItem(
            name: name,
            referenceDuration: referenceDuration
        )
        timers.append(timer)
        saveState()
        triggerAutoSync()
    }
    
    func removeTimer(_ timer: TimerItem) {
        if timer.id == activeTimerId {
            stopTimer(timer)
        }
        timers.removeAll { $0.id == timer.id }
        saveState()
        triggerAutoSync()
    }
    
    func startTimer(_ timer: TimerItem) {
        // Stop any currently running timer first
        if let currentActiveId = activeTimerId,
           let index = timers.firstIndex(where: { $0.id == currentActiveId }) {
            timers[index].isRunning = false
            if let startTime = timers[index].lastStartTime {
                timers[index].elapsedTime += Date().timeIntervalSince(startTime)
            }
            timers[index].lastStartTime = nil
        }
        
        // Start the new timer
        if let index = timers.firstIndex(where: { $0.id == timer.id }) {
            timers[index].isRunning = true
            timers[index].lastStartTime = Date()
            activeTimerId = timer.id
            
            // Start Live Activity
            let currentElapsed = timers[index].elapsedTime
            LiveActivityManager.shared.startActivity(
                for: timers[index],
                currentElapsedTime: currentElapsed
            )
        }
        
        saveState()
        updateWidget()
        triggerAutoSync()
    }
    
    func pauseTimer(_ timer: TimerItem) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        
        if let startTime = timers[index].lastStartTime {
            timers[index].elapsedTime += Date().timeIntervalSince(startTime)
        }
        timers[index].isRunning = false
        timers[index].lastStartTime = nil
        
        // Update Live Activity to show paused state
        LiveActivityManager.shared.updateActivity(
            elapsedTime: timers[index].elapsedTime,
            isRunning: false
        )
        
        saveState()
        updateWidget()
        triggerAutoSync()
    }
    
    func toggleTimer(_ timer: TimerItem) {
        if timer.isRunning {
            pauseTimer(timer)
        } else {
            startTimer(timer)
        }
    }
    
    /// Stop timer - keeps elapsed time but removes from widget/Dynamic Island
    func stopTimer(_ timer: TimerItem) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        
        // Save elapsed time if running
        if let startTime = timers[index].lastStartTime {
            timers[index].elapsedTime += Date().timeIntervalSince(startTime)
        }
        timers[index].isRunning = false
        timers[index].lastStartTime = nil
        
        // Clear active timer - this removes from widget
        if activeTimerId == timer.id {
            activeTimerId = nil
        }
        
        // End Live Activity - removes from Dynamic Island and lock screen
        Task {
            await LiveActivityManager.shared.endCurrentActivity()
        }
        
        saveState()
        updateWidget()
        triggerAutoSync()
    }
    
    func resetTimer(_ timer: TimerItem) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        
        timers[index].elapsedTime = 0
        timers[index].isRunning = false
        timers[index].lastStartTime = nil
        timers[index].lastResetTime = Date() // Track reset time to prevent sync overwrite
        
        if activeTimerId == timer.id {
            activeTimerId = nil
            Task {
                await LiveActivityManager.shared.endCurrentActivity()
            }
        }
        
        saveState()
        updateWidget()
        triggerAutoSync()
    }
    
    func updateTimerName(_ timer: TimerItem, newName: String) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        timers[index].name = newName
        saveState()
        updateWidget()
        triggerAutoSync()
    }
    
    func updateTimerDuration(_ timer: TimerItem, newDuration: TimeInterval) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        timers[index].referenceDuration = newDuration
        saveState()
        triggerAutoSync()
    }
    
    // MARK: - Google Sheets Sync
    
    private func triggerAutoSync() {
        GoogleSheetsService.shared.triggerAutoSync(timers: timers) { [weak self] updatedTimers in
            guard let self = self else { return }
            // Update local timers with any higher values from remote
            self.applyRemoteUpdates(updatedTimers)
        }
    }
    
    private func applyRemoteUpdates(_ remoteTimers: [TimerItem]) {
        var hasChanges = false
        
        for remoteTimer in remoteTimers {
            if let localIndex = timers.firstIndex(where: { $0.id == remoteTimer.id }) {
                // Only update if not running and remote has higher value
                if !timers[localIndex].isRunning && 
                   remoteTimer.elapsedTime > timers[localIndex].elapsedTime {
                    timers[localIndex].elapsedTime = remoteTimer.elapsedTime
                    hasChanges = true
                }
            } else {
                // New timer from remote
                timers.append(remoteTimer)
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveState()
            updateWidget()
        }
    }
    
    /// Manual sync - performs full two-way sync
    func manualSync() async throws {
        let updatedTimers = try await GoogleSheetsService.shared.twoWaySync(localTimers: timers)
        await MainActor.run {
            applyRemoteUpdates(updatedTimers)
        }
    }
    
    // MARK: - Display Timer
    
    private func setupDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }
    
    // MARK: - App Lifecycle
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleWillResignActive()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleDidEnterBackground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleDidBecomeActive()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppWillTerminate()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleWillResignActive() {
        brightnessBeforeBackground = UIScreen.main.brightness
        resignActiveTime = Date()
    }
    
    private func handleDidEnterBackground() {
        let currentBrightness = UIScreen.main.brightness
        let timeSinceResign = resignActiveTime.map { Date().timeIntervalSince($0) } ?? 1.0
        
        let brightnessDropped = currentBrightness < 0.01
        let quickTransition = timeSinceResign < 0.3
        let isLockScreen = brightnessDropped || (quickTransition && currentBrightness < brightnessBeforeBackground * 0.5)
        
        if !isLockScreen {
            if let activeId = activeTimerId,
               let timer = timers.first(where: { $0.id == activeId }),
               timer.isRunning {
                pauseTimer(timer)
            }
        }
        
        saveState()
        updateWidget()
    }
    
    private func handleDidBecomeActive() {
        resignActiveTime = nil
        
        // Sync on app becoming active (fetch any remote updates)
        triggerAutoSync()
    }
    
    private func handleAppWillTerminate() {
        if let activeId = activeTimerId,
           let index = timers.firstIndex(where: { $0.id == activeId }),
           timers[index].isRunning {
            if let startTime = timers[index].lastStartTime {
                timers[index].elapsedTime += Date().timeIntervalSince(startTime)
            }
            timers[index].isRunning = false
            timers[index].lastStartTime = nil
        }
        
        saveState()
        updateWidget()
        
        Task {
            await LiveActivityManager.shared.endAllActivities()
        }
    }
    
    // MARK: - Persistence
    
    private func saveState() {
        SharedDefaults.saveTimers(timers)
        SharedDefaults.saveActiveTimerId(activeTimerId)
    }
    
    private func loadState() {
        timers = SharedDefaults.loadTimers()
        activeTimerId = SharedDefaults.loadActiveTimerId()
        
        for index in timers.indices {
            if timers[index].isRunning {
                if let startTime = timers[index].lastStartTime {
                    timers[index].elapsedTime += Date().timeIntervalSince(startTime)
                }
                timers[index].lastStartTime = Date()
                
                LiveActivityManager.shared.startActivity(
                    for: timers[index],
                    currentElapsedTime: timers[index].elapsedTime
                )
            }
        }
        
        saveState()
    }
    
    // MARK: - Widget Updates
    
    private func updateWidget() {
        var state = TimerWidgetState.empty
        
        if let activeId = activeTimerId,
           let timer = timers.first(where: { $0.id == activeId }) {
            state = TimerWidgetState(
                activeTimerId: activeId,
                activeTimerName: timer.name,
                elapsedTime: timer.currentElapsedTime,
                isRunning: timer.isRunning,
                lastUpdated: Date()
            )
        }
        
        SharedDefaults.saveWidgetState(state)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Widget Actions
    
    func handleWidgetToggle() {
        if let activeId = activeTimerId,
           let timer = timers.first(where: { $0.id == activeId }) {
            toggleTimer(timer)
        }
    }
}
