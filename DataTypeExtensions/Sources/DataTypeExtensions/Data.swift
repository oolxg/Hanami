//
//  Data.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation
import Utils

public extension Data {
    func decodeToObject<O: Decodable>(decoder: JSONDecoder = AppUtil.decoder) -> O? {
        do {
            return try decoder.decode(O.self, from: self)
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
        
        print(String(data: self, encoding: .utf8)!)
        return nil
    }
}
