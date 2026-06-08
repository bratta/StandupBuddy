import Foundation

enum AffirmationService {
    private static let endpointURL = URL(string: "https://www.affirmations.dev/")!

    struct Response: Decodable {
        let affirmation: String
    }

    static func fetch() async throws -> String {
        var request = URLRequest(url: endpointURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("StandupBuddy/1.0 (https://github.com/bratta/standup-buddy)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let statusCode: Int?
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            data = responseData
            statusCode = (response as? HTTPURLResponse)?.statusCode
        } catch {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "Affirmation", method: "GET",
                    url: endpointURL.absoluteString,
                    message: "Network error: \(error.localizedDescription)"
                )
            }
            throw error
        }

        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            Task { @MainActor in
                APILogger.shared.log(
                    level: .success, source: "Affirmation", method: "GET",
                    url: endpointURL.absoluteString, statusCode: statusCode,
                    message: "Fetched affirmation"
                )
            }
            return response.affirmation
        } catch {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "Affirmation", method: "GET",
                    url: endpointURL.absoluteString, statusCode: statusCode,
                    message: "Could not parse response: \(error.localizedDescription)"
                )
            }
            throw error
        }
    }
}
