//
//  Publisher.swift
//  Hanami
//
//  Created by Oleg on 27/05/2022.
//

import Foundation
import Combine

extension Publisher {
    #if DEBUG
    func debugDecode<Item: Decodable>(type: Item.Type, decoder: JSONDecoder = AppUtil.decoder) -> AnyPublisher<Output, Never> where Self.Output == Data {
        map { data in
            do {
                _ = try decoder.decode(type, from: data)
                return data
            } catch let DecodingError.dataCorrupted(context) {
                Swift.print(context)
            } catch let DecodingError.keyNotFound(key, context) {
                Swift.print("Key '\(key)' not found:", context.debugDescription)
                Swift.print("codingPath:", context.codingPath)
            } catch let DecodingError.valueNotFound(value, context) {
                Swift.print("Value '\(value)' not found:", context.debugDescription)
                Swift.print("codingPath:", context.codingPath)
            } catch let DecodingError.typeMismatch(type, context) {
                Swift.print("Type '\(type)' mismatch:", context.debugDescription)
                Swift.print("codingPath:", context.codingPath)
            } catch {
                Swift.print("error: ", error)
            }
            
            Swift.print(String(data: data, encoding: .utf8)!)
            
            return data
        }
        .catch { _ in Empty() }
        .eraseToAnyPublisher()
    }
    #endif
    
    func validateResponseCode() -> AnyPublisher<Output, Error> where Output == URLSession.DataTaskPublisher.Output {
        tryMap { output in
            guard let response = output.response as? HTTPURLResponse else {
                throw URLError(.unknown)
            }
            
            guard response.statusCode >= 200 && response.statusCode < 300 else {
                if let url = response.url {
                    throw URLError(
                        URLError.Code(
                            rawValue: response.statusCode
                        ),
                        userInfo: ["url": url]
                    )
                } else {
                    throw URLError(
                        URLError.Code(
                            rawValue: response.statusCode
                        )
                    )
                }
            }
            
            return output
        }
        .eraseToAnyPublisher()
    }
}
