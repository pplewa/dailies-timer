import SwiftUI

struct FullScreenTimerView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Environment(\.dismiss) var dismiss
    let timer: TimerItem
    
    @State private var pulseAnimation = false
    @State private var ringProgress: CGFloat = 0
    
    private var currentTimer: TimerItem {
        timerManager.timers.first { $0.id == timer.id } ?? timer
    }
    
    private var isActive: Bool {
        timerManager.activeTimerId == timer.id
    }
    
    var body: some View {
        ZStack {
            // Dynamic background
            backgroundGradient
            
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 16)
                
                Spacer()
                
                // Main timer display
                timerDisplay
                
                Spacer()
                
                // Controls
                controls
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                        HapticManager.shared.impact(.light)
                    }
                }
        )
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.appBackground,
                    currentTimer.isRunning ? Color.appPrimary.opacity(0.15) : Color.appSecondary.opacity(0.1),
                    Color.appBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated circles
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.appPrimary.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.3)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.3 : 0.5)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.appAccent.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.6)
                    .position(x: geo.size.width * 0.8, y: geo.size.height * 0.7)
                    .scaleEffect(pulseAnimation ? 1.0 : 1.2)
                    .opacity(pulseAnimation ? 0.5 : 0.3)
            }
        }
        .animation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true),
            value: pulseAnimation
        )
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button {
                dismiss()
                HapticManager.shared.impact(.light)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.appTextSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.appSurface.opacity(0.5))
                    )
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(timer.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.appText)
                
                if timer.referenceDuration > 0 {
                    Text("Target: \(timer.formattedReferenceDuration)")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            currentTimer.isRunning ? Color.appPrimary.opacity(0.3) : Color.appSecondary.opacity(0.2),
                            currentTimer.isRunning ? Color.appAccent.opacity(0.1) : Color.appSecondary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 320, height: 320)
                .scaleEffect(pulseAnimation && currentTimer.isRunning ? 1.05 : 1.0)
            
            // Background ring
            Circle()
                .stroke(Color.appSecondary.opacity(0.3), lineWidth: 12)
                .frame(width: 280, height: 280)
            
            // Progress ring
            if timer.referenceDuration > 0 {
                Circle()
                    .trim(from: 0, to: min(currentTimer.progress, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: progressColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: currentTimer.progress)
            }
            
            // Timer text
            VStack(spacing: 8) {
                Text(currentTimer.currentElapsedTime.formattedTimerWithMillis)
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appText, Color.appText.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shimmer(isActive: currentTimer.isRunning)
                
                if currentTimer.isRunning {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.appSuccess)
                            .frame(width: 8, height: 8)
                            .glowEffect(color: .appSuccess, radius: 6)
                        
                        Text("RUNNING")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.appSuccess)
                            .tracking(2)
                    }
                } else if isActive {
                    Text("PAUSED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.appWarning)
                        .tracking(2)
                } else {
                    Text("STOPPED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.appTextSecondary)
                        .tracking(2)
                }
                
                if timer.referenceDuration > 0 {
                    let percentage = Int(min(currentTimer.progress * 100, 999))
                    Text("\(percentage)%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(currentTimer.hasExceededReference ? .appWarning : .appTextSecondary)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        HStack(spacing: 24) {
            // Reset button
            Button {
                timerManager.resetTimer(timer)
                HapticManager.shared.notification(.warning)
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.appSurface)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                        
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.appTextSecondary)
                    }
                    
                    Text("Reset")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Play/Pause button
            Button {
                timerManager.toggleTimer(timer)
                HapticManager.shared.impact(.medium)
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: currentTimer.isRunning ?
                                    [Color.appWarning, Color.appWarning.opacity(0.7)] :
                                    [Color.appPrimary, Color.appAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(
                                color: currentTimer.isRunning ?
                                Color.appWarning.opacity(0.4) :
                                Color.appPrimary.opacity(0.4),
                                radius: 15,
                                y: 5
                            )
                        
                        Image(systemName: currentTimer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .offset(x: currentTimer.isRunning ? 0 : 2)
                    }
                    .scaleEffect(pulseAnimation && currentTimer.isRunning ? 1.05 : 1.0)
                    
                    Text(currentTimer.isRunning ? "Pause" : "Start")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.appText)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Stop button
            Button {
                timerManager.stopTimer(timer)
                HapticManager.shared.impact(.medium)
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.appSurface)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                        
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(isActive ? .appPrimary : .appTextSecondary)
                    }
                    
                    Text("Stop")
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .opacity(isActive || currentTimer.isRunning ? 1 : 0.5)
        }
    }
    
    // MARK: - Helpers
    
    private var progressColors: [Color] {
        if currentTimer.hasExceededReference {
            return [Color.appWarning, Color.red]
        }
        return [Color.appPrimary, Color.appAccent]
    }
    
    private func startAnimations() {
        pulseAnimation = true
    }
}

#Preview {
    FullScreenTimerView(timer: TimerItem(
        name: "Morning Routine",
        referenceDuration: 1800,
        elapsedTime: 600,
        isRunning: true
    ))
    .environmentObject(TimerManager())
    .preferredColorScheme(.dark)
}
