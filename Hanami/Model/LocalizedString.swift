//
//  LocalizedString.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation

// swiftlint:disable identifier_name
struct LocalizedString: Codable {
    var en, fr, ru, jp, jpRo, th: String?
    var zh, zhRo, es, esLa, ar: String?
    var uk: String?
    
    enum CodingKeys: String, CodingKey {
        case en, ru, zh, fr
        case es, ar, th, uk
        case jp = "ja"
        case jpRo = "ja-ro"
        case zhRo = "zh-ro"
        case esLa = "es-la"
    }
}

extension LocalizedString {
    init(localizedStrings langContent: [LocalizedString]) {
        langContent.forEach { content in
            en = content.en == nil ? en : content.en
            uk = content.uk == nil ? uk : content.uk
            fr = content.fr == nil ? fr : content.fr
            es = content.es == nil ? es : content.es
            esLa = content.esLa == nil ? esLa : content.esLa
            ru = content.ru == nil ? ru : content.ru
            jp = content.jp == nil ? jp : content.jp
            jpRo = content.jpRo == nil ? jpRo : content.jpRo
            zh = content.zh == nil ? zh : content.zh
            zhRo = content.zhRo == nil ? zhRo : content.zhRo
            ar = content.ar == nil ? ar : content.ar
            th = content.th == nil ? th : content.th
        }
    }
}

extension LocalizedString: Equatable { }

extension LocalizedString {
    var availableLang: String? {
        if let en = en {
            return en
        } else if let fr = fr {
            return fr
        } else if let es = es {
            return es
        } else if let esLa = esLa {
            return esLa
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
        } else if let ar = ar {
            return ar
        } else if let th = th {
            return th
        } else if let uk = uk {
            return uk
        }
        
        return nil
    }
    
    var languageFlag: String {
        if en != nil {
            return "🇬🇧"
        } else if fr != nil {
            return "🇫🇷"
        } else if es != nil {
            return "🇪🇸"
        } else if esLa != nil {
            return "🇲🇽"
        } else if jpRo != nil || jp != nil {
            return "🇯🇵"
        } else if ru != nil {
            return "🇷🇺"
        } else if zhRo != nil || zh != nil {
            return "🇨🇳"
        } else if ar != nil {
            return "🇸🇦"
        } else if th != nil {
            return "🇹🇭"
        } else if uk != nil {
            return "🇺🇦"
        }
        
        return "❓"
    }
}
