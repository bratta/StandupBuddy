import Foundation

enum FunFactService {
    private static let endpointURL = URL(string: "https://uselessfacts.jsph.pl/api/v2/facts/random?language=en")!

    struct Response: Decodable {
        let text: String
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
                    level: .error, source: "Fun Fact", method: "GET",
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
                    level: .success, source: "Fun Fact", method: "GET",
                    url: endpointURL.absoluteString, statusCode: statusCode,
                    message: "Fetched fact"
                )
            }
            return response.text
        } catch {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "Fun Fact", method: "GET",
                    url: endpointURL.absoluteString, statusCode: statusCode,
                    message: "Could not parse response: \(error.localizedDescription)"
                )
            }
            throw error
        }
    }
}
