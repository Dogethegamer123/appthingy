import Foundation
import Observation

enum AppTab: String, CaseIterable {
    case macros
    case schedule
    case home
    case feed
    case settings
    
    var label: String {
        switch self {
        case .macros: return "Macros"
        case .schedule: return "Schedule"
        case .home: return "Home"
        case .feed: return "Feed"
        case .settings: return "Settings"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .macros: return "square.grid.2x2.fill"
        case .schedule: return "calendar.badge.clock"
        case .home: return "house.fill"
        case .feed: return "text.bubble.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
}
