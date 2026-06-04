import Foundation

enum Category: String, Codable, CaseIterable, Sendable {
    case standup
    case blocker
    case gratitude

    var displayName: String {
        switch self {
        case .standup: return "Standup"
        case .blocker: return "Blocker"
        case .gratitude: return "Gratitude"
        }
    }
}
