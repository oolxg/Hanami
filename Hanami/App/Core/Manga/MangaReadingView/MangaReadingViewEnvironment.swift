//
//  MangaReadingViewFeature.swift
//  Hanami
//
//  Created by Oleg on 16/06/2022.
//

import Foundation


struct MangaReadingViewEnvironment {
    let databaseClient: DatabaseClient
    let cacheClient: CacheClient
    let imageClient: ImageClient
    let mangaClient: MangaClient
    let hudClient: HUDClient
}
