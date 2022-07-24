//
//  CacheClient.swift
//  Smuggler
//
//  Created by mk.pwnz on 24/07/2022.
//

import Foundation
import Cache


struct CacheClient {
    private static var storage: Storage<String, String> {
        let diskConfig = DiskConfig(name: "Smuggler_Cache")
        let memoryConfig = MemoryConfig(expiry: .never)
        
        // switflint:disable:next force_try
        return try! Storage(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: String.self)
        )
    }
    
    private static var coverArtStorage: Storage<String, CoverArtInfo> {
        storage.transformCodable(ofType: CoverArtInfo.self)
    }
    
    let cacheCoverArtInfo: (CoverArtInfo) -> Void
    let fetchCoverArtInfo: (UUID) -> CoverArtInfo?
}

extension CacheClient {
    static let live = CacheClient(
        cacheCoverArtInfo: { coverArtInfo in
            try? coverArtStorage.setObject(coverArtInfo, forKey: coverArtInfo.id.uuidString.lowercased())
        },
        fetchCoverArtInfo: { coverArtID in
            try? coverArtStorage.object(forKey: coverArtID.uuidString.lowercased())
        }
    )
}
