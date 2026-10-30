import Foundation
import Network
import SystemConfiguration

enum ConnectivityStatus {
    case offline
    case limited
    case online
}

extension ConnectivityStatus {
    func toWire() -> String {
        switch self {
        case .offline: return "offline"
        case .limited: return "limited"
        case .online: return "online"
        }
    }
}

/// Mirrors Android [NetworkConnectivityManager] using only system reachability signals
/// (NWPath + SCNetworkReachability), without app-level HTTP/DNS probes.
///
/// All mutable state is confined to `queue`. Public methods never block the caller:
/// they hop onto `queue` and report back through callbacks.
final class NetworkConnectivityManager {
    private let queue = DispatchQueue(label: "com.suamusica.connectivity_wrapper.network")
    private var monitor: NWPathMonitor?
    private var probeMonitor: NWPathMonitor?
    private var latestPath: NWPath?
    private var lastEmittedStatus: ConnectivityStatus?
    private var onStatusChanged: ((ConnectivityStatus) -> Void)?
    private var pendingStatusRequests: [(ConnectivityStatus) -> Void] = []

    /// The first `NWPath` delivered after start is the current state, so it is emitted
    /// right away (no separate initial read needed). `onStatusChanged` runs on `queue`.
    func startMonitoring(onStatusChanged: @escaping (ConnectivityStatus) -> Void) {
        queue.async {
            self.onStatusChanged = onStatusChanged
            guard self.monitor == nil else { return }
            self.lastEmittedStatus = nil
            let pathMonitor = NWPathMonitor()
            self.monitor = pathMonitor
            pathMonitor.pathUpdateHandler = { [weak self] path in
                self?.handlePathUpdate(path)
            }
            pathMonitor.start(queue: self.queue)
        }
    }

    func stopMonitoring() {
        queue.async {
            self.onStatusChanged = nil
            self.monitor?.cancel()
            self.monitor = nil
            self.latestPath = nil
            self.lastEmittedStatus = nil
        }
    }

    /// `completion` runs on `queue`.
    func currentStatus(completion: @escaping (ConnectivityStatus) -> Void) {
        queue.async {
            if let path = self.latestPath {
                completion(self.status(from: path))
                return
            }
            self.pendingStatusRequests.append(completion)
            if self.monitor == nil {
                self.startProbe()
            }
        }
    }

    /// One-shot path read for `getCurrentStatus` calls made while nobody listens.
    private func startProbe() {
        guard probeMonitor == nil else { return }
        let probe = NWPathMonitor()
        probeMonitor = probe
        probe.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.probeMonitor?.cancel()
            self.probeMonitor = nil
            self.resolvePendingStatusRequests(with: path)
        }
        probe.start(queue: queue)
    }

    private func handlePathUpdate(_ path: NWPath) {
        latestPath = path
        resolvePendingStatusRequests(with: path)
        emit(status(from: path))
    }

    private func resolvePendingStatusRequests(with path: NWPath) {
        guard !pendingStatusRequests.isEmpty else { return }
        let status = status(from: path)
        let requests = pendingStatusRequests
        pendingStatusRequests.removeAll()
        requests.forEach { $0(status) }
    }

    /// Parallel to Android [statusFromCapabilities]: validated path -> online;
    /// captive / transport without a satisfied path -> limited; else offline.
    private func status(from path: NWPath) -> ConnectivityStatus {
        let flags = currentReachabilityFlags()

        if flags?.interventionRequired == true {
            return .limited
        }

        if path.status == .requiresConnection {
            return .limited
        }

        if path.status == .satisfied {
            if flags?.connectionRequired == true {
                return .limited
            }
            // NWPath.satisfied is the system signal that the route is viable (Apple
            // validates internally; same role as NET_CAPABILITY_VALIDATED on Android).
            return .online
        }

        if hasTransport(path) {
            return .limited
        }

        if flags?.reachable == true {
            if flags?.connectionRequired == true {
                return .limited
            }
            return .online
        }

        return .offline
    }

    private func hasTransport(_ path: NWPath) -> Bool {
        path.usesInterfaceType(.wifi) ||
            path.usesInterfaceType(.cellular) ||
            path.usesInterfaceType(.wiredEthernet) ||
            path.usesInterfaceType(.other)
    }

    private func emit(_ status: ConnectivityStatus) {
        guard lastEmittedStatus != status else { return }
        let previous = lastEmittedStatus
        lastEmittedStatus = status
        NSLog("[ConnectivityWrapper] status %@ -> %@", previous?.toWire() ?? "none", status.toWire())
        onStatusChanged?(status)
    }

    private struct ReachabilityFlags {
        let reachable: Bool
        let interventionRequired: Bool
        let connectionRequired: Bool
    }

    private func currentReachabilityFlags() -> ReachabilityFlags? {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                SCNetworkReachabilityCreateWithAddress(nil, address)
            }
        }) else {
            return nil
        }

        var flags: SCNetworkReachabilityFlags = []
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return nil
        }

        return ReachabilityFlags(
            reachable: flags.contains(.reachable),
            interventionRequired: flags.contains(.interventionRequired),
            connectionRequired: flags.contains(.connectionRequired)
        )
    }
}
