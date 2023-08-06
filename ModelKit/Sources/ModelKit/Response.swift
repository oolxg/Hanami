//
//  Response.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation

public struct Response<ResponseData>: Decodable, Equatable where ResponseData: Equatable & Decodable {
    public let result: String
    public let response: `Type`
    public let data: ResponseData
    public let limit: Int?
    public let total: Int?
    
    public enum `Type`: String, Decodable {
        case collection, entity
    }
}
