//
//  LocalizedString.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation


struct LocalizedString: Codable {
    var en, fr, ru, jp, jpRo, zh, zhRo, es, esLa: String?
    
    enum CodingKeys: String, CodingKey {
        case en, ru, zh, fr, es
        case jp = "ja"
        case jpRo = "jp-ro"
        case zhRo = "zh-ro"
        case esLa = "es-la"
    }
}

extension LocalizedString {
    init(localizedStrings langContent: [LocalizedString]) {
        langContent.forEach { content in
            en = content.en == nil ? en : content.en
            fr = content.fr == nil ? fr : content.fr
            es = content.es == nil ? es : content.es
            esLa = content.esLa == nil ? esLa : content.esLa
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
    var availableLang: String {
        if let en = en {
            return en
        } else if let fr = fr {
            return fr
        } else if let es = es {
            return es
        } else if let esLa = esLa {
            return esLa
        }  else if let jpRo = jpRo {
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
    
    var languageFlag: String {
        if en != nil {
            return "🇬🇧"
        }  else if fr != nil {
            return "🇫🇷"
        }  else if es != nil || esLa != nil {
            return "🇪🇸"
        } else if jpRo != nil || jp != nil {
            return "🇯🇵"
        } else if ru != nil {
            return "🇷🇺"
        } else if zhRo != nil || zh != nil {
            return "🇨🇳"
        }
        
        return "❓"
    }
}
