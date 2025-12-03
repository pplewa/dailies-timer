import SwiftUI

struct AddTimerView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var isAnimating = false
    
    @FocusState private var isNameFocused: Bool
    
    private var totalSeconds: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Timer icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appPrimary.opacity(0.2), Color.appAccent.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                            
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.appPrimary, Color.appAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                        .padding(.top, 20)
                        
                        // Name input
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Timer Name", systemImage: "tag.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.appTextSecondary)
                            
                            TextField("e.g., Morning Routine", text: $name)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.appText)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.appSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isNameFocused ?
                                                    LinearGradient(
                                                        colors: [Color.appPrimary, Color.appAccent],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ) :
                                                    LinearGradient(
                                                        colors: [Color.appSecondary, Color.appSecondary],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .focused($isNameFocused)
                        }
                        .padding(.horizontal)
                        
                        // Duration picker
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Reference Duration (Optional)", systemImage: "clock.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.appTextSecondary)
                            
                            Text("This is for reference only - timers will count up indefinitely")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary.opacity(0.7))
                            
                            HStack(spacing: 0) {
                                // Hours
                                durationPicker(value: $hours, label: "hr", range: 0...23)
                                
                                Text(":")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appTextSecondary)
                                
                                // Minutes
                                durationPicker(value: $minutes, label: "min", range: 0...59)
                                
                                Text(":")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appTextSecondary)
                                
                                // Seconds
                                durationPicker(value: $seconds, label: "sec", range: 0...59)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appSurface)
                            )
                        }
                        .padding(.horizontal)
                        
                        // Quick duration presets
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Presets")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.appTextSecondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                presetButton(title: "5 min", h: 0, m: 5, s: 0)
                                presetButton(title: "15 min", h: 0, m: 15, s: 0)
                                presetButton(title: "30 min", h: 0, m: 30, s: 0)
                                presetButton(title: "45 min", h: 0, m: 45, s: 0)
                                presetButton(title: "1 hr", h: 1, m: 0, s: 0)
                                presetButton(title: "2 hr", h: 2, m: 0, s: 0)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                        
                        // Create button
                        Button {
                            createTimer()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Timer")
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: isValid ?
                                    [Color.appPrimary, Color.appAccent] :
                                    [Color.appSecondary, Color.appSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(
                                color: isValid ? Color.appPrimary.opacity(0.4) : Color.clear,
                                radius: 15,
                                y: 5
                            )
                        }
                        .disabled(!isValid)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appTextSecondary)
                }
            }
            .onAppear {
                isAnimating = true
                isNameFocused = true
            }
        }
    }
    
    private func durationPicker(value: Binding<Int>, label: String, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Picker(label, selection: value) {
                ForEach(range, id: \.self) { num in
                    Text(String(format: "%02d", num))
                        .tag(num)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70, height: 100)
            .clipped()
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.appTextSecondary)
        }
    }
    
    private func presetButton(title: String, h: Int, m: Int, s: Int) -> some View {
        Button {
            hours = h
            minutes = m
            seconds = s
            HapticManager.shared.selection()
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isPresetSelected(h: h, m: m, s: s) ? .white : .appText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isPresetSelected(h: h, m: m, s: s) ?
                            LinearGradient(
                                colors: [Color.appPrimary, Color.appAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [Color.appSecondary, Color.appSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func isPresetSelected(h: Int, m: Int, s: Int) -> Bool {
        hours == h && minutes == m && seconds == s
    }
    
    private func createTimer() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        timerManager.addTimer(
            name: trimmedName,
            referenceDuration: totalSeconds
        )
        
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

#Preview {
    AddTimerView()
        .environmentObject(TimerManager())
        .preferredColorScheme(.dark)
}

