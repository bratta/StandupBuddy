import Foundation

/// Checks GitHub Releases for a newer version of the app. The repository is public,
/// so the latest-release endpoint is queried unauthenticated — no token required.
enum UpdateService {
    static let owner = "bratta"
    static let repo = "StandupBuddy"

    enum UpdateCheckResult: Sendable {
        case upToDate(current: String)
        case updateAvailable(current: String, latest: String, releaseURL: URL)
    }

    enum UpdateError: Error, LocalizedError {
        case unknownVersion
        case httpError(Int)
        case decodingError
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .unknownVersion: return "Could not determine the running app version."
            case .httpError(let code): return "GitHub API returned HTTP \(code)."
            case .decodingError: return "Could not parse the GitHub API response."
            case .malformedResponse: return "The latest release is missing a download page."
            }
        }
    }

    private struct ReleaseResponse: Decodable {
        let tag_name: String
        let html_url: String
    }

    static func checkForUpdate() async throws -> UpdateCheckResult {
        guard let current = currentVersion, !current.isEmpty else {
            await logError(url: latestReleaseURL.absoluteString, message: UpdateError.unknownVersion.errorDescription!)
            throw UpdateError.unknownVersion
        }

        let url = latestReleaseURL
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let statusCode: Int?
        do {
            let (responseData, response) = try await URLSession.shared.data(for: req)
            data = responseData
            statusCode = (response as? HTTPURLResponse)?.statusCode
            try validate(response: response)
        } catch let error as UpdateError {
            await logError(url: url.absoluteString, message: error.errorDescription ?? error.localizedDescription)
            throw error
        } catch {
            await logError(url: url.absoluteString, message: "Network error: \(error.localizedDescription)")
            throw error
        }

        guard let release = try? JSONDecoder().decode(ReleaseResponse.self, from: data) else {
            await logError(url: url.absoluteString, statusCode: statusCode, message: UpdateError.decodingError.errorDescription!)
            throw UpdateError.decodingError
        }

        guard let releaseURL = URL(string: release.html_url) else {
            await logError(url: url.absoluteString, statusCode: statusCode, message: UpdateError.malformedResponse.errorDescription!)
            throw UpdateError.malformedResponse
        }

        let latest = normalizedVersion(release.tag_name)

        if isNewer(latest, than: current) {
            await Task { @MainActor in
                APILogger.shared.log(
                    level: .success, source: "Updates", method: "GET",
                    url: url.absoluteString, statusCode: statusCode,
                    message: "Update available: \(latest) (current \(current))"
                )
            }.value
            return .updateAvailable(current: current, latest: latest, releaseURL: releaseURL)
        } else {
            await Task { @MainActor in
                APILogger.shared.log(
                    level: .success, source: "Updates", method: "GET",
                    url: url.absoluteString, statusCode: statusCode,
                    message: "Up to date (current \(current), latest \(latest))"
                )
            }.value
            return .upToDate(current: current)
        }
    }

    /// The running app version. In DEBUG builds this can be overridden via the
    /// `UPDATE_CHECK_CURRENT_VERSION` environment variable (set it in the Xcode
    /// scheme's Run ▸ Arguments tab) to simulate an older install without rebuilding.
    private static var currentVersion: String? {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["UPDATE_CHECK_CURRENT_VERSION"],
           !override.isEmpty {
            return override
        }
        #endif
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    private static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    }

    private static func logError(url: String, statusCode: Int? = nil, message: String) async {
        await Task { @MainActor in
            APILogger.shared.log(
                level: .error, source: "Updates", method: "GET",
                url: url, statusCode: statusCode, message: message
            )
        }.value
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: break
        default: throw UpdateError.httpError(http.statusCode)
        }
    }

    /// Strips a leading "v" and surrounding whitespace from a tag like "v1.2.1".
    static func normalizedVersion(_ tag: String) -> String {
        var s = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") {
            s.removeFirst()
        }
        return s
    }

    /// Compares dotted numeric versions component-by-component, padding the shorter
    /// with zeros (so "1.2" == "1.2.0"). Non-numeric components are treated as 0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = components(of: normalizedVersion(candidate))
        let b = components(of: normalizedVersion(current))
        let count = max(a.count, b.count)
        for i in 0..<count {
            let lhs = i < a.count ? a[i] : 0
            let rhs = i < b.count ? b[i] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }

    private static func components(of version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
