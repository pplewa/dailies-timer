import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

// MARK: - Timeline Provider

struct TimerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(
            date: Date(),
            timerName: "Timer",
            elapsedTime: 0,
            isRunning: false,
            hasTimer: true,
            referenceDuration: 0
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        let state = SharedDefaults.loadWidgetState()
        let timers = SharedDefaults.loadTimers()
        let activeTimer = timers.first { $0.id == state.activeTimerId }
        
        let entry = TimerEntry(
            date: Date(),
            timerName: state.activeTimerName ?? "No Timer",
            elapsedTime: state.elapsedTime,
            isRunning: state.isRunning,
            hasTimer: state.activeTimerId != nil,
            referenceDuration: activeTimer?.referenceDuration ?? 0
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let state = SharedDefaults.loadWidgetState()
        let timers = SharedDefaults.loadTimers()
        let activeTimer = timers.first { $0.id == state.activeTimerId }
        
        var entries: [TimerEntry] = []
        let currentDate = Date()
        
        if state.isRunning {
            // Update every second while running
            for secondOffset in 0..<60 {
                let entryDate = Calendar.current.date(byAdding: .second, value: secondOffset, to: currentDate)!
                let elapsed = state.elapsedTime + Double(secondOffset)
                
                let entry = TimerEntry(
                    date: entryDate,
                    timerName: state.activeTimerName ?? "Timer",
                    elapsedTime: elapsed,
                    isRunning: true,
                    hasTimer: state.activeTimerId != nil,
                    referenceDuration: activeTimer?.referenceDuration ?? 0
                )
                entries.append(entry)
            }
        } else {
            // Static entry when paused or no timer
            let entry = TimerEntry(
                date: currentDate,
                timerName: state.activeTimerName ?? "No Timer",
                elapsedTime: state.elapsedTime,
                isRunning: false,
                hasTimer: state.activeTimerId != nil,
                referenceDuration: activeTimer?.referenceDuration ?? 0
            )
            entries.append(entry)
        }
        
        let refreshDate = Calendar.current.date(byAdding: .second, value: 60, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
}

// MARK: - Entry

struct TimerEntry: TimelineEntry {
    let date: Date
    let timerName: String
    let elapsedTime: TimeInterval
    let isRunning: Bool
    let hasTimer: Bool
    let referenceDuration: TimeInterval
    
    var formattedTime: String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        guard referenceDuration > 0 else { return 0 }
        return min(elapsedTime / referenceDuration, 1.0)
    }
}

// MARK: - Widget Views

struct TimerWidgetEntryView: View {
    var entry: TimerEntry
    @Environment(\.widgetFamily) var family
    
    // App colors
    let appPrimary = Color(red: 0.914, green: 0.271, blue: 0.376)
    let appSuccess = Color(red: 0.306, green: 0.804, blue: 0.769)
    let appBackground = Color(red: 0.102, green: 0.102, blue: 0.180)
    let appSurface = Color(red: 0.086, green: 0.129, blue: 0.243)
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .accessoryCircular:
            circularWidget
        case .accessoryRectangular:
            rectangularWidget
        case .accessoryInline:
            inlineWidget
        default:
            smallWidget
        }
    }
    
    // MARK: - Small Widget
    
    private var smallWidget: some View {
        VStack(spacing: 8) {
            if entry.hasTimer {
                // Status indicator
                HStack {
                    Circle()
                        .fill(entry.isRunning ? appSuccess : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(entry.timerName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Spacer()
                
                // Time display
                Text(entry.formattedTime)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(entry.isRunning ? .primary : .secondary)
                    .minimumScaleFactor(0.5)
                
                // Progress bar if reference duration set
                if entry.referenceDuration > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(appPrimary)
                                .frame(width: geo.size.width * entry.progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                
                Spacer()
                
                // Toggle button
                Link(destination: URL(string: "dailies-timer://toggle")!) {
                    HStack {
                        Image(systemName: entry.isRunning ? "pause.fill" : "play.fill")
                        Text(entry.isRunning ? "Pause" : "Start")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(entry.isRunning ? Color.orange : appSuccess)
                    )
                }
            } else {
                // No active timer state
                Spacer()
                
                Image(systemName: "timer")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                
                Text("No Active Timer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Link(destination: URL(string: "dailies-timer://open")!) {
                    Text("Open App")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(appPrimary)
                        )
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            appSurface
        }
    }
    
    // MARK: - Medium Widget
    
    private var mediumWidget: some View {
        HStack(spacing: 16) {
            if entry.hasTimer {
                // Left side - Timer info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(entry.isRunning ? appSuccess : Color.gray)
                            .frame(width: 10, height: 10)
                        
                        Text(entry.timerName)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                    
                    Text(entry.formattedTime)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(entry.isRunning ? .primary : .secondary)
                        .minimumScaleFactor(0.5)
                    
                    HStack {
                        Text(entry.isRunning ? "Running" : "Paused")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if entry.referenceDuration > 0 {
                            Text("•")
                                .foregroundColor(.secondary)
                            let percentage = Int(entry.progress * 100)
                            Text("\(percentage)%")
                                .font(.caption)
                                .foregroundColor(appPrimary)
                        }
                    }
                }
                
                Spacer()
                
                // Right side - Controls
                VStack(spacing: 12) {
                    Link(destination: URL(string: "dailies-timer://toggle")!) {
                        Circle()
                            .fill(entry.isRunning ? Color.orange : appSuccess)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: entry.isRunning ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    Text(entry.isRunning ? "Pause" : "Start")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No Active Timer")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Open app to start a timer")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            appSurface
        }
    }
    
    // MARK: - Lock Screen Widgets
    
    private var circularWidget: some View {
        ZStack {
            if entry.hasTimer {
                // Progress ring
                if entry.referenceDuration > 0 {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                
                VStack(spacing: 2) {
                    Image(systemName: entry.isRunning ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                    
                    Text(shortTime)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.5)
                }
            } else {
                Image(systemName: "timer")
                    .font(.title3)
            }
        }
        .widgetURL(URL(string: "dailies-timer://toggle"))
    }
    
    private var rectangularWidget: some View {
        HStack(spacing: 8) {
            if entry.hasTimer {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.isRunning ? "play.fill" : "pause.fill")
                            .font(.caption2)
                        Text(entry.timerName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    
                    Text(entry.formattedTime)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("No Timer")
                }
                .font(.caption)
            }
            
            Spacer()
        }
        .widgetURL(URL(string: "dailies-timer://toggle"))
    }
    
    private var inlineWidget: some View {
        if entry.hasTimer {
            Label(
                "\(entry.timerName): \(entry.formattedTime)",
                systemImage: entry.isRunning ? "play.fill" : "pause.fill"
            )
        } else {
            Label("No Timer", systemImage: "timer")
        }
    }
    
    private var shortTime: String {
        let total = Int(entry.elapsedTime)
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Widget Configuration

struct TimerWidget: Widget {
    let kind: String = "TimerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerTimelineProvider()) { entry in
            TimerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Timer")
        .description("Track your current timer from the Home Screen or Lock Screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Live Activity Widget

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedTime: TimeInterval
        var isRunning: Bool
        var startTime: Date?
    }
    
    var timerName: String
    var timerId: String
    var referenceDuration: TimeInterval
}

struct TimerLiveActivityView: View {
    let context: ActivityViewContext<TimerActivityAttributes>
    
    let appPrimary = Color(red: 0.914, green: 0.271, blue: 0.376)
    let appSuccess = Color(red: 0.306, green: 0.804, blue: 0.769)
    
    var formattedTime: String {
        let total = Int(context.state.elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        guard context.attributes.referenceDuration > 0 else { return 0 }
        return min(context.state.elapsedTime / context.attributes.referenceDuration, 1.0)
    }
    
    // Check if we have a valid running timer
    var isTimerActive: Bool {
        context.state.startTime != nil
    }
    
    var body: some View {
        HStack {
            // Timer info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.timerName)
                    .font(.headline)
                    .lineLimit(1)
                
                // ALWAYS use live timer if we have a startTime
                if let startTime = context.state.startTime {
                    Text(timerInterval: startTime...Date.distantFuture, countsDown: false)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                } else {
                    Text(formattedTime)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Control button - shows based on whether timer is active
            Link(destination: URL(string: "dailies-timer://toggle")!) {
                Circle()
                    .fill(isTimerActive ? Color.orange : appSuccess)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: isTimerActive ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding()
    }
}

// MARK: - Live Activity Configuration

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock screen / banner UI
            TimerLiveActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.086, green: 0.129, blue: 0.243))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.timerName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(context.state.startTime != nil ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(context.state.startTime != nil ? "Running" : "Paused")
                                .font(.caption2)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "dailies-timer://toggle")!) {
                        Image(systemName: context.state.startTime != nil ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(context.state.startTime != nil ? .orange : .green)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    if let startTime = context.state.startTime {
                        Text(timerInterval: startTime...Date.distantFuture, countsDown: false)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                    } else {
                        let total = Int(context.state.elapsedTime)
                        let hours = total / 3600
                        let minutes = (total % 3600) / 60
                        let seconds = total % 60
                        
                        Text(hours > 0 ?
                             String(format: "%d:%02d:%02d", hours, minutes, seconds) :
                             String(format: "%02d:%02d", minutes, seconds))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if context.attributes.referenceDuration > 0 {
                        let progress = min(context.state.elapsedTime / context.attributes.referenceDuration, 1.0)
                        ProgressView(value: progress)
                            .tint(Color(red: 0.914, green: 0.271, blue: 0.376))
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.startTime != nil ? "play.fill" : "pause.fill")
                    .foregroundStyle(context.state.startTime != nil ? .green : .orange)
            } compactTrailing: {
                if let startTime = context.state.startTime {
                    Text(timerInterval: startTime...Date.distantFuture, countsDown: false)
                        .font(.system(size: 14, design: .monospaced))
                        .monospacedDigit()
                        .frame(width: 56)
                } else {
                    let total = Int(context.state.elapsedTime)
                    let minutes = (total % 3600) / 60
                    let seconds = total % 60
                    Text(String(format: "%d:%02d", minutes, seconds))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                Image(systemName: context.state.startTime != nil ? "play.fill" : "pause.fill")
                    .foregroundStyle(context.state.startTime != nil ? .green : .orange)
            }
            .widgetURL(URL(string: "dailies-timer://toggle"))
        }
    }
}

// MARK: - Control Widget (iOS 18+)

@available(iOS 18.0, *)
struct TimerControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "TimerControl") {
            ControlWidgetButton(action: ToggleTimerIntent()) {
                let state = SharedDefaults.loadWidgetState()
                
                Label(
                    state.isRunning ? "Pause" : "Start",
                    systemImage: state.isRunning ? "pause.fill" : "play.fill"
                )
            }
        }
        .displayName("Timer Control")
        .description("Pause or resume your timer.")
    }
}

// MARK: - App Intents

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Timer"
    static var description = IntentDescription("Pause or resume the current timer")
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    TimerWidget()
} timeline: {
    TimerEntry(date: Date(), timerName: "Morning Routine", elapsedTime: 754, isRunning: true, hasTimer: true, referenceDuration: 1800)
    TimerEntry(date: Date(), timerName: "Workout", elapsedTime: 1800, isRunning: false, hasTimer: true, referenceDuration: 3600)
}

#Preview(as: .systemMedium) {
    TimerWidget()
} timeline: {
    TimerEntry(date: Date(), timerName: "Morning Routine", elapsedTime: 754, isRunning: true, hasTimer: true, referenceDuration: 1800)
}

#Preview(as: .accessoryCircular) {
    TimerWidget()
} timeline: {
    TimerEntry(date: Date(), timerName: "Timer", elapsedTime: 125, isRunning: true, hasTimer: true, referenceDuration: 300)
}
