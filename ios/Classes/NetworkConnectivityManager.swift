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

final class NetworkConnectivityManager {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.suamusica.connectivity_wrapper.network")
    private var latestPath: NWPath?
    private let lock = NSLock()
    private var isMonitoring = false
    var onStatusChanged: ((ConnectivityStatus) -> Void)?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.latestPath = path
            self.lock.unlock()
            let status = self.status(from: path)
            self.onStatusChanged?(status)
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor.cancel()
    }

    func currentStatus() -> ConnectivityStatus {
        lock.lock()
        let path = latestPath
        lock.unlock()

        if let path {
            return status(from: path)
        }
        return legacyStatus()
    }

    private func status(from path: NWPath) -> ConnectivityStatus {
        switch path.status {
        case .satisfied:
            if legacyIndicatesCaptivePortal() {
                return .limited
            }
            return .online
        case .requiresConnection:
            return .limited
        case .unsatisfied:
            return .offline
        @unknown default:
            return .offline
        }
    }

    private func legacyStatus() -> ConnectivityStatus {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                SCNetworkReachabilityCreateWithAddress(nil, address)
            }
        }) else {
            return .offline
        }

        var flags: SCNetworkReachabilityFlags = []
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return .offline
        }

        let reachable = flags.contains(.reachable)
        if !reachable {
            return .offline
        }
        if flags.contains(.interventionRequired) {
            return .limited
        }
        let needsConnection = flags.contains(.connectionRequired)
        if needsConnection {
            return .limited
        }
        return .online
    }

    private func legacyIndicatesCaptivePortal() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                SCNetworkReachabilityCreateWithAddress(nil, address)
            }
        }) else {
            return false
        }

        var flags: SCNetworkReachabilityFlags = []
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }
        return flags.contains(.interventionRequired)
    }
}
