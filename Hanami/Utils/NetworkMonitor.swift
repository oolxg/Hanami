//
//  NetworkMonitor.swift
//  Hanami
//
//  Created by Oleg on 15/07/2022.
//

import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "moe.mkpwnz.Hanami.NetworkMonitor")
    @Published private(set) var isConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        
        monitor.start(queue: queue)
    }
}
