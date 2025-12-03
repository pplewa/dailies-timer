import SwiftUI

struct TimerRowView: View {
    @EnvironmentObject var timerManager: TimerManager
    let timer: TimerItem
    
    @State private var showingDeleteConfirmation = false
    @State private var offset: CGFloat = 0
    @State private var isPressing = false
    
    private var currentTimer: TimerItem {
        timerManager.timers.first { $0.id == timer.id } ?? timer
    }
    
    private var isActive: Bool {
        timerManager.activeTimerId == timer.id
    }
    
    var body: some View {
        ZStack {
            // Delete background
            HStack {
                Spacer()
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 80, height: 100)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            
            // Main card
            mainCard
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -80)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.smoothSpring) {
                                if value.translation.width < -40 {
                                    offset = -80
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .confirmationDialog("Delete Timer", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                withAnimation(.smoothSpring) {
                    timerManager.removeTimer(timer)
                }
                HapticManager.shared.notification(.warning)
            }
            Button("Cancel", role: .cancel) {
                withAnimation(.smoothSpring) {
                    offset = 0
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(timer.name)'?")
        }
    }
    
    private var mainCard: some View {
        Button {
            timerManager.selectedTimerForFullScreen = currentTimer
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 16) {
                // Timer indicator
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
                
                // Timer info
                VStack(alignment: .leading, spacing: 4) {
                    Text(timer.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(currentTimer.currentElapsedTime.formattedTimer)
                            .font(.system(.title2, design: .monospaced))
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
                        
                        if timer.referenceDuration > 0 {
                            Text("/ \(timer.formattedReferenceDuration)")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Quick action buttons
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
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressing ? 0.98 : 1.0)
        .animation(.quickSpring, value: isPressing)
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
            TimerRowView(timer: TimerItem(
                name: "Morning Routine",
                referenceDuration: 1800,
                elapsedTime: 600,
                isRunning: true
            ))
            
            TimerRowView(timer: TimerItem(
                name: "Workout",
                referenceDuration: 3600,
                elapsedTime: 0,
                isRunning: false
            ))
        }
        .padding()
        .environmentObject(TimerManager())
    }
    .preferredColorScheme(.dark)
}
