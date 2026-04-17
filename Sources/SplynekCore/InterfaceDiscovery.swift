import Foundation
import Network
import Darwin

/// Enumerate active interfaces on macOS and classify them.
///
/// Two sources are merged:
///   1. `getifaddrs()` gives us BSD name + IPv4/IPv6 addresses for every up interface.
///   2. `NWPathMonitor` gives us matching `NWInterface` objects (with `type`),
///      which is what `NWParameters.requiredInterface` wants.
///
/// The two lists are joined on BSD name. Interfaces with no usable address
/// (no IPv4 and no non-link-local IPv6) are dropped.
enum InterfaceDiscovery {

    static func current() async -> [DiscoveredInterface] {
        async let posix = posixInterfaces()
        async let nw = nwInterfacesByName()
        let (posixList, nwMap) = await (posix, nw)

        return posixList.compactMap { entry -> DiscoveredInterface? in
            // Must have at least one usable address.
            guard entry.ipv4 != nil || entry.ipv6 != nil else { return nil }

            let nwIf = nwMap[entry.name]
            let kind: DiscoveredInterface.Kind
            if let t = nwIf?.type {
                switch t {
                case .wifi:          kind = .wifi
                case .wiredEthernet: kind = .ethernet
                case .cellular:      kind = .cellular
                case .loopback:      return nil
                case .other:         kind = classifyOther(name: entry.name)
                @unknown default:    kind = .other
                }
            } else {
                kind = classifyOther(name: entry.name)
            }

            if kind == .other, entry.name.hasPrefix("utun") || entry.name.hasPrefix("ipsec") ||
                entry.name.hasPrefix("ppp") || entry.name.hasPrefix("gif") {
                return nil  // VPN / tunnel
            }

            return DiscoveredInterface(
                name: entry.name,
                ipv4: entry.ipv4,
                ipv6: entry.ipv6,
                ifindex: entry.ifindex,
                kind: kind,
                nwInterface: nwIf
            )
        }
    }

    // MARK: POSIX

    private struct PosixEntry {
        let name: String
        var ipv4: String?
        var ipv6: String?
        var ifindex: UInt32
    }

    private static func posixInterfaces() async -> [PosixEntry] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(first) }

        var byName: [String: PosixEntry] = [:]
        var order: [String] = []

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            defer { cursor = ptr.pointee.ifa_next }
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0 else { continue }
            guard let sa = ptr.pointee.ifa_addr else { continue }

            let name = String(cString: ptr.pointee.ifa_name)
            let family = sa.pointee.sa_family

            if family == UInt8(AF_INET) {
                let ip = parseIPv4(sa)
                if let ip, !ip.hasPrefix("127.") && !ip.hasPrefix("169.254.") {
                    if var entry = byName[name] {
                        if entry.ipv4 == nil { entry.ipv4 = ip; byName[name] = entry }
                    } else {
                        byName[name] = PosixEntry(name: name, ipv4: ip, ipv6: nil,
                                                  ifindex: if_nametoindex(ptr.pointee.ifa_name))
                        order.append(name)
                    }
                }
            } else if family == UInt8(AF_INET6) {
                let ip = parseIPv6(sa)
                // Skip loopback (::1) and link-local (fe80::/10) — only globally
                // routable v6 is useful for egress.
                if let ip,
                   !ip.hasPrefix("::1"),
                   !ip.lowercased().hasPrefix("fe80:") {
                    if var entry = byName[name] {
                        if entry.ipv6 == nil { entry.ipv6 = ip; byName[name] = entry }
                    } else {
                        byName[name] = PosixEntry(name: name, ipv4: nil, ipv6: ip,
                                                  ifindex: if_nametoindex(ptr.pointee.ifa_name))
                        order.append(name)
                    }
                }
            }
        }
        return order.compactMap { byName[$0] }
    }

    private static func parseIPv4(_ sa: UnsafePointer<sockaddr>) -> String? {
        let saIn = UnsafeRawPointer(sa).assumingMemoryBound(to: sockaddr_in.self)
        var inAddr = saIn.pointee.sin_addr
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard let cstr = inet_ntop(AF_INET, &inAddr, &buf, socklen_t(INET_ADDRSTRLEN)) else {
            return nil
        }
        return String(cString: cstr)
    }

    private static func parseIPv6(_ sa: UnsafePointer<sockaddr>) -> String? {
        let saIn6 = UnsafeRawPointer(sa).assumingMemoryBound(to: sockaddr_in6.self)
        var in6Addr = saIn6.pointee.sin6_addr
        var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard let cstr = inet_ntop(AF_INET6, &in6Addr, &buf, socklen_t(INET6_ADDRSTRLEN)) else {
            return nil
        }
        return String(cString: cstr)
    }

    // MARK: Network.framework

    /// Returns a snapshot of `NWInterface`s from a short-lived NWPathMonitor,
    /// keyed by BSD name.
    private static func nwInterfacesByName() async -> [String: NWInterface] {
        await withCheckedContinuation { cont in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "splynek.nwpath")
            let gate = ResumeGate()
            monitor.pathUpdateHandler = { path in
                guard gate.fire() else { return }
                var dict: [String: NWInterface] = [:]
                for iface in path.availableInterfaces {
                    dict[iface.name] = iface
                }
                monitor.cancel()
                cont.resume(returning: dict)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 1.5) {
                guard gate.fire() else { return }
                monitor.cancel()
                cont.resume(returning: [:])
            }
        }
    }

    // MARK: Heuristics

    private static func classifyOther(name: String) -> DiscoveredInterface.Kind {
        if name.hasPrefix("pdp_ip") || name.hasPrefix("rmnet") { return .cellular }
        if name.hasPrefix("en") { return .ethernet }
        return .other
    }
}
