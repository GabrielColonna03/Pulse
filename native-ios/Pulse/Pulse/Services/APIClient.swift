import Foundation

enum APIClientError: LocalizedError {
    case missingBaseURL
    case invalidURL
    case http(Int, String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Set your Pulse API base URL in Settings before signing in."
        case .invalidURL:
            return "The API URL looks invalid."
        case .http(_, let message):
            return message
        case .decoding:
            return "Could not read the server response."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private let encoder = JSONEncoder()
    private var baseURLString: String
    private var token: String?

    init() {
        self.baseURLString = UserDefaults.standard.string(forKey: SessionKeys.apiBase)
            ?? KeychainStore.get(SessionKeys.apiBase)
            ?? ""
        self.token = KeychainStore.get(SessionKeys.token)
    }

    func configure(baseURL: String) {
        let cleaned = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        baseURLString = cleaned
        UserDefaults.standard.set(cleaned, forKey: SessionKeys.apiBase)
        KeychainStore.set(cleaned, forKey: SessionKeys.apiBase)
    }

    func setToken(_ token: String?) {
        self.token = token
        if let token, !token.isEmpty {
            KeychainStore.set(token, forKey: SessionKeys.token)
        } else {
            KeychainStore.delete(SessionKeys.token)
        }
    }

    func currentBaseURL() -> String { baseURLString }
    func currentToken() -> String? { token }

    func login(pin: String) async throws -> LoginResponse {
        let response: LoginResponse = try await request(
            path: "/api/login",
            method: "POST",
            body: ["pin": pin],
            authorized: false
        )
        setToken(response.token)
        return response
    }

    func logout() async throws {
        _ = try? await requestEmpty(path: "/api/logout", method: "POST", body: Optional<String>.none)
        setToken(nil)
    }

    func me() async throws -> UserProfile {
        try await request(path: "/api/me", method: "GET")
    }

    func categoryModel() async throws -> CategoryModel {
        try await request(path: "/api/category-model", method: "GET")
    }

    func saveCategoryModel(_ model: CategoryModel) async throws -> CategoryModel {
        try await request(path: "/api/category-model", method: "PUT", body: CategoryModelEnvelope(model: model))
    }

    func transactions() async throws -> [Transaction] {
        try await request(path: "/api/transactions", method: "GET")
    }

    func searchTransactions(query: String) async throws -> [Transaction] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request(path: "/api/transactions/search?q=\(encoded)", method: "GET")
    }

    func createTransaction(_ body: CreateTransactionBody) async throws {
        struct CreatedList: Codable { var created: [Transaction]? }
        // Server may return a single tx or { created: [...] }
        let _: Data = try await requestData(path: "/api/transactions", method: "POST", body: body)
    }

    func updateTransaction(id: String, body: UpdateTransactionBody) async throws -> Transaction {
        try await request(path: "/api/transactions/\(id)", method: "PUT", body: body)
    }

    func deleteTransaction(id: String) async throws {
        try await requestEmpty(path: "/api/transactions/\(id)", method: "DELETE")
    }

    func clearTransactions() async throws {
        try await requestEmpty(path: "/api/transactions", method: "DELETE")
    }

    func trips() async throws -> [Trip] {
        try await request(path: "/api/trips", method: "GET")
    }

    func createTrip(name: String) async throws -> Trip {
        try await request(path: "/api/trips", method: "POST", body: CreateTripBody(name: name))
    }

    func renameTrip(id: String, name: String) async throws -> Trip {
        try await request(path: "/api/trips/\(id)", method: "PUT", body: RenameTripBody(name: name))
    }

    func deleteTrip(id: String) async throws {
        try await requestEmpty(path: "/api/trips/\(id)", method: "DELETE")
    }

    func changePin(currentPin: String, newPin: String) async throws {
        try await requestEmpty(path: "/api/me/pin", method: "POST", body: ChangePinBody(currentPin: currentPin, newPin: newPin))
    }

    func users() async throws -> [ManagedUser] {
        try await request(path: "/api/users", method: "GET")
    }

    func createUser(displayName: String, pin: String) async throws -> ManagedUser {
        try await request(path: "/api/users", method: "POST", body: CreateUserBody(displayName: displayName, pin: pin))
    }

    func resetOnboarding(userId: String) async throws {
        try await requestEmpty(path: "/api/users/\(userId)/onboarding-reset", method: "POST")
    }

    func deleteUser(userId: String) async throws {
        try await requestEmpty(path: "/api/users/\(userId)", method: "DELETE")
    }

    func exportExcel() async throws -> Data {
        try await requestData(path: "/api/export-excel", method: "GET", body: Optional<String>.none)
    }

    func exportBackupCSV() async throws -> Data {
        try await requestData(path: "/api/export-backup-csv", method: "GET", body: Optional<String>.none)
    }

    func health() async throws -> Bool {
        struct Health: Codable { var status: String }
        let health: Health = try await request(path: "/api/health", method: "GET", authorized: false)
        return health.status == "ok"
    }

    // MARK: - Internals

    private func makeURL(path: String) throws -> URL {
        guard !baseURLString.isEmpty else { throw APIClientError.missingBaseURL }
        let absolute = path.hasPrefix("http") ? path : "\(baseURLString)\(path.hasPrefix("/") ? path : "/\(path)")"
        guard let url = URL(string: absolute) else { throw APIClientError.invalidURL }
        return url
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body? = Optional<String>.none,
        authorized: Bool = true
    ) async throws -> T {
        let data = try await requestData(path: path, method: method, body: body, authorized: authorized)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    private func requestEmpty<Body: Encodable>(
        path: String,
        method: String,
        body: Body? = Optional<String>.none,
        authorized: Bool = true
    ) async throws {
        _ = try await requestData(path: path, method: method, body: body, authorized: authorized)
    }

    private func requestData<Body: Encodable>(
        path: String,
        method: String,
        body: Body? = Optional<String>.none,
        authorized: Bool = true
    ) async throws -> Data {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIClientError.http(-1, "Unexpected response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? decoder.decode(APIErrorBody.self, from: data))?.error
                    ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                throw APIClientError.http(http.statusCode, message)
            }
            return data
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.transport(error)
        }
    }
}
