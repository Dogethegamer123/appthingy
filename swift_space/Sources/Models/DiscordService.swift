import Foundation
import os

actor DiscordService {
    private let logger = Logger(subsystem: "com.afkremote", category: "Discord")
    private let baseURL = "https://discord.com/api/v10"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }
    
    enum DiscordError: LocalizedError {
        case invalidToken
        case noPermission
        case channelNotFound
        case rateLimited(Double)
        case noConnection
        case httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidToken: return "Invalid bot token"
            case .noPermission: return "Bot lacks permission for this channel"
            case .channelNotFound: return "Channel not found — check the ID"
            case .rateLimited(let s): return "Rate limited — retrying in \(Int(s))s"
            case .noConnection: return "No connection"
            case .httpError(let c): return "Discord error (\(c))"
            }
        }
    }
    
    private func makeRequest(path: String, method: String = "GET", body: Data? = nil, token: String) -> URLRequest {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = method
        req.setValue("Bot \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("DiscordBot (https://afkremote.app, 1.0)", forHTTPHeaderField: "User-Agent")
        req.httpBody = body
        return req
    }
    
    private func perform(_ request: URLRequest, retries: Int = 2) async throws -> (Data, Int) {
        do {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if code == 429 && retries > 0 {
                var wait: Double = 1.0
                if let rl = try? JSONDecoder().decode(DiscordRateLimit.self, from: data) {
                    wait = rl.retryAfter
                }
                logger.warning("Rate limited, waiting \(wait)s")
                try await Task.sleep(for: .seconds(wait))
                return try await perform(request, retries: retries - 1)
            }
            
            return (data, code)
        } catch is URLError {
            throw DiscordError.noConnection
        }
    }
    
    private func mapError(_ code: Int) -> DiscordError {
        switch code {
        case 401: return .invalidToken
        case 403: return .noPermission
        case 404: return .channelNotFound
        default: return .httpError(code)
        }
    }
    
    func getChannel(id: String, token: String) async throws -> DiscordChannel {
        let req = makeRequest(path: "/channels/\(id)", token: token)
        let (data, code) = try await perform(req)
        guard (200..<300).contains(code) else { throw mapError(code) }
        return try JSONDecoder().decode(DiscordChannel.self, from: data)
    }
    
    func fetchMessages(channelId: String, token: String, limit: Int = 50) async throws -> [DiscordMessage] {
        let req = makeRequest(path: "/channels/\(channelId)/messages?limit=\(limit)", token: token)
        let (data, code) = try await perform(req)
        guard (200..<300).contains(code) else { throw mapError(code) }
        return try JSONDecoder().decode([DiscordMessage].self, from: data)
    }
    
    func sendCommand(channelId: String, command: String, token: String) async throws {
        let body = try JSONEncoder().encode(["content": "[App] !\(command)"])
        let req = makeRequest(path: "/channels/\(channelId)/messages", method: "POST", body: body, token: token)
        let (_, code) = try await perform(req)
        guard (200..<300).contains(code) else { throw mapError(code) }
    }
}
