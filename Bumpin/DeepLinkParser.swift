import Foundation

struct DeepLinkParser {
    /// Parses bumpin://join?code=ABC123 and returns the code if present
    static func parseJoinCode(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "bumpin", url.host?.lowercased() == "join" else { return nil }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return comps?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    /// Parses a universal link of the form https://<domain>/join/ABC123 and returns the code if present
    @MainActor
    static func parseUniversalJoinCode(from url: URL) -> String? {
        guard let host = url.host, AppConfig.shared.isAllowedUniversalLinkHost(host) else { return nil }
        let parts = url.pathComponents
        guard parts.count >= 3, parts[1].lowercased() == "join" else { return nil }
        return parts[2].uppercased()
    }

    /// Builds the canonical invite URL for a given 6-character code
    @MainActor
    static func buildInviteURL(forCode code: String) -> URL? {
        return AppConfig.shared.inviteURL(forCode: code)
    }
}


