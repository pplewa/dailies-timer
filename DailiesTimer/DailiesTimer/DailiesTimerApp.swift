import SwiftUI

@main
struct DailiesTimerApp: App {
    @StateObject private var timerManager = TimerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(GoogleSheetsService.shared)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle widget deep links
        guard url.scheme == "dailies-timer" else { return }
        
        switch url.host {
        case "toggle":
            timerManager.handleWidgetToggle()
        default:
            break
        }
    }
}
