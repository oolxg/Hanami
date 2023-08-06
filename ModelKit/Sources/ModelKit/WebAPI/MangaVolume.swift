//
//  MangaVolume.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import Foundation
import DataTypeExtensions

public struct VolumesContainer: Decodable {
    public let volumes: [MangaVolume]
    
    public init() {
        volumes = []
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var temp: [MangaVolume] = []
        
        do {
            let decodedVolumes = try container.decode(
                [String: MangaVolume].self,
                forKey: DynamicCodingKeys(stringValue: "volumes")!
            )
            temp = decodedVolumes.map(\.value)
        } catch DecodingError.typeMismatch {
            temp = try container.decode(
                [MangaVolume].self,
                forKey: DynamicCodingKeys(stringValue: "volumes")!
            )
        }
        
        // all volumes w/o index are going to be first in list
        volumes = temp.sorted { ($0.volumeIndex ?? .infinity) > ($1.volumeIndex ?? .infinity) }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
}

public struct MangaVolume: Decodable {
    public let chapters: [Chapter]
    // sometimes volumes can have number as double, e.g. 77.6 (for extras or oneshots),
    // if volume has no index(returns 'none'), 'volumeIndex' will be set to nil
    public let volumeIndex: Double?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        var tempDecodedChapters: [Chapter] = []
        var tempVolume: String = "none"
        
        for key in container.allKeys {
            if key.stringValue == "chapters" {
                do {
                    let decodedChapters = try container.decode(
                        [String: Chapter].self,
                        forKey: DynamicCodingKeys(stringValue: key.stringValue)!
                    )
                    tempDecodedChapters = decodedChapters.map(\.value)
                } catch {
                    tempDecodedChapters = try container.decode(
                        [Chapter].self,
                        forKey: DynamicCodingKeys(stringValue: key.stringValue)!
                    )
                }
            } else if key.stringValue == "volume" {
                tempVolume = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            }
        }
        chapters = tempDecodedChapters.sorted { ($0.index ?? .infinity) > ($1.index ?? .infinity) }
        volumeIndex = Double(tempVolume)
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
}

extension MangaVolume: Equatable {
    public static func == (lhs: MangaVolume, rhs: MangaVolume) -> Bool {
        lhs.chapters == rhs.chapters
    }
}

public extension MangaVolume {
    var volumeName: String {
        volumeIndex.isNil ? "No volume" : "Volume \(volumeIndex!.clean())"
    }
}

public extension MangaVolume {
    init(chapters: [Chapter], volumeIndex: Double?) {
        self.chapters = chapters
        self.volumeIndex = volumeIndex
    }
}
