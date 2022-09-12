//
//  LocalizedString.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation

// For details see
// https://api.mangadex.org/docs/static-data/#language-codes--localization

// swiftlint:disable identifier_name
struct LocalizedString: Codable {
    var en, fr, ru, jp, jpRo, th: String?
    var zh, zhRo, es, esLa, ar: String?
    var uk, it, ko: String?
    
    enum CodingKeys: String, CodingKey {
        case en, ru, zh, fr
        case es, ar, th, uk
        case jp = "ja"
        case jpRo = "ja-ro"
        case zhRo = "zh-ro"
        case esLa = "es-la"
        case it, ko
    }
}

extension LocalizedString {
    init(localizedStrings langContent: [LocalizedString]) {
        langContent.forEach { content in
            en = en == nil ? content.en : en
            uk = uk == nil ? content.uk : uk
            fr = fr == nil ? content.fr : fr
            es = es == nil ? content.es : es
            esLa = esLa == nil ? content.esLa : esLa
            ru = ru == nil ? content.ru : ru
            jp = jp == nil ? content.jp : jp
            jpRo = jpRo == nil ? content.jpRo : jpRo
            zh = zh == nil ? content.zh : zh
            zhRo = zhRo == nil ? content.zhRo : zhRo
            ar = ar == nil ? content.ar : ar
            th = th == nil ? content.th : th
            it = it == nil ? content.it : it
            ko = ko == nil ? content.ko : ko
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
        } else if let it = it {
            return it
        } else if let ko = ko {
            return ko
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
        } else if it != nil {
            return "🇮🇹"
        } else if ko != nil {
            return "🇰🇷"
        }
        
        return "❓"
    }
}
