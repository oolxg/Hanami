//
//  ISO639-1.swift
//  Hanami
//
//  Created by Oleg on 11.01.23.
//

import Foundation

enum ISO639Language: String {
    // swiftlint:disable identifier_name
    case ar, cs, de, en, es
    case esLa = "es-la"
    case hi, hu, fa, fr, it
    case jp = "ja"
    case jpRo = "ja-ro"
    case ko, mn, ms, nl, ru
    case ptBr = "pt-br"
    case vi, th, uk, zh
    case zhRo = "zh-ro"
    // swiftlint:enable identifier_name
}

extension ISO639Language {
    static var deviceLanguage: Self? {
        guard let deviceLangStr = NSLocale.current.languageCode else {
            return nil
        }
        
        return ISO639Language(rawValue: deviceLangStr)
    }
    
    var language: String {
        switch self {
        case .ar: return "Arabic"
        case .de: return "German"
        case .zh: return "Chinese"
        case .cs: return "Czech"
        case .nl: return "Dutch, Flemish"
        case .en: return "English"
        case .fr: return "French"
        case .hi: return "Hindi"
        case .hu: return "Hungarian"
        case .it: return "Italian"
        case .ptBr: return "Brazilian Portugese"
        case .ko: return "Korean"
        case .ms: return "Malay"
        case .mn: return "Mongolian"
        case .fa: return "Persian"
        case .vi: return "Vietnamese"
        case .ru: return "Russian"
        case .es: return "Spanish, Castilian"
        case .th: return "Thai"
        case .uk: return "Ukrainian"
        case .esLa: return "Latin American Spanish"
        case .jp: return "Japanese"
        case .jpRo: return "Romanized Japanese"
        case .zhRo: return "Romanized Chinese"
        }
    }
}

extension ISO639Language: Codable { }
extension ISO639Language: CaseIterable { }
extension ISO639Language: Identifiable { var id: Self { self } }
extension ISO639Language: Equatable { }
