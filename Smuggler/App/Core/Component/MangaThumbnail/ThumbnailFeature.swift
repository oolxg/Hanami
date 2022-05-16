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
    init(manga: Manga, coverArtInfo: CoverArtInfo? = nil) {
        self.manga = manga
        self.mangaState = MangaState(manga: manga)
        self.coverArtInfo = coverArtInfo
    }
    var mangaState: MangaState
    var manga: Manga
    var coverArtInfo: CoverArtInfo?
    
    var thumbnail: UIImage?
    
    var thumbnailURL: URL? {
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
    case mangaAction(MangaAction)
}

struct MangaThumbnailEnvironment {
    var loadThumbnailInfo: (UUID, JSONDecoder) -> Effect<Response<CoverArtInfo>, APIError>
    var loadThumbnail: (URL?) -> Effect<UIImage?, APIError>
}

let mangaThumbnailReducer = Reducer<MangaThumbnailState, MangaThumbnailAction, SystemEnvironment<MangaThumbnailEnvironment>>.combine(
    mangaReducer.pullback(
        state: \.mangaState,
        action: /MangaThumbnailAction.mangaAction,
        environment: { _ in .live(
            environment: .init(
                downloadChaptersInfo: downloadChaptersForManga,
                downloadChapterPageInfo: downloadPageInfoForChapter
            )
        ) }
    ),
    Reducer { state, action, env in
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
                
                guard let coverArtID = state.manga.relationships.filter({ $0.type == .coverArt }).first?.id else {
                    return .none
                }
                
                return env.loadThumbnailInfo(coverArtID, env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(MangaThumbnailAction.thumbnailInfoLoaded)
            case .thumbnailInfoLoaded(let result):
                switch result {
                    case .success(let response):
                        state.coverArtInfo = response.data
                        
                        return env.loadThumbnail(state.thumbnailURL)
                            .receive(on: env.mainQueue())
                            .catchToEffect(MangaThumbnailAction.thumbnailLoaded)
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
            case .mangaAction(_):
                return .none
        }
    }
)
