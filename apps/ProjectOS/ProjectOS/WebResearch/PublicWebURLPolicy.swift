import Foundation

/// Which addresses ProjectOS will download on the model's behalf: public HTTPS
/// pages only, never this Mac, the local network, or an address carrying
/// credentials.
///
/// It judges the address as written, so a public name that resolves to a
/// private address is not caught here. HTTPS is required both because macOS
/// blocks plain HTTP for this app and because a page read over HTTP could be
/// rewritten in transit.
enum PublicWebURLPolicy {
    static func allows(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              let rawHost = components.host?.lowercased(),
              !rawHost.isEmpty else {
            return false
        }
        let host = rawHost.hasSuffix(".") ? String(rawHost.dropLast()) : rawHost
        guard !host.isEmpty else { return false }

        if host.contains(":") { return isPublicIPv6(host) }
        if looksNumeric(host) { return ipv4Octets(host).map(isPublicIPv4) ?? false }
        // A name without a dot is a local one, such as "intranet".
        guard host.contains(".") else { return false }
        let localSuffixes = [".localhost", ".local", ".internal", ".lan", ".home", ".home.arpa", ".corp", ".intranet"]
        guard !localSuffixes.contains(where: host.hasSuffix), host != "localhost" else { return false }
        return true
    }

    /// Addresses written entirely in digits, dots, or hex escapes are meant as
    /// IP addresses, including short forms such as "127.1".
    private static func looksNumeric(_ host: String) -> Bool {
        host.hasPrefix("0x") || host.allSatisfy { $0.isNumber || $0 == "." }
    }

    private static func ipv4Octets(_ host: String) -> [UInt8]? {
        let pieces = host.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 4 else { return nil }
        let octets = pieces.compactMap { UInt8($0) }
        return octets.count == 4 ? octets : nil
    }

    private static func isPublicIPv4(_ octets: [UInt8]) -> Bool {
        switch (octets[0], octets[1]) {
        case (0, _), (10, _), (127, _): false          // this host, and private space
        case (169, 254): false                          // link-local
        case (172, 16...31): false                      // private space
        case (192, 168): false                          // private space
        case (100, 64...127): false                     // carrier-grade NAT
        case (224...255, _): false                      // multicast and reserved
        default: true
        }
    }

    private static func isPublicIPv6(_ host: String) -> Bool {
        let value = host.hasPrefix("[") ? String(host.dropFirst().dropLast()) : host
        if value == "::" || value == "::1" { return false }
        // Unique-local (fc00::/7), link-local (fe80::/10), and IPv4-mapped
        // addresses, which would smuggle a private IPv4 address through.
        let privatePrefixes = ["fc", "fd", "fe8", "fe9", "fea", "feb", "::ffff:"]
        return !privatePrefixes.contains { value.hasPrefix($0) }
    }
}
