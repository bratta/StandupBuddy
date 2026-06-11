import Foundation

enum DadJokeService {
    private static let endpointURL = URL(string: "https://icanhazdadjoke.com/")!

    struct Response: Decodable {
        let joke: String
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
                    level: .error, source: "Dad Joke", method: "GET",
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
                    level: .success, source: "Dad Joke", method: "GET",
                    url: endpointURL.absoluteString, statusCode: statusCode,
                    message: "Fetched joke"
                )
            }
            return response.joke.flattenedForSlack()
        } catch {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "Dad Joke", method: "GET",
                    url: endpointURL.absoluteString, statusCode: statusCode,
                    message: "Could not parse response: \(error.localizedDescription)"
                )
            }
            throw error
        }
    }
}
