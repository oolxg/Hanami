//
//  Response.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation


// MARK: - MangaResponse
struct Response<ResponseData>: Codable, Equatable where ResponseData: Equatable, ResponseData: Codable {
    let result: String
    let response: `Type`
    let data: ResponseData
    
    enum `Type`: String, Codable {
        case collection, entity
    }
}
