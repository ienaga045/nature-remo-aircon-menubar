import Foundation

enum NatureRemoError: LocalizedError {
    case missingToken
    case invalidResponse
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Nature Remo APIトークンが未設定です。"
        case .invalidResponse:
            "Nature Remo APIの応答を読み取れませんでした。"
        case .apiError(let status, let message):
            "Nature Remo APIエラー (\(status)): \(message)"
        }
    }
}

final class NatureRemoClient: @unchecked Sendable {
    private let baseURL = URL(string: "https://api.nature.global")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func appliances(token: String) async throws -> [Appliance] {
        var request = URLRequest(url: baseURL.appending(path: "/1/appliances"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder().decode([Appliance].self, from: data)
    }

    func devices(token: String) async throws -> [RemoDevice] {
        var request = URLRequest(url: baseURL.appending(path: "/1/devices"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder().decode([RemoDevice].self, from: data)
    }

    func updateAircon(
        applianceID: String,
        token: String,
        powerOff: Bool = false,
        mode: OperationMode? = nil,
        temperature: String? = nil
    ) async throws {
        var components = URLComponents()
        var items: [URLQueryItem] = []

        if powerOff {
            items.append(URLQueryItem(name: "button", value: "power-off"))
        } else {
            items.append(URLQueryItem(name: "button", value: ""))
        }

        if let mode {
            items.append(URLQueryItem(name: "operation_mode", value: mode.rawValue))
        }

        if let temperature {
            items.append(URLQueryItem(name: "temperature", value: temperature))
        }

        components.queryItems = items

        var request = URLRequest(url: baseURL.appending(path: "/1/appliances/\(applianceID)/aircon_settings"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validate(data: data, response: response)
    }

    private func validate(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NatureRemoError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NatureRemoError.apiError(httpResponse.statusCode, message)
        }
    }
}
