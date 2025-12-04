import SwiftUI

struct TimerRowView: View {
    @EnvironmentObject var timerManager: TimerManager
    let timer: TimerItem
    let isEditMode: Bool
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    private var currentTimer: TimerItem {
        timerManager.timers.first { $0.id == timer.id } ?? timer
    }
    
    private var isActive: Bool {
        timerManager.activeTimerId == timer.id
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Delete button (edit mode only)
            if isEditMode {
                Button {
                    showingDeleteConfirmation = true
                    HapticManager.shared.impact(.medium)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.trailing, 12)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            // Main card
            Button {
                guard !isEditMode else { return }
                timerManager.selectedTimerForFullScreen = currentTimer
                HapticManager.shared.impact(.medium)
            } label: {
                mainCardContent
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isEditMode)
        }
        .confirmationDialog("Delete Timer", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
                HapticManager.shared.notification(.warning)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(timer.name)'?")
        }
    }
    
    private var mainCardContent: some View {
        HStack(spacing: 12) {
            // Timer indicator circle
            timerIndicator
            
            // Timer info (name + time)
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appText)
                    .lineLimit(1)
                
                timerTimeDisplay
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Quick action buttons (hide in edit mode)
            if !isEditMode {
                actionButtons
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isActive ?
                            LinearGradient(
                                colors: [Color.appPrimary.opacity(0.5), Color.appAccent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isActive ? Color.appPrimary.opacity(0.2) : Color.black.opacity(0.2),
                    radius: isActive ? 15 : 10,
                    x: 0,
                    y: 5
                )
        )
        .opacity(isEditMode ? 0.8 : 1.0)
    }
    
    private var timerIndicator: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.appSecondary, Color.appSecondary.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 4
                )
                .frame(width: 56, height: 56)
            
            if currentTimer.referenceDuration > 0 {
                Circle()
                    .trim(from: 0, to: min(currentTimer.progress, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: progressColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
            }
            
            if currentTimer.isRunning {
                Circle()
                    .fill(Color.appSuccess)
                    .frame(width: 12, height: 12)
                    .glowEffect(color: .appSuccess, radius: 8)
            } else if isActive {
                Circle()
                    .fill(Color.appWarning)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(Color.appTextSecondary.opacity(0.5))
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    private var timerTimeDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(currentTimer.currentElapsedTime.formattedTimerCompact)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(
                    currentTimer.isRunning ?
                    LinearGradient(
                        colors: [Color.appPrimary, Color.appAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.appTextSecondary, Color.appTextSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(1)
            
            if timer.referenceDuration > 0 {
                Text("/ \(timer.formattedReferenceDurationCompact)")
                    .font(.caption2)
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Play/Pause button
            Button {
                timerManager.toggleTimer(timer)
                HapticManager.shared.impact(.light)
            } label: {
                Image(systemName: currentTimer.isRunning ? "pause.fill" : "play.fill")
                    .font(.body)
                    .foregroundColor(.appText)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: currentTimer.isRunning ?
                                    [Color.appWarning.opacity(0.3), Color.appWarning.opacity(0.1)] :
                                    [Color.appSuccess.opacity(0.3), Color.appSuccess.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Stop button (only show if active)
            if isActive {
                Button {
                    timerManager.stopTimer(timer)
                    HapticManager.shared.impact(.light)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.body)
                        .foregroundColor(.appText)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.appPrimary.opacity(0.3))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            // Reset button
            Button {
                timerManager.resetTimer(timer)
                HapticManager.shared.impact(.light)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
                    .foregroundColor(.appTextSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.appSecondary.opacity(0.3))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    private var progressColors: [Color] {
        if currentTimer.hasExceededReference {
            return [Color.appWarning, Color.red]
        }
        return [Color.appPrimary, Color.appAccent]
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.quickSpring, value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        
        VStack(spacing: 16) {
            TimerRowView(
                timer: TimerItem(
                    name: "Morning Routine",
                    referenceDuration: 1800,
                    elapsedTime: 600,
                    isRunning: true
                ),
                isEditMode: false,
                onDelete: {}
            )
            
            TimerRowView(
                timer: TimerItem(
                    name: "Workout",
                    referenceDuration: 3600,
                    elapsedTime: 0,
                    isRunning: false
                ),
                isEditMode: true,
                onDelete: {}
            )
        }
        .padding()
        .environmentObject(TimerManager())
    }
    .preferredColorScheme(.dark)
}
