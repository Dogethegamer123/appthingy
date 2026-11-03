import SwiftData
import Foundation

@Model
final class AppSettings {
    var refreshInterval: Int
    var accentHex: String
    var hapticsEnabled: Bool
    var didSeed: Bool
    
    init(refreshInterval: Int = 15, accentHex: String = "FF0000", hapticsEnabled: Bool = true, didSeed: Bool = false) {
        self.refreshInterval = refreshInterval
        self.accentHex = accentHex
        self.hapticsEnabled = hapticsEnabled
        self.didSeed = didSeed
    }
}
