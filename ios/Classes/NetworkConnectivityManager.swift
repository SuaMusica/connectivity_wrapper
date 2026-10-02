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
final class NetworkConnectivityManager {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.suamusica.connectivity_wrapper.network")
    private var latestPath: NWPath?
    private let lock = NSLock()
    private var isMonitoring = false
    private var lastEmittedStatus: ConnectivityStatus = .offline
    var onStatusChanged: ((ConnectivityStatus) -> Void)?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        let pathMonitor = NWPathMonitor()
        monitor = pathMonitor
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        pathMonitor.start(queue: queue)
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor?.cancel()
        monitor = nil
    }

    func currentStatus() -> ConnectivityStatus {
        lock.lock()
        let path = latestPath
        lock.unlock()

        if let path {
            return status(from: path)
        }
        if let path = Self.fetchCurrentPathSync() {
            lock.lock()
            latestPath = path
            lock.unlock()
            return status(from: path)
        }
        return legacyReachabilityStatus()
    }

    private func handlePathUpdate(_ path: NWPath) {
        lock.lock()
        latestPath = path
        lock.unlock()
        emit(status(from: path))
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
        lock.lock()
        guard lastEmittedStatus != status else {
            lock.unlock()
            return
        }
        let previous = lastEmittedStatus
        lastEmittedStatus = status
        lock.unlock()
        NSLog("[ConnectivityWrapper] status %@ -> %@", previous.toWire(), status.toWire())
        onStatusChanged?(status)
    }

    private static func fetchCurrentPathSync(timeout: TimeInterval = 2) -> NWPath? {
        let monitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var result: NWPath?

        monitor.pathUpdateHandler = { path in
            result = path
            semaphore.signal()
            monitor.cancel()
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            monitor.cancel()
        }
        return result
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

    private func legacyReachabilityStatus() -> ConnectivityStatus {
        guard let flags = currentReachabilityFlags() else {
            return .offline
        }
        if !flags.reachable {
            return .offline
        }
        if flags.interventionRequired || flags.connectionRequired {
            return .limited
        }
        return .online
    }
}
