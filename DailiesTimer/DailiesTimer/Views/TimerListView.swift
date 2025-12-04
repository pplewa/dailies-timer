import SwiftUI

struct TimerListView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var sheetsService: GoogleSheetsService
    @State private var isRefreshing = false
    @State private var showingSyncAlert = false
    @State private var syncAlertMessage = ""
    @State private var isEditMode = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Sync status bar
                if sheetsService.isConfigured {
                    syncStatusBar
                }
                
                if timerManager.timers.isEmpty {
                    EmptyStateView()
                        .padding(.top, 60)
                } else {
                    ForEach(timerManager.timers) { timer in
                        TimerRowView(
                            timer: timer,
                            isEditMode: isEditMode,
                            onDelete: {
                                withAnimation(.smoothSpring) {
                                    timerManager.removeTimer(timer)
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
            }
            .padding()
            .animation(.smoothSpring, value: timerManager.timers.count)
            .animation(.smoothSpring, value: isEditMode)
        }
        .refreshable {
            await refreshData()
        }
        .overlay(alignment: .bottom) {
            if sheetsService.isSyncing {
                SyncIndicator()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Edit mode toggle button
            if !timerManager.timers.isEmpty {
                editModeButton
            }
        }
        .alert("Sync", isPresented: $showingSyncAlert) {
            Button("OK") {}
        } message: {
            Text(syncAlertMessage)
        }
    }
    
    private var editModeButton: some View {
        HStack {
            Spacer()
            
            Button {
                withAnimation(.smoothSpring) {
                    isEditMode.toggle()
                }
                HapticManager.shared.impact(.light)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isEditMode ? "checkmark" : "pencil")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(isEditMode ? "Done" : "Edit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isEditMode ? .appSuccess : .appText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isEditMode ? Color.appSuccess.opacity(0.2) : Color.appSurface)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
    }
    
    private var syncStatusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: sheetsService.autoSyncEnabled ? "arrow.triangle.2.circlepath.circle.fill" : "cloud")
                    .foregroundColor(sheetsService.autoSyncEnabled ? .appSuccess : .appTextSecondary)
                
                if sheetsService.autoSyncEnabled {
                    Text("Auto-sync")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.appSuccess)
                }
            }
            
            if let lastSync = sheetsService.lastSyncTime {
                Text("• \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            if sheetsService.canWrite {
                Button {
                    performTwoWaySync()
                } label: {
                    HStack(spacing: 4) {
                        if sheetsService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.appPrimary)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Sync Now")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.appPrimary.opacity(0.15))
                    )
                }
                .disabled(sheetsService.isSyncing)
            } else {
                Text("Read Only")
                    .font(.caption2)
                    .foregroundColor(.appWarning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appWarning.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appSurface)
        )
    }
    
    /// Performs full two-way sync with Google Sheets
    private func performTwoWaySync() {
        Task {
            do {
                try await timerManager.manualSync()
                HapticManager.shared.notification(.success)
                syncAlertMessage = "Two-way sync complete! Timers synced with Google Sheets."
                showingSyncAlert = true
            } catch {
                HapticManager.shared.notification(.error)
                syncAlertMessage = "Sync failed: \(error.localizedDescription)"
                showingSyncAlert = true
            }
        }
    }
    
    private func refreshData() async {
        guard sheetsService.isConfigured && sheetsService.canWrite else { return }
        
        do {
            try await timerManager.manualSync()
            HapticManager.shared.notification(.success)
        } catch {
            print("Sync error: \(error)")
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appPrimary.opacity(0.2), Color.appAccent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                
                Image(systemName: "timer")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(isAnimating ? 10 : -10))
            }
            .animation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            
            VStack(spacing: 8) {
                Text("No Timers Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appText)
                
                Text("Tap the + button to create\nyour first timer")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Sync Indicator

struct SyncIndicator: View {
    @State private var isRotating = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false),
                    value: isRotating
                )
            
            Text("Syncing...")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.appText)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.appSurface)
                .shadow(color: Color.black.opacity(0.3), radius: 10)
        )
        .padding(.bottom, 20)
        .onAppear {
            isRotating = true
        }
    }
}

#Preview {
    NavigationStack {
        TimerListView()
            .environmentObject(TimerManager())
            .environmentObject(GoogleSheetsService.shared)
    }
    .preferredColorScheme(.dark)
}
