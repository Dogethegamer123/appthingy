import SwiftData
import Foundation

@Model
final class CachedFeed {
    var rawJSON: Data
    var fetchedAt: Date
    
    init(rawJSON: Data = Data(), fetchedAt: Date = .now) {
        self.rawJSON = rawJSON
        self.fetchedAt = fetchedAt
    }
}
