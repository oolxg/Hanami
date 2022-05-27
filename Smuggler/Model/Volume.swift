//
//  Volume.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import Foundation

// JSON Example https://api.mangadex.org/manga/9d3d3403-1a87-4737-9803-bc3d99db1424/aggregate
/*

{
    "result":"ok",
    "volumes":{
        "none":{
            "volume":"none",
            "count":13,
            "chapters":{
                "7":{
                    "chapter":"7",
                    "id":"5b459e5a-1b92-4173-913f-2461d1126dc2",
                    "others":[
                        
                    ],
                    "count":1
                },
                "6":{
                    "chapter":"6",
                    "id":"f663173e-cc94-4cf8-9d2a-491f763ee949",
                    "others":[
                        "c037ec52-e036-426f-b577-b588cd0362fa"
                    ],
                    "count":2
                },
                "5":{
                    "chapter":"5",
                    "id":"0a51631d-70ba-48c5-87b5-d1e3071b2430",
                    "others":[
                        "c9271404-f701-476c-b448-6849d970cb93"
                    ],
                    "count":2
                },
                "4":{
                    "chapter":"4",
                    "id":"85a77d44-58d3-4018-9d60-608a62161c79",
                    "others":[
                        "9528152b-5e91-4118-abfc-471862ec3759"
                    ],
                    "count":2
                },
                "3":{
                    "chapter":"3",
                    "id":"aa32de98-f603-4554-ae67-928cc5294c74",
                    "others":[
                        "d2bcab62-41c9-49f6-9cc8-574f6e82f9ac"
                    ],
                    "count":2
                },
                "2":{
                    "chapter":"2",
                    "id":"d2726135-c790-4b79-bc5b-f4e96eae2ff4",
                    "others":[
                        "0b1c07a5-8dac-438d-9f3d-4bb289fa2d37"
                    ],
                    "count":2
                },
                "1":{
                    "chapter":"1",
                    "id":"af9a4326-9934-41bb-b666-fd5d8784fe4b",
                    "others":[
                        "3a25fa25-cd11-4408-afac-1323839c6397"
                    ],
                    "count":2
                }
            }
        }
    }
}
 
 */

struct Volumes: Codable {
    let volumes: [Volume]
    
    init() {
        volumes = []
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var temp = [Volume]()
        
        for key in container.allKeys {
            if key.stringValue == "volumes" {
                do {
                    let decodedVolumes = try container.decode([String: Volume].self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
                    temp = decodedVolumes.map(\.value)
                } catch DecodingError.typeMismatch {
                    temp = try container.decode([Volume].self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
                }
            }
        }
        
        volumes = temp.sorted(by: { ($0.volumeIndex ?? -1) > ($1.volumeIndex ?? -1) })
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
}

struct Volume: Codable {
    let chapters: [Chapter]
    let count: Int
    // sometimes volumes can have number as double, e.g. 77.6 (for extras or oneshots),
    // if volume has no index(returns 'none'), 'volumeIndex' will be set to nil
    let volumeIndex: Double?
    let id: UUID
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        var tempDecodedChapters = [Chapter]()
        var tempCount = 0
        var tempVolume: String = "none"
        
        for key in container.allKeys {
            if key.stringValue == "chapters" {
                let decodedChapters = try container.decode([String: Chapter].self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
                tempDecodedChapters = decodedChapters.map(\.value)
            } else if key.stringValue == "count" {
                tempCount = try container.decode(Int.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            }  else if key.stringValue == "volume" {
                tempVolume = try container.decode(String.self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            }
        }
        id = UUID()
        chapters = tempDecodedChapters.sorted(by: { ($0.chapterIndex ?? -1) > ($1.chapterIndex ?? -1) })
        count = tempCount
        volumeIndex = Double(tempVolume)
    }
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
    
}

extension Volume: Equatable {
    static func ==(lhs: Volume, rhs: Volume) -> Bool {
        lhs.chapters == rhs.chapters
    }
}

extension Volume: Identifiable { }

extension Volume {
    init(dummyInit: Bool) {
        if !dummyInit {
            fatalError("Only for testing")
        }
        
        self.chapters = []
        self.id = UUID()
        self.volumeIndex = 0
        self.count = 0
    }
}

extension Volumes: Equatable {
    static func ==(lhs: Volumes, rhs: Volumes) -> Bool {
        lhs.volumes == rhs.volumes
    }
}

extension Volume {
    var volumeName: String {
        volumeIndex == nil ? "No volume" : "Volume \(volumeIndex!.clean)"
    }
}
