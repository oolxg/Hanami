//
//  ThumbnailFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import ComposableArchitecture

struct MangaThumbnailState: Equatable, Identifiable {
    var manga: Manga
    var coverArt: CoverArt?
    
    var imageURL: URL {
        URL(string: "https://uploads.mangadex.org/covers/\(manga.id.uuidString)/\(String(describing: coverArt?.id))")!
    }
    
    var id: UUID {
        manga.id
    }
}

enum MangaThumbnailAction: Equatable {
    case onAppear
    case thumbnailLoaded(Result<Response<CoverArt>, APIError>)
}

struct MangaThumbnailEnvironment {
    var loadThumbnail: (UUID?, JSONDecoder) -> Effect<Response<CoverArt>, APIError>
}

let mangaThumbnailReducer = Reducer<MangaThumbnailState, MangaThumbnailAction, SystemEnvironment<MangaThumbnailEnvironment>> { state, action, env in
    switch action {
        case .onAppear:
            return env.loadThumbnail(state.manga.relationships.filter { $0.type == "cover_art" }.first?.id, env.decoder())
                .receive(on: env.mainQueue())
                .catchToEffect()
                .map(MangaThumbnailAction.thumbnailLoaded)
        case .thumbnailLoaded(let result):
            switch result {
                case .success(let response):
                    state.coverArt = response.data
                    break
                case .failure(let error):
                    break
            }
            return .none
    }
}
