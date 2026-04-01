import Foundation

actor NokoClient {
    let baseURL = URL(string: "https://api.nokotime.com/v2")!
    let token: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Throttle: minimum interval between requests (500ms for 2 req/s limit)
    private var lastRequestTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.5

    init(token: String) {
        self.token = token
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "X-NokoToken": token,
            "User-Agent": "Tempo/1.0",
            "Content-Type": "application/json",
        ]
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Entries

    func entries(from: Date? = nil, to: Date? = nil, projectIds: [Int]? = nil, userId: Int? = nil, page: Int = 1, perPage: Int = 100) async throws -> (entries: [NokoEntry], hasMore: Bool) {
        var params: [(String, String)] = [
            ("page", "\(page)"),
            ("per_page", "\(perPage)"),
        ]
        if let from { params.append(("from", TimeFormatter.apiDateString(from))) }
        if let to { params.append(("to", TimeFormatter.apiDateString(to))) }
        if let ids = projectIds, !ids.isEmpty {
            params.append(("project_ids", ids.map(String.init).joined(separator: ",")))
        }
        if let userId { params.append(("user_ids", "\(userId)")) }

        let (data, response) = try await get("/entries", params: params)
        let entries = try decoder.decode([NokoEntry].self, from: data)
        let hasMore = linkHeaderHasNext(response)
        return (entries, hasMore)
    }

    func allEntries(from: Date? = nil, to: Date? = nil, projectIds: [Int]? = nil, userId: Int? = nil) async throws -> [NokoEntry] {
        var all: [NokoEntry] = []
        var page = 1
        while true {
            let result = try await entries(from: from, to: to, projectIds: projectIds, userId: userId, page: page)
            all.append(contentsOf: result.entries)
            if !result.hasMore { break }
            page += 1
        }
        return all
    }

    func createEntry(date: Date, minutes: Int, projectId: Int?, description: String?) async throws -> NokoEntry {
        let payload = CreateEntryPayload(
            date: TimeFormatter.apiDateString(date),
            minutes: minutes,
            projectId: projectId,
            description: description
        )
        let body = try encoder.encode(payload)
        let (data, _) = try await post("/entries", body: body)
        return try decoder.decode(NokoEntry.self, from: data)
    }

    func updateEntry(id: Int, date: String? = nil, minutes: Int? = nil, projectId: Int? = nil, description: String? = nil) async throws -> NokoEntry {
        let payload = UpdateEntryPayload(date: date, minutes: minutes, projectId: projectId, description: description)
        let body = try encoder.encode(payload)
        let (data, _) = try await put("/entries/\(id)", body: body)
        return try decoder.decode(NokoEntry.self, from: data)
    }

    func deleteEntry(id: Int) async throws {
        let _ = try await delete("/entries/\(id)")
    }

    // MARK: - Projects

    func projects() async throws -> [NokoProject] {
        var all: [NokoProject] = []
        var page = 1
        while true {
            let params: [(String, String)] = [
                ("page", "\(page)"),
                ("per_page", "1000"),
            ]
            let (data, response) = try await get("/projects", params: params)
            let batch = try decoder.decode([NokoProject].self, from: data)
            all.append(contentsOf: batch)
            if !linkHeaderHasNext(response) { break }
            page += 1
        }
        return all.filter { $0.enabled }
    }

    // MARK: - User

    func currentUser() async throws -> NokoUser {
        let (data, _) = try await get("/current_user")
        return try decoder.decode(NokoUser.self, from: data)
    }

    // MARK: - Tags

    func tags() async throws -> [NokoTag] {
        let (data, _) = try await get("/tags", params: [("per_page", "1000")])
        return try decoder.decode([NokoTag].self, from: data)
    }

    // MARK: - HTTP

    private func throttle() async {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try? await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        lastRequestTime = Date()
    }

    private func get(_ path: String, params: [(String, String)] = []) async throws -> (Data, HTTPURLResponse) {
        await throttle()
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return try await perform(request)
    }

    private func post(_ path: String, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        await throttle()
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.httpBody = body
        return try await perform(request)
    }

    private func put(_ path: String, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        await throttle()
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "PUT"
        request.httpBody = body
        return try await perform(request)
    }

    private func delete(_ path: String) async throws -> (Data, HTTPURLResponse) {
        await throttle()
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "DELETE"
        return try await perform(request)
    }

    private func perform(_ request: URLRequest, retries: Int = 3) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NokoError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return (data, http)
        case 429:
            if retries > 0 {
                let delay = UInt64(pow(2.0, Double(3 - retries))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
                return try await perform(request, retries: retries - 1)
            }
            throw NokoError.rateLimited
        case 401:
            throw NokoError.unauthorized
        case 404:
            throw NokoError.notFound
        case 422:
            let message = String(data: data, encoding: .utf8) ?? "Validation error"
            throw NokoError.validationError(message)
        default:
            throw NokoError.httpError(http.statusCode, String(data: data, encoding: .utf8))
        }
    }

    private func linkHeaderHasNext(_ response: HTTPURLResponse) -> Bool {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return false }
        return link.contains("rel=\"next\"")
    }
}

// MARK: - Errors

enum NokoError: LocalizedError {
    case invalidResponse
    case rateLimited
    case unauthorized
    case notFound
    case validationError(String)
    case httpError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .rateLimited: return "Rate limited — please wait a moment"
        case .unauthorized: return "Invalid API token"
        case .notFound: return "Resource not found"
        case .validationError(let msg): return "Validation error: \(msg)"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "Unknown error")"
        }
    }
}
