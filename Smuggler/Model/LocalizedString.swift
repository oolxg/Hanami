//
//  LocalizedString.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation


struct LocalizedString: Codable {
    var en, ru, jp, jpRo, zh, zhRo: String?
    
    enum CodingKeys: String, CodingKey {
        case en, ru, zh
        case jp = "ja"
        case jpRo = "jp-ro"
        case zhRo = "zh-ro"
    }
}

extension LocalizedString {
    init(localizedStrings langContent: [LocalizedString]) {
        langContent.forEach { content in
            en = content.en == nil ? en : content.en
            ru = content.ru == nil ? ru : content.ru
            jp = content.jp == nil ? jp : content.jp
            jpRo = content.jpRo == nil ? jpRo : content.jpRo
            zh = content.zh == nil ? zh : content.zh
            zhRo = content.zhRo == nil ? zhRo : content.zhRo
        }
    }
}

extension LocalizedString: Equatable { }

extension LocalizedString {
    func getAvailableName() -> String {
        if let en = en {
            return en
        } else if let jpRo = jpRo {
            return jpRo
        } else if let jp = jp {
            return jp
        } else if let ru = ru {
            return ru
        } else if let zhRo = zhRo {
            return zhRo
        } else if let zh = zh {
            return zh
        }
        
        return "No available name"
    }
}
