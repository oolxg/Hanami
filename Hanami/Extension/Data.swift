//
//  Data.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation

extension Data {
    func decodeToObject<O: Decodable>(decoder: JSONDecoder = AppUtil.decoder) -> O? {
        var isError = true
        do {
            _ = try decoder.decode(O.self, from: self)
            isError = false
        } catch let DecodingError.dataCorrupted(context) {
            print(context)
        } catch let DecodingError.keyNotFound(key, context) {
            print("Key '\(key)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch let DecodingError.valueNotFound(value, context) {
            print("Value '\(value)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch let DecodingError.typeMismatch(type, context) {
            print("Type '\(type)' mismatch:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch {
            print("error: ", error)
        }
        
        if isError {
            print(String(data: self, encoding: .utf8)!)
        }
        
        return try? decoder.decode(O.self, from: self)
    }
}
