import Foundation

@Observable
@MainActor
final class APILogger {
    static let shared = APILogger()

    private(set) var entries: [APILogEntry] = []

    private init() {}

    func log(
        level: APILogLevel,
        source: String,
        method: String,
        url: String,
        statusCode: Int? = nil,
        message: String
    ) {
        entries.insert(
            APILogEntry(level: level, source: source, method: method, url: url, statusCode: statusCode, message: message),
            at: 0
        )
    }

    func clear() {
        entries.removeAll()
    }
}
