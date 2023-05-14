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
    var ar, cs, de, en, es, esLa: String?
    var hi, hu, fa, fr, it: String?
    var jp, jpRo, ko, mn, ms: String?
    var nl, ru, th, uk, zh: String?
    var zhRo: String?
    
    enum CodingKeys: String, CodingKey {
        case ar, cs, en, es, de
        case esLa = "es-la"
        case hi, hu, fa, fr, it
        case jp = "ja"
        case jpRo = "ja-ro"
        case ko, mn, ms, nl, ru
        case th, uk, zh
        case zhRo = "zh-ro"
    }
}

extension LocalizedString {
    init(localizedStrings: [LocalizedString]) {
        localizedStrings.forEach { content in
            ar = ar.isNil ? content.ar : ar
            cs = cs.isNil ? content.cs : cs
            de = de.isNil ? content.de : de
            en = en.isNil ? content.en : en
            es = es.isNil ? content.es : es
            esLa = esLa.isNil ? content.esLa : esLa
            hi = hi.isNil ? content.hi : hi
            hu = hu.isNil ? content.hu : hu
            fa = fa.isNil ? content.fa : fa
            fr = fr.isNil ? content.fr : fr
            it = it.isNil ? content.it : it
            jp = jp.isNil ? content.jp : jp
            jpRo = jpRo.isNil ? content.jpRo : jpRo
            ko = ko.isNil ? content.ko : ko
            mn = mn.isNil ? content.mn : mn
            ms = ms.isNil ? content.ms : ms
            nl = nl.isNil ? content.nl : nl
            ru = ru.isNil ? content.ru : ru
            th = th.isNil ? content.th : th
            uk = uk.isNil ? content.uk : uk
            zh = zh.isNil ? content.zh : zh
            zhRo = zhRo.isNil ? content.zhRo : zhRo
        }
    }
}

extension LocalizedString: Equatable { }

extension LocalizedString {
    var availableText: String? {
        if let en {
            return en
        } else if let ar {
            return ar
        } else if let cs {
            return cs
        } else if let de {
            return de
        } else if let es {
            return es
        } else if let esLa {
            return esLa
        } else if let hi {
            return hi
        } else if let hu {
            return hu
        } else if let fa {
            return fa
        } else if let fr {
            return fr
        } else if let it {
            return it
        } else if let jp {
            return jp
        } else if let jpRo {
            return jpRo
        } else if let ko {
            return ko
        } else if let mn {
            return mn
        } else if let ms {
            return ms
        } else if let nl {
            return nl
        } else if let ru {
            return ru
        } else if let th {
            return th
        } else if let uk {
            return uk
        } else if let zh {
            return zh
        } else if let zhRo {
            return zhRo
        }
        
        return nil
    }
}
// swiftlint:enable identifier_name
