//
//  MangaStatistics.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/06/2022.
//

import Foundation

struct MangaStatisticsContainer: Codable {
    let result: String
    let statistics: [UUID: MangaStatistics]
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var tempResult = ""
        var tempStringStatistics: [String: MangaStatistics] = [:]
        
        for key in container.allKeys {
            if key.stringValue == "result" {
                tempResult = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            } else if key.stringValue == "statistics" {
                tempStringStatistics = try container.decode(
                    [String: MangaStatistics].self,
                    forKey: DynamicCodingKeys(stringValue: key.stringValue)!
                )
            }
        }
        
        var tempUUIDStatistics: [UUID: MangaStatistics] = [:]
        
        for (id, stat) in tempStringStatistics {
            guard let uuid = UUID(uuidString: id) else { continue }
            
            tempUUIDStatistics[uuid] = stat
        }
        
        result = tempResult
        statistics = tempUUIDStatistics
    }
}

struct MangaStatistics: Codable {
    let rating: MangaRating
    let follows: Int
}

// MARK: - Rating
struct MangaRating: Codable {
    let average: Double?
    let bayesian: Double
}

extension MangaRating: Equatable { }


extension MangaStatistics: Equatable { }
