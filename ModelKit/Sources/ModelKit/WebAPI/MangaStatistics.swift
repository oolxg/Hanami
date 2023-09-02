//
//  MangaStatistics.swift
//  Hanami
//
//  Created by Oleg on 13/06/2022.
//

import Foundation

public struct MangaStatisticsContainer: Decodable {
    public let statistics: [UUID: MangaStatistics]
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
    
    // https://github.com/apple/swift-corelibs-foundation/issues/3614#issuecomment-1118348969
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        let tempStringStatistics = try container.decode(
            [String: MangaStatistics].self,
            forKey: DynamicCodingKeys(stringValue: "statistics")!
        )
        
        var tempUUIDStatistics: [UUID: MangaStatistics] = [:]
        
        for (id, stat) in tempStringStatistics {
            guard let uuid = UUID(uuidString: id) else { continue }

            tempUUIDStatistics[uuid] = stat
        }
        
        statistics = tempUUIDStatistics
    }
}

public struct MangaStatistics: Decodable {
    public let rating: MangaRating
    public let follows: Int
    
    // MARK: - Rating
    public struct MangaRating: Decodable {
        public let average: Double?
        public let bayesian: Double
    }
}

extension MangaStatistics: Equatable { }

extension MangaStatistics.MangaRating: Equatable { }

public extension MangaStatisticsContainer {
    init(statistics: [UUID: MangaStatistics]) {
        self.statistics = statistics
    }
}
