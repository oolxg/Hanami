//
//  NetworkMonitor.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/07/2022.
//

import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "InternetConnectionMonitor")
    @Published private(set) var isConnected = true
    @Published private(set) var isExpensive = false
    
    private init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
            }
        }
        
        monitor.start(queue: queue)
    }
}
