//
//  Tag.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation

// swiftlint:disable identifier_name
// MARK: - Tag
struct Tag: Codable {
    let id: UUID
    let attributes: Attributes
    let relationships: [Relationship]?
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let name: TagName
        let group: Group
        let version: Int
        
        enum Group: String, Codable {
            case content, format, theme, genre
        }
        
        struct TagName: Codable {
            let en: Name
            
            enum Name: String, Codable {
                /* Format types */
                case oneshot = "Oneshot"
                case awardWinning = "Award Winning"
                case officialColored = "Official Colored"
                case longStrip = "Long Strip"
                case anthology = "Anthology"
                case fanColored = "Fan Colored"
                case userCreated = "User Created"
                case fourKoma = "4-Koma"
                case doujinshi = "Doujinshi"
                case webComic = "Web Comic"
                case adaptation = "Adaptation"
                case fullColor = "Full Color"
                /* Format types END */
                
                /* Theme types */
                case reincarnation = "Reincarnation"
                case timeTravel = "Time Travel"
                case genderswap = "Genderswap"
                case loli = "Loli"
                case traditionalGames = "Traditional Games"
                case monsters = "Monsters"
                case demons = "Demons"
                case ghosts = "Ghosts"
                case animals = "Animals"
                case ninja = "Ninja"
                case incest = "Incest"
                case survival = "Survival"
                case zombies = "Zombies"
                case reverseHarem = "Reverse Harem"
                case martialArts = "Martial Arts"
                case samurai = "Samurai"
                case mafia = "Mafia"
                case virtualReality = "Virtual Reality"
                case officeWorkers = "Office Workers"
                case videoGames = "Video Games"
                case postApocalyptic = "Post-Apocalyptic"
                case crossdressing = "Crossdressing"
                case magic = "Magic"
                case harem = "Harem"
                case military = "Military"
                case schoolLife = "School Life"
                case villainess = "Villainess"
                case vampires = "Vampires"
                case delinquents = "Delinquents"
                case monsterGirls = "Monster Girls"
                case shota = "Shota"
                case police = "Police"
                case aliens = "Aliens"
                case cooking = "Cooking"
                case supernatural = "Supernatural"
                case music = "Music"
                case gyaru = "Gyaru"
                /* Theme type END */
                
                /* Content types */
                case sexualViolence = "Sexual Violence"
                case gore = "Gore"
                /* Content types END */
                
                /* Genre types */
                case thriller = "Thriller"
                case sciFi = "Sci-Fi"
                case historical = "Historical"
                case action = "Action"
                case psychological = "Psychological"
                case romance = "Romance"
                case comedy = "Comedy"
                case mecha = "Mecha"
                case boysLove = "Boys' Love"
                case crime = "Crime"
                case sports = "Sports"
                case superhero = "Superhero"
                case magicalGirls = "Magical Girls"
                case adventure = "Adventure"
                case girlsLove = "Girls' Love"
                case wuxia = "Wuxia"
                case isekai = "Isekai"
                case philosophical = "Philosophical"
                case drama = "Drama"
                case medical = "Medical"
                case horror = "Horror"
                case fantasy = "Fantasy"
                case sliceOfLife = "Slice of Life"
                case mystery = "Mystery"
                case tragedy = "Tragedy"
                /* Genre types END */
            }
        }
    }
}

extension Tag: Equatable {
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
}

extension Tag: Identifiable { }

extension Tag {
    var name: String {
        attributes.name.en.rawValue
    }
}
// swiftlint:enable identifier_name
