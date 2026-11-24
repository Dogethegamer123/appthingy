import SwiftData
import Foundation

@Model
final class TabIconConfig {
    @Attribute(.unique) var tabKey: String
    var symbolName: String?
    @Attribute(.externalStorage) var customImageData: Data?
    
    init(tabKey: String, symbolName: String? = nil, customImageData: Data? = nil) {
        self.tabKey = tabKey
        self.symbolName = symbolName
        self.customImageData = customImageData
    }
}
