//
//  NetworkMonitor.swift
//  Hanami
//
//  Created by Oleg on 15/07/2022.
//

import Network
import Combine
import Dependencies

public extension DependencyValues {
    var networkMonitor: NetworkMonitor {
        get { self[NetworkMonitor.self] }
        set { self[NetworkMonitor.self] = newValue }
    }
}

public final class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "moe.mkpwnz.Hanami.NetworkMonitor", qos: .background)
    @Published public private(set) var isConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        
        monitor.start(queue: queue)
    }
}

extension NetworkMonitor: DependencyKey {
    public static let liveValue = NetworkMonitor()
}
