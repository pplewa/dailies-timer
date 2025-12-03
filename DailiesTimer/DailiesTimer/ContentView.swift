import SwiftUI

struct ContentView: View {
    @EnvironmentObject var timerManager: TimerManager
    @State private var showingAddTimer = false
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            // Animated background
            AnimatedBackground()
            
            NavigationStack {
                TimerListView()
                    .navigationTitle("Dailies")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingAddTimer = true
                                HapticManager.shared.impact(.light)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.appPrimary, Color.appAccent],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showingSettings = true
                                HapticManager.shared.impact(.light)
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                    }
            }
            .tint(Color.appPrimary)
        }
        .sheet(isPresented: $showingAddTimer) {
            AddTimerView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(item: $timerManager.selectedTimerForFullScreen) { timer in
            FullScreenTimerView(timer: timer)
        }
    }
}

// MARK: - Animated Background

struct AnimatedBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.appBackground,
                Color.appSurface,
                Color.appSecondary.opacity(0.3)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
        .overlay(
            // Subtle noise texture
            GeometryReader { geo in
                Canvas { context, size in
                    for _ in 0..<100 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(0.02))
                        )
                    }
                }
            }
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var sheetsService: GoogleSheetsService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAuthMethod: GoogleAuthMethod = .serviceAccount
    
    // API Key fields
    @State private var apiKey = ""
    
    // Service Account fields
    @State private var serviceAccountEmail = ""
    @State private var privateKey = ""
    
    // Common fields
    @State private var spreadsheetId = ""
    @State private var sheetName = "Timers"
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Google Sheets Configuration
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Google Sheets Sync", systemImage: "tablecells")
                                .font(.headline)
                                .foregroundColor(.appText)
                            
                            // Auth Method Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Authentication Method")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                                
                                Picker("Auth Method", selection: $selectedAuthMethod) {
                                    ForEach(GoogleAuthMethod.allCases, id: \.self) { method in
                                        Text(method.rawValue).tag(method)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                if selectedAuthMethod == .apiKey {
                                    Text("⚠️ API Keys can only READ data. Use Service Account to sync/write.")
                                        .font(.caption)
                                        .foregroundColor(.appWarning)
                                        .padding(.top, 4)
                                }
                            }
                            
                            VStack(spacing: 12) {
                                if selectedAuthMethod == .apiKey {
                                    CustomTextField(
                                        title: "API Key",
                                        text: $apiKey,
                                        placeholder: "Enter your API key",
                                        isSecure: true
                                    )
                                } else {
                                    CustomTextField(
                                        title: "Service Account Email",
                                        text: $serviceAccountEmail,
                                        placeholder: "xxx@project.iam.gserviceaccount.com"
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Private Key")
                                            .font(.caption)
                                            .foregroundColor(.appTextSecondary)
                                        
                                        TextEditor(text: $privateKey)
                                            .font(.system(.caption2, design: .monospaced))
                                            .frame(minHeight: 120, maxHeight: 180)
                                            .padding(8)
                                            .background(Color.appBackground)
                                            .foregroundColor(.appText)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.appSecondary, lineWidth: 1)
                                            )
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                        
                                        Text("Copy the entire \"private_key\" value from your JSON file (including -----BEGIN/END PRIVATE KEY-----)")
                                            .font(.caption2)
                                            .foregroundColor(.appTextSecondary.opacity(0.7))
                                    }
                                }
                                
                                CustomTextField(
                                    title: "Spreadsheet ID",
                                    text: $spreadsheetId,
                                    placeholder: "From URL: /spreadsheets/d/{THIS_PART}/edit"
                                )
                                
                                CustomTextField(
                                    title: "Sheet Name",
                                    text: $sheetName,
                                    placeholder: "Timers"
                                )
                            }
                            
                            // Auto-sync Toggle (only for Service Account)
                            if selectedAuthMethod == .serviceAccount {
                                Toggle(isOn: Binding(
                                    get: { sheetsService.autoSyncEnabled },
                                    set: { sheetsService.setAutoSync($0) }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Auto-sync")
                                            .font(.subheadline)
                                            .foregroundColor(.appText)
                                        Text("Automatically sync when timers start/pause/stop")
                                            .font(.caption)
                                            .foregroundColor(.appTextSecondary)
                                    }
                                }
                                .tint(.appPrimary)
                                .padding(.vertical, 4)
                            }
                            
                            // Action Buttons
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Button {
                                        saveConfiguration()
                                    } label: {
                                        Text("Save")
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.appPrimary)
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    
                                    if sheetsService.isConfigured {
                                        Button {
                                            sheetsService.clearConfiguration()
                                            clearFields()
                                        } label: {
                                            Text("Clear")
                                                .fontWeight(.semibold)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.appSecondary)
                                                .foregroundColor(.appText)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                                
                                // Test Connection Button
                                Button {
                                    testConnection()
                                } label: {
                                    HStack {
                                        if sheetsService.isSyncing {
                                            ProgressView()
                                                .tint(.white)
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "network")
                                        }
                                        Text("Test Connection")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.appSuccess.opacity(0.8), Color.appSuccess],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .disabled(sheetsService.isSyncing || !canTest)
                                .opacity(canTest ? 1 : 0.5)
                            }
                            
                            // Status Messages
                            if sheetsService.isConfigured {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.appSuccess)
                                    Text("Configured (\(sheetsService.authMethod.rawValue))")
                                        .foregroundColor(.appSuccess)
                                    
                                    if !sheetsService.canWrite {
                                        Text("• Read Only")
                                            .foregroundColor(.appWarning)
                                    }
                                }
                                .font(.caption)
                            }
                            
                            // Test Result
                            if let result = sheetsService.testResult {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .appSuccess : .red)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.message)
                                            .foregroundColor(result.success ? .appSuccess : .red)
                                        Text(result.timestamp, style: .time)
                                            .foregroundColor(.appTextSecondary)
                                    }
                                }
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(result.success ? Color.appSuccess.opacity(0.1) : Color.red.opacity(0.1))
                                )
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appSurface)
                        )
                        
                        // Service Account Help
                        if selectedAuthMethod == .serviceAccount {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Service Account Setup", systemImage: "questionmark.circle")
                                    .font(.headline)
                                    .foregroundColor(.appText)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    helpStep("1", "Go to Google Cloud Console → APIs & Services")
                                    helpStep("2", "Enable Google Sheets API for your project")
                                    helpStep("3", "Create Credentials → Service Account")
                                    helpStep("4", "Create a Key (JSON) for the service account")
                                    helpStep("5", "Open your Google Sheet and share it with the service account email (Editor access)")
                                    helpStep("6", "Copy client_email and private_key from the JSON file")
                                }
                                .font(.caption)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appSurface)
                            )
                        }
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("About", systemImage: "info.circle")
                                .font(.headline)
                                .foregroundColor(.appText)
                            
                            Text("Dailies Timer helps you track time for your daily activities. Connect to Google Sheets to sync your timer data across devices.")
                                .font(.subheadline)
                                .foregroundColor(.appTextSecondary)
                            
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appSurface)
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .onAppear {
            loadConfiguration()
        }
        .alert("Settings", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canTest: Bool {
        switch selectedAuthMethod {
        case .apiKey:
            return !apiKey.isEmpty && !spreadsheetId.isEmpty
        case .serviceAccount:
            return !serviceAccountEmail.isEmpty && !privateKey.isEmpty && !spreadsheetId.isEmpty
        }
    }
    
    private func helpStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.appPrimary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.appPrimary.opacity(0.2)))
            
            Text(text)
                .foregroundColor(.appTextSecondary)
        }
    }
    
    private func loadConfiguration() {
        selectedAuthMethod = sheetsService.authMethod
        apiKey = sheetsService.currentAPIKey ?? ""
        serviceAccountEmail = sheetsService.currentServiceAccountEmail ?? ""
        privateKey = sheetsService.currentPrivateKey ?? ""
        spreadsheetId = sheetsService.currentSpreadsheetId ?? ""
        sheetName = sheetsService.currentSheetName
    }
    
    private func saveConfiguration() {
        switch selectedAuthMethod {
        case .apiKey:
            guard !apiKey.isEmpty, !spreadsheetId.isEmpty else {
                alertMessage = "Please fill in API Key and Spreadsheet ID"
                showingAlert = true
                return
            }
            sheetsService.configureWithAPIKey(
                apiKey: apiKey,
                spreadsheetId: spreadsheetId,
                sheetName: sheetName.isEmpty ? "Timers" : sheetName
            )
            
        case .serviceAccount:
            guard !serviceAccountEmail.isEmpty, !privateKey.isEmpty, !spreadsheetId.isEmpty else {
                alertMessage = "Please fill in Service Account Email, Private Key, and Spreadsheet ID"
                showingAlert = true
                return
            }
            sheetsService.configureWithServiceAccount(
                email: serviceAccountEmail,
                privateKey: privateKey,
                spreadsheetId: spreadsheetId,
                sheetName: sheetName.isEmpty ? "Timers" : sheetName
            )
        }
        
        alertMessage = "Configuration saved successfully"
        showingAlert = true
        HapticManager.shared.notification(.success)
    }
    
    private func testConnection() {
        // Save first to ensure latest values are used
        saveConfigurationSilently()
        
        Task {
            await sheetsService.testConnection()
            if sheetsService.testResult?.success == true {
                HapticManager.shared.notification(.success)
            } else {
                HapticManager.shared.notification(.error)
            }
        }
    }
    
    private func saveConfigurationSilently() {
        switch selectedAuthMethod {
        case .apiKey:
            if !apiKey.isEmpty && !spreadsheetId.isEmpty {
                sheetsService.configureWithAPIKey(
                    apiKey: apiKey,
                    spreadsheetId: spreadsheetId,
                    sheetName: sheetName.isEmpty ? "Timers" : sheetName
                )
            }
        case .serviceAccount:
            if !serviceAccountEmail.isEmpty && !privateKey.isEmpty && !spreadsheetId.isEmpty {
                sheetsService.configureWithServiceAccount(
                    email: serviceAccountEmail,
                    privateKey: privateKey,
                    spreadsheetId: spreadsheetId,
                    sheetName: sheetName.isEmpty ? "Timers" : sheetName
                )
            }
        }
    }
    
    private func clearFields() {
        apiKey = ""
        serviceAccountEmail = ""
        privateKey = ""
        spreadsheetId = ""
        sheetName = "Timers"
    }
}

// MARK: - Custom TextField

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.appTextSecondary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.appBackground)
            .foregroundColor(.appText)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appSecondary, lineWidth: 1)
            )
    }
}

#Preview {
    ContentView()
        .environmentObject(TimerManager())
        .environmentObject(GoogleSheetsService())
}
