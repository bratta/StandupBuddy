import Foundation

struct PullRequest: Sendable {
    let title: String
    let url: String
    let displayName: String
}

enum GitHubService {
    enum GitHubError: Error, LocalizedError {
        case missingToken
        case unauthorized
        case rateLimited
        case httpError(Int)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .missingToken: return "No GitHub Personal Access Token configured. Add one in Settings."
            case .unauthorized: return "GitHub token is invalid or expired."
            case .rateLimited: return "GitHub API rate limit exceeded. Try again later."
            case .httpError(let code): return "GitHub API returned HTTP \(code)."
            case .decodingError: return "Could not parse GitHub API response."
            }
        }
    }

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            let title: String
            let html_url: String
        }
        let items: [Item]
    }

    private struct UserResponse: Decodable {
        let login: String
    }

    static func fetchOpenPRs(repos: [RepositoryConfig]) async throws -> [PullRequest] {
        guard let token = try KeychainService.loadPAT(), !token.isEmpty else {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "GitHub", method: "GET",
                    url: "https://api.github.com/user",
                    message: GitHubError.missingToken.errorDescription!
                )
            }
            throw GitHubError.missingToken
        }

        let login = try await fetchLogin(token: token)
        var results: [PullRequest] = []

        for repo in repos {
            let prs = try await fetchPRs(for: repo, login: login, token: token)
            results.append(contentsOf: prs)
        }
        return results
    }

    private static func fetchLogin(token: String) async throws -> String {
        let url = URL(string: "https://api.github.com/user")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let statusCode: Int?
        do {
            let (responseData, response) = try await URLSession.shared.data(for: req)
            data = responseData
            statusCode = (response as? HTTPURLResponse)?.statusCode
            try validate(response: response)
        } catch let error as GitHubError {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "GitHub", method: "GET",
                    url: url.absoluteString,
                    message: error.errorDescription ?? error.localizedDescription
                )
            }
            throw error
        } catch {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "GitHub", method: "GET",
                    url: url.absoluteString,
                    message: "Network error: \(error.localizedDescription)"
                )
            }
            throw error
        }

        guard let user = try? JSONDecoder().decode(UserResponse.self, from: data) else {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "GitHub", method: "GET",
                    url: url.absoluteString, statusCode: statusCode,
                    message: GitHubError.decodingError.errorDescription!
                )
            }
            throw GitHubError.decodingError
        }

        Task { @MainActor in
            APILogger.shared.log(
                level: .success, source: "GitHub", method: "GET",
                url: url.absoluteString, statusCode: statusCode,
                message: "Authenticated as \(user.login)"
            )
        }
        return user.login
    }

    private static func fetchPRs(for repo: RepositoryConfig, login: String, token: String) async throws -> [PullRequest] {
        let q = "is:pr+is:open+author:\(login)+repo:\(repo.owner)/\(repo.name)"
        let urlStr = "https://api.github.com/search/issues?q=\(q)&per_page=100"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let statusCode: Int?
        do {
            let (responseData, response) = try await URLSession.shared.data(for: req)
            data = responseData
            statusCode = (response as? HTTPURLResponse)?.statusCode
            try validate(response: response)
        } catch let error as GitHubError {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "GitHub", method: "GET",
                    url: url.absoluteString,
                    message: "\(repo.owner)/\(repo.name): \(error.errorDescription ?? error.localizedDescription)"
                )
            }
            throw error
        } catch {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "GitHub", method: "GET",
                    url: url.absoluteString,
                    message: "\(repo.owner)/\(repo.name): Network error: \(error.localizedDescription)"
                )
            }
            throw error
        }

        guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            Task { @MainActor in
                APILogger.shared.log(
                    level: .error, source: "GitHub", method: "GET",
                    url: url.absoluteString, statusCode: statusCode,
                    message: "\(repo.owner)/\(repo.name): \(GitHubError.decodingError.errorDescription!)"
                )
            }
            throw GitHubError.decodingError
        }

        let count = decoded.items.count
        Task { @MainActor in
            APILogger.shared.log(
                level: .success, source: "GitHub", method: "GET",
                url: url.absoluteString, statusCode: statusCode,
                message: "\(repo.owner)/\(repo.name): \(count) open PR\(count == 1 ? "" : "s")"
            )
        }
        return decoded.items.map { PullRequest(title: $0.title, url: $0.html_url, displayName: repo.displayName) }
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: break
        case 401: throw GitHubError.unauthorized
        case 403: throw GitHubError.rateLimited
        default: throw GitHubError.httpError(http.statusCode)
        }
    }
}
