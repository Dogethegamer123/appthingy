import Foundation
import Observation

@Observable
final class CredentialStore {
    var botToken: String = ""
    var channelId: String = ""
    
    var isConfigured: Bool {
        !botToken.isEmpty && !channelId.isEmpty
    }
    
    var maskedToken: String {
        guard botToken.count > 4 else { return String(repeating: "•", count: 8) }
        return String(repeating: "•", count: 8) + botToken.suffix(4)
    }
    
    init() {
        reload()
    }
    
    func reload() {
        botToken = KeychainService.read(account: "botToken") ?? ""
        channelId = KeychainService.read(account: "channelId") ?? ""
    }
    
    func save(token: String, channelId: String) {
        KeychainService.save(account: "botToken", value: token)
        KeychainService.save(account: "channelId", value: channelId)
        reload()
    }
    
    func clear() {
        KeychainService.delete(account: "botToken")
        KeychainService.delete(account: "channelId")
        reload()
    }
}
