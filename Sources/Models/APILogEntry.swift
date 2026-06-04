import Foundation

enum APILogLevel: Sendable {
    case success
    case warning
    case error
}

struct APILogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: APILogLevel
    let source: String
    let method: String
    let url: String
    let statusCode: Int?
    let message: String

    init(level: APILogLevel, source: String, method: String, url: String, statusCode: Int? = nil, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.source = source
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.message = message
    }
}
