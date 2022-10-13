//
//  Response.swift
//  Hanami
//
//  Created by Oleg on 13/05/2022.
//

import Foundation

struct Response<ResponseData>: Codable, Equatable where ResponseData: Equatable & Codable {
    let result: String
    let response: `Type`
    let data: ResponseData
    let limit: Int?
    let total: Int?
    
    enum `Type`: String, Codable {
        case collection, entity
    }
}