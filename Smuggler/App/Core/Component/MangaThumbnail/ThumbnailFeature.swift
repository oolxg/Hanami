//
//  ThumbnailFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

struct MangaThumbnailState: Equatable, Identifiable {
    var manga: Manga
    var coverArtInfo: CoverArtInfo?
    
    var thumbnail: UIImage?
    
    var imageURL: URL? {
        guard let fileName = coverArtInfo?.attributes.fileName else {
            return nil
        }
        
        return URL(string: "https://uploads.mangadex.org/covers/\(manga.id.uuidString.lowercased())/\(fileName).256.jpg")
    }
    
    var id: UUID {
        manga.id
    }
}

enum MangaThumbnailAction: Equatable {
    case onAppear
    case thumbnailInfoLoaded(Result<Response<CoverArtInfo>, APIError>)
    case thumbnailLoaded(Result<UIImage?, APIError>)
}

struct MangaThumbnailEnvironment {
    var loadThumbnailInfo: (UUID?, JSONDecoder) -> Effect<Response<CoverArtInfo>, APIError>
    var loadThumbnail: (URL?) -> Effect<UIImage?, APIError>
}

let mangaThumbnailReducer = Reducer<MangaThumbnailState, MangaThumbnailAction, SystemEnvironment<MangaThumbnailEnvironment>> { state, action, env in
    switch action {
        case .onAppear:
            if let coverArtInfo = state.coverArtInfo,
               let image = LocalFileManager.shared.getImage(
                    withName: coverArtInfo.attributes.fileName,
                    from: state.manga.id.uuidString.lowercased()
               ) {
                state.thumbnail = image
                return .none
            }
            
            let coverArtID = state.manga.relationships.filter { $0.type == "cover_art" }.first?.id
            return env.loadThumbnailInfo(coverArtID, env.decoder())
                .receive(on: env.mainQueue())
                .catchToEffect()
                .map(MangaThumbnailAction.thumbnailInfoLoaded)
        case .thumbnailInfoLoaded(let result):
            switch result {
                case .success(let response):
                    state.coverArtInfo = response.data

                    return env.loadThumbnail(state.imageURL)
                        .receive(on: env.mainQueue())
                        .catchToEffect()
                        .map(MangaThumbnailAction.thumbnailLoaded)
                case .failure(let error):
                    return .none
            }
        case .thumbnailLoaded(let result):
            switch result {
                case .success(let image):
                    state.thumbnail = image
                    
                    if let image = image, let coverArtInfo = state.coverArtInfo {
                        LocalFileManager.shared.saveImage(
                            image: image,
                            withName: coverArtInfo.attributes.fileName,
                            inFolder: state.manga.id.uuidString.lowercased()
                        )
                    }
                    
                    return .none
                case .failure(let error):
                    return .none
            }
    }
}
