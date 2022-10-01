//
//  MangaVolume.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import Foundation

struct VolumesContainer: Codable {
    let volumes: [MangaVolume]
    
    init() {
        volumes = []
    }
    
    init(from decoder: Decoder) throws {
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
        volumes = temp.sorted { ($0.volumeIndex ?? 9999) > ($1.volumeIndex ?? 9999) }
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
}

struct MangaVolume: Codable {
    let chapters: [Chapter]
    // sometimes volumes can have number as double, e.g. 77.6 (for extras or oneshots),
    // if volume has no index(returns 'none'), 'volumeIndex' will be set to nil
    let volumeIndex: Double?
    
    init(from decoder: Decoder) throws {
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
        chapters = tempDecodedChapters.sorted { ($0.chapterIndex ?? 99999) > ($1.chapterIndex ?? 99999) }
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
    static func == (lhs: MangaVolume, rhs: MangaVolume) -> Bool {
        lhs.chapters == rhs.chapters
    }
}

extension MangaVolume {
    var volumeName: String {
        volumeIndex == nil ? "No volume" : "Volume \(volumeIndex!.clean())"
    }
}

extension MangaVolume {
    init(chapters: [Chapter], volumeIndex: Double?) {
        self.chapters = chapters
        self.volumeIndex = volumeIndex
    }
}
