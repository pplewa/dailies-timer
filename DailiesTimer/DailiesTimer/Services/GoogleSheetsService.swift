import Foundation
import Security

/// Authentication method for Google Sheets
enum GoogleAuthMethod: String, Codable, CaseIterable {
    case apiKey = "API Key (Read Only)"
    case serviceAccount = "Service Account"
}

/// Service for syncing timer data with Google Sheets
class GoogleSheetsService: ObservableObject {
    static let shared = GoogleSheetsService()
    
    @Published var isConfigured: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var authMethod: GoogleAuthMethod = .serviceAccount
    @Published var testResult: TestResult?
    @Published var autoSyncEnabled: Bool = true
    
    // API Key auth
    private var apiKey: String?
    
    // Service Account auth
    private var serviceAccountEmail: String?
    private var privateKey: String?
    
    // Common
    private var spreadsheetId: String?
    private var sheetName: String = "Timers"
    
    private let baseURL = "https://sheets.googleapis.com/v4/spreadsheets"
    private let tokenURL = "https://oauth2.googleapis.com/token"
    
    // Cached access token for service account
    private var accessToken: String?
    private var tokenExpiration: Date?
    
    // Debounce sync
    private var syncTask: Task<Void, Never>?
    private let syncDebounceInterval: TimeInterval = 2.0
    
    struct TestResult: Equatable {
        let success: Bool
        let message: String
        let timestamp: Date
    }
    
    init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration
    
    func configureWithAPIKey(apiKey: String, spreadsheetId: String, sheetName: String = "Timers") {
        self.authMethod = .apiKey
        self.apiKey = apiKey
        self.spreadsheetId = spreadsheetId
        self.sheetName = sheetName
        self.isConfigured = true
        
        // Clear service account fields
        self.serviceAccountEmail = nil
        self.privateKey = nil
        self.accessToken = nil
        self.tokenExpiration = nil
        
        saveConfiguration()
    }
    
    func configureWithServiceAccount(email: String, privateKey: String, spreadsheetId: String, sheetName: String = "Timers") {
        self.authMethod = .serviceAccount
        self.serviceAccountEmail = email
        // Convert \n literals to actual newlines (from JSON copy-paste)
        self.privateKey = privateKey
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
        self.spreadsheetId = spreadsheetId
        self.sheetName = sheetName
        self.isConfigured = true
        
        // Clear API key
        self.apiKey = nil
        self.accessToken = nil
        self.tokenExpiration = nil
        
        saveConfiguration()
    }
    
    func clearConfiguration() {
        apiKey = nil
        serviceAccountEmail = nil
        privateKey = nil
        spreadsheetId = nil
        accessToken = nil
        tokenExpiration = nil
        isConfigured = false
        testResult = nil
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "googleSheetsAuthMethod")
        defaults.removeObject(forKey: "googleSheetsApiKey")
        defaults.removeObject(forKey: "googleSheetsServiceAccountEmail")
        defaults.removeObject(forKey: "googleSheetsPrivateKey")
        defaults.removeObject(forKey: "googleSheetsSpreadsheetId")
        defaults.removeObject(forKey: "googleSheetsSheetName")
    }
    
    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(authMethod.rawValue, forKey: "googleSheetsAuthMethod")
        defaults.set(apiKey, forKey: "googleSheetsApiKey")
        defaults.set(serviceAccountEmail, forKey: "googleSheetsServiceAccountEmail")
        defaults.set(privateKey, forKey: "googleSheetsPrivateKey")
        defaults.set(spreadsheetId, forKey: "googleSheetsSpreadsheetId")
        defaults.set(sheetName, forKey: "googleSheetsSheetName")
        defaults.set(autoSyncEnabled, forKey: "googleSheetsAutoSync")
    }
    
    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        
        if let methodString = defaults.string(forKey: "googleSheetsAuthMethod"),
           let method = GoogleAuthMethod(rawValue: methodString) {
            authMethod = method
        } else if defaults.string(forKey: "googleSheetsAuthMethod") == "API Key" {
            // Handle old config migration
            authMethod = .apiKey
        }
        
        apiKey = defaults.string(forKey: "googleSheetsApiKey")
        serviceAccountEmail = defaults.string(forKey: "googleSheetsServiceAccountEmail")
        privateKey = defaults.string(forKey: "googleSheetsPrivateKey")
        spreadsheetId = defaults.string(forKey: "googleSheetsSpreadsheetId")
        sheetName = defaults.string(forKey: "googleSheetsSheetName") ?? "Timers"
        autoSyncEnabled = defaults.object(forKey: "googleSheetsAutoSync") as? Bool ?? true
        
        switch authMethod {
        case .apiKey:
            isConfigured = apiKey != nil && spreadsheetId != nil
        case .serviceAccount:
            isConfigured = serviceAccountEmail != nil && privateKey != nil && spreadsheetId != nil
        }
    }
    
    // MARK: - Service Account JWT Token
    
    private func getAccessToken() async throws -> String {
        // Return cached token if still valid
        if let token = accessToken, let expiration = tokenExpiration, Date() < expiration {
            return token
        }
        
        guard let email = serviceAccountEmail, let key = privateKey else {
            throw GoogleSheetsError.notConfigured
        }
        
        // Create JWT
        let jwt = try createJWT(email: email, privateKey: key)
        
        // Exchange JWT for access token
        let token = try await exchangeJWTForToken(jwt: jwt)
        
        // Cache the token (expires in 1 hour, refresh at 50 minutes)
        self.accessToken = token
        self.tokenExpiration = Date().addingTimeInterval(50 * 60)
        
        return token
    }
    
    private func createJWT(email: String, privateKey: String) throws -> String {
        let now = Date()
        let expiration = now.addingTimeInterval(3600) // 1 hour
        
        // JWT Header
        let header: [String: Any] = [
            "alg": "RS256",
            "typ": "JWT"
        ]
        
        // JWT Claims
        let claims: [String: Any] = [
            "iss": email,
            "scope": "https://www.googleapis.com/auth/spreadsheets",
            "aud": tokenURL,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(expiration.timeIntervalSince1970)
        ]
        
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let claimsData = try JSONSerialization.data(withJSONObject: claims)
        
        let headerBase64 = headerData.base64URLEncodedString()
        let claimsBase64 = claimsData.base64URLEncodedString()
        
        let signatureInput = "\(headerBase64).\(claimsBase64)"
        
        // Sign with RSA-SHA256
        let signature = try signWithRSA(data: signatureInput.data(using: .utf8)!, privateKey: privateKey)
        let signatureBase64 = signature.base64URLEncodedString()
        
        return "\(signatureInput).\(signatureBase64)"
    }
    
    private func signWithRSA(data: Data, privateKey pemString: String) throws -> Data {
        // Extract the base64 key data from PEM format
        var keyString = pemString
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let keyData = Data(base64Encoded: keyString) else {
            print("GoogleSheetsService: Failed to decode base64 key. Key length: \(keyString.count)")
            throw GoogleSheetsError.invalidPrivateKey
        }
        
        // For PKCS#8 format (Google's format), we need to extract the RSA key
        let rsaKeyData = try extractRSAKeyFromPKCS8(keyData)
        
        // Create SecKey from the RSA key data
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
        ]
        
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(rsaKeyData as CFData, attributes as CFDictionary, &error) else {
            if let err = error?.takeRetainedValue() {
                print("GoogleSheetsService: SecKey creation error: \(err)")
            }
            throw GoogleSheetsError.invalidPrivateKey
        }
        
        // Sign the data
        guard let signedData = SecKeyCreateSignature(
            secKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) else {
            if let err = error?.takeRetainedValue() {
                print("GoogleSheetsService: Signing error: \(err)")
            }
            throw GoogleSheetsError.signingFailed
        }
        
        return signedData as Data
    }
    
    /// Extract RSA private key from PKCS#8 format
    private func extractRSAKeyFromPKCS8(_ pkcs8Data: Data) throws -> Data {
        let bytes = [UInt8](pkcs8Data)
        
        for i in 0..<(bytes.count - 4) {
            if bytes[i] == 0x04 { // OCTET STRING tag
                var keyStart = i + 2
                var keyLength = 0
                
                if bytes[i + 1] == 0x82 {
                    keyLength = Int(bytes[i + 2]) << 8 + Int(bytes[i + 3])
                    keyStart = i + 4
                } else if bytes[i + 1] == 0x81 {
                    keyLength = Int(bytes[i + 2])
                    keyStart = i + 3
                } else if bytes[i + 1] < 0x80 {
                    keyLength = Int(bytes[i + 1])
                    keyStart = i + 2
                } else {
                    continue
                }
                
                if keyStart < bytes.count && bytes[keyStart] == 0x30 {
                    let endIndex = min(keyStart + keyLength, bytes.count)
                    return Data(bytes[keyStart..<endIndex])
                }
            }
        }
        
        return pkcs8Data
    }
    
    private func exchangeJWTForToken(jwt: String) async throws -> String {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleSheetsError.tokenExchangeFailed
        }
        
        if httpResponse.statusCode != 200 {
            let responseStr = String(data: data, encoding: .utf8) ?? "unknown"
            print("GoogleSheetsService: Token exchange failed (\(httpResponse.statusCode)): \(responseStr)")
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDesc = errorJson["error_description"] as? String {
                throw GoogleSheetsError.authError(errorDesc)
            }
            throw GoogleSheetsError.tokenExchangeFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw GoogleSheetsError.tokenExchangeFailed
        }
        
        return token
    }
    
    // MARK: - Test Connection
    
    func testConnection() async {
        await MainActor.run {
            isSyncing = true
            testResult = nil
            syncError = nil
        }
        
        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }
        
        do {
            guard let spreadsheetId = spreadsheetId else {
                throw GoogleSheetsError.notConfigured
            }
            
            var urlString = "\(baseURL)/\(spreadsheetId)?fields=properties.title"
            
            var request: URLRequest
            
            switch authMethod {
            case .apiKey:
                guard let apiKey = apiKey else {
                    throw GoogleSheetsError.notConfigured
                }
                urlString += "&key=\(apiKey)"
                request = URLRequest(url: URL(string: urlString)!)
                
            case .serviceAccount:
                let token = try await getAccessToken()
                request = URLRequest(url: URL(string: urlString)!)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GoogleSheetsError.connectionFailed
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let properties = json["properties"] as? [String: Any],
                   let title = properties["title"] as? String {
                    await MainActor.run {
                        testResult = TestResult(
                            success: true,
                            message: "Connected to: \"\(title)\"",
                            timestamp: Date()
                        )
                    }
                } else {
                    await MainActor.run {
                        testResult = TestResult(
                            success: true,
                            message: "Connection successful!",
                            timestamp: Date()
                        )
                    }
                }
            } else {
                let errorMessage = parseErrorResponse(data: data, statusCode: httpResponse.statusCode)
                throw GoogleSheetsError.httpError(httpResponse.statusCode, errorMessage)
            }
        } catch {
            await MainActor.run {
                let message = (error as? GoogleSheetsError)?.errorDescription ?? error.localizedDescription
                testResult = TestResult(
                    success: false,
                    message: message,
                    timestamp: Date()
                )
                syncError = message
            }
        }
    }
    
    private func parseErrorResponse(data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return "HTTP Error \(statusCode)"
    }
    
    // MARK: - Auto Sync (Debounced)
    
    /// Trigger an auto-sync with debouncing to avoid too many API calls
    func triggerAutoSync(timers: [TimerItem], completion: (([TimerItem]) -> Void)? = nil) {
        guard isConfigured && autoSyncEnabled && canWrite else { return }
        
        // Cancel previous pending sync
        syncTask?.cancel()
        
        syncTask = Task {
            // Wait for debounce interval
            try? await Task.sleep(nanoseconds: UInt64(syncDebounceInterval * 1_000_000_000))
            
            // Check if cancelled
            if Task.isCancelled { return }
            
            do {
                let updatedTimers = try await twoWaySync(localTimers: timers)
                await MainActor.run {
                    completion?(updatedTimers)
                }
            } catch {
                print("GoogleSheetsService: Auto-sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Two-Way Sync
    
    /// Performs two-way sync: pushes local changes and pulls remote changes
    /// Returns updated timers if remote had higher values
    func twoWaySync(localTimers: [TimerItem]) async throws -> [TimerItem] {
        guard isConfigured, let spreadsheetId = spreadsheetId else {
            throw GoogleSheetsError.notConfigured
        }
        
        guard authMethod == .serviceAccount else {
            throw GoogleSheetsError.apiKeyWriteNotSupported
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }
        
        // Step 1: Fetch remote timers
        let remoteTimers = try await fetchTimersInternal()
        
        // Step 2: Merge - take higher elapsed time values, but respect explicit resets
        var mergedTimers = localTimers
        var hasRemoteUpdates = false
        let recentResetThreshold: TimeInterval = 10.0 // Ignore remote if reset within 10 seconds
        
        for remoteTimer in remoteTimers {
            if let localIndex = mergedTimers.firstIndex(where: { $0.id == remoteTimer.id }) {
                // Timer exists locally - check if remote has higher elapsed time
                let localElapsed = mergedTimers[localIndex].currentElapsedTime
                let remoteElapsed = remoteTimer.elapsedTime
                
                // Check if timer was recently reset - if so, local value takes precedence
                let wasRecentlyReset: Bool
                if let resetTime = mergedTimers[localIndex].lastResetTime {
                    wasRecentlyReset = Date().timeIntervalSince(resetTime) < recentResetThreshold
                } else {
                    wasRecentlyReset = false
                }
                
                if wasRecentlyReset {
                    // Timer was recently reset - do not accept remote's higher value
                    print("GoogleSheetsService: Timer '\(remoteTimer.name)' was recently reset, keeping local value: \(localElapsed)s")
                } else if remoteElapsed > localElapsed && !mergedTimers[localIndex].isRunning {
                    // Remote has higher value and timer is not currently running
                    print("GoogleSheetsService: Updating '\(remoteTimer.name)' from remote: \(localElapsed)s -> \(remoteElapsed)s")
                    mergedTimers[localIndex].elapsedTime = remoteElapsed
                    hasRemoteUpdates = true
                }
            } else {
                // Timer exists only on remote - add it locally
                print("GoogleSheetsService: Adding timer '\(remoteTimer.name)' from remote")
                mergedTimers.append(remoteTimer)
                hasRemoteUpdates = true
            }
        }
        
        // Step 3: Push merged data back to sheet
        try await syncTimersInternal(mergedTimers)
        
        await MainActor.run {
            lastSyncTime = Date()
            if hasRemoteUpdates {
                print("GoogleSheetsService: Two-way sync complete with remote updates")
            } else {
                print("GoogleSheetsService: Two-way sync complete (no remote updates)")
            }
        }
        
        return mergedTimers
    }
    
    // MARK: - Sync Operations (Internal)
    
    private func syncTimersInternal(_ timers: [TimerItem]) async throws {
        guard let spreadsheetId = spreadsheetId else {
            throw GoogleSheetsError.notConfigured
        }
        
        // Prepare data rows
        var values: [[String]] = [
            ["ID", "Name", "Reference Duration (s)", "Elapsed Time (s)", "Is Running", "Last Updated"]
        ]
        
        let dateFormatter = ISO8601DateFormatter()
        
        for timer in timers {
            let currentElapsed = timer.currentElapsedTime
            values.append([
                timer.id.uuidString,
                timer.name,
                String(format: "%.0f", timer.referenceDuration),
                String(format: "%.0f", currentElapsed),
                timer.isRunning ? "TRUE" : "FALSE",
                dateFormatter.string(from: Date())
            ])
        }
        
        let encodedSheetName = sheetName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sheetName
        let range = "\(encodedSheetName)!A1:F\(values.count)"
        let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? range
        
        let urlString = "\(baseURL)/\(spreadsheetId)/values/\(encodedRange)?valueInputOption=USER_ENTERED"
        
        let token = try await getAccessToken()
        guard let url = URL(string: urlString) else {
            throw GoogleSheetsError.invalidData
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "range": "\(sheetName)!A1:F\(values.count)",
            "majorDimension": "ROWS",
            "values": values
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleSheetsError.syncFailed
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = parseErrorResponse(data: data, statusCode: httpResponse.statusCode)
            throw GoogleSheetsError.httpError(httpResponse.statusCode, errorMessage)
        }
    }
    
    private func fetchTimersInternal() async throws -> [TimerItem] {
        guard let spreadsheetId = spreadsheetId else {
            throw GoogleSheetsError.notConfigured
        }
        
        let encodedSheetName = sheetName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sheetName
        let range = "\(encodedSheetName)!A2:F100"
        let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? range
        
        var urlString = "\(baseURL)/\(spreadsheetId)/values/\(encodedRange)"
        
        var request: URLRequest
        
        switch authMethod {
        case .apiKey:
            guard let apiKey = apiKey else {
                throw GoogleSheetsError.notConfigured
            }
            urlString += "?key=\(apiKey)"
            guard let url = URL(string: urlString) else {
                throw GoogleSheetsError.invalidData
            }
            request = URLRequest(url: url)
            
        case .serviceAccount:
            let token = try await getAccessToken()
            guard let url = URL(string: urlString) else {
                throw GoogleSheetsError.invalidData
            }
            request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleSheetsError.fetchFailed
        }
        
        // Handle empty sheet (404 or no values)
        if httpResponse.statusCode == 404 {
            return []
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GoogleSheetsError.fetchFailed
        }
        
        guard let result = try? JSONDecoder().decode(SheetsResponse.self, from: data) else {
            return []
        }
        
        var timers: [TimerItem] = []
        
        for row in result.values ?? [] {
            guard row.count >= 5,
                  let id = UUID(uuidString: row[0]),
                  let referenceDuration = Double(row[2]),
                  let elapsedTime = Double(row[3]) else {
                continue
            }
            
            let timer = TimerItem(
                id: id,
                name: row[1],
                referenceDuration: referenceDuration,
                elapsedTime: elapsedTime,
                isRunning: false
            )
            timers.append(timer)
        }
        
        return timers
    }
    
    // MARK: - Public Sync Operations
    
    func syncTimers(_ timers: [TimerItem]) async throws {
        guard isConfigured, let spreadsheetId = spreadsheetId else {
            throw GoogleSheetsError.notConfigured
        }
        
        if authMethod == .apiKey {
            throw GoogleSheetsError.apiKeyWriteNotSupported
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }
        
        try await syncTimersInternal(timers)
        
        await MainActor.run {
            lastSyncTime = Date()
        }
    }
    
    func fetchTimers() async throws -> [TimerItem] {
        guard isConfigured else {
            throw GoogleSheetsError.notConfigured
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }
        
        let timers = try await fetchTimersInternal()
        
        await MainActor.run {
            lastSyncTime = Date()
        }
        
        return timers
    }
    
    // MARK: - Getters for UI
    
    var currentAPIKey: String? { apiKey }
    var currentServiceAccountEmail: String? { serviceAccountEmail }
    var currentPrivateKey: String? { privateKey }
    var currentSpreadsheetId: String? { spreadsheetId }
    var currentSheetName: String { sheetName }
    
    /// Check if current auth method supports write operations
    var canWrite: Bool {
        authMethod == .serviceAccount
    }
    
    func setAutoSync(_ enabled: Bool) {
        autoSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "googleSheetsAutoSync")
    }
}

// MARK: - Supporting Types

enum GoogleSheetsError: LocalizedError {
    case notConfigured
    case syncFailed
    case fetchFailed
    case invalidData
    case invalidPrivateKey
    case signingFailed
    case tokenExchangeFailed
    case connectionFailed
    case authError(String)
    case httpError(Int, String)
    case apiKeyWriteNotSupported
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sheets is not configured"
        case .syncFailed:
            return "Failed to sync data to Google Sheets"
        case .fetchFailed:
            return "Failed to fetch data from Google Sheets"
        case .invalidData:
            return "Invalid data format"
        case .invalidPrivateKey:
            return "Invalid private key format. Copy the entire private_key value from your JSON file (including the -----BEGIN/END----- markers)"
        case .signingFailed:
            return "Failed to sign authentication request"
        case .tokenExchangeFailed:
            return "Failed to get access token. Check your service account email and private key"
        case .connectionFailed:
            return "Connection failed"
        case .authError(let message):
            return "Auth error: \(message)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .apiKeyWriteNotSupported:
            return "API Keys only support reading data. Use a Service Account to write/sync data"
        }
    }
}

struct SheetsResponse: Codable {
    let range: String?
    let majorDimension: String?
    let values: [[String]]?
}

// MARK: - Base64 URL Encoding

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
