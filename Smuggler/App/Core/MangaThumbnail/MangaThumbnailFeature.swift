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
    
    init(manga: Manga) {
        self.manga = manga
        self.mangaState = MangaViewState(manga: manga)
    }
    
    var mangaState: MangaViewState
    var manga: Manga
    var coverArtInfo: CoverArtInfo? = nil
    var thumbnail: UIImage?
    var id: UUID {
        manga.id
    }
    
    var thumbnailURL: URL? {
        guard let fileName = coverArtInfo?.attributes.fileName else {
            return nil
        }
        
        return URL(string: "https://uploads.mangadex.org/covers/\(manga.id.uuidString.lowercased())/\(fileName).256.jpg")
    }
}

enum MangaThumbnailAction {
    case onAppear
    case thumbnailInfoLoaded(Result<Response<CoverArtInfo>, APIError>)
    case thumbnailLoaded(Result<UIImage, APIError>)
    case mangaAction(MangaViewAction)
}

struct MangaThumbnailEnvironment {
    var loadThumbnailInfo: (UUID, JSONDecoder) -> Effect<Response<CoverArtInfo>, APIError>
}

let mangaThumbnailReducer = Reducer<MangaThumbnailState, MangaThumbnailAction, SystemEnvironment<MangaThumbnailEnvironment>>.combine(
    mangaViewReducer.pullback(
        state: \.mangaState,
        action: /MangaThumbnailAction.mangaAction,
        environment: { _ in .live(
            environment: .init(
                downloadMangaVolumes: downloadChaptersForManga
            )
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
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
                        // if we already loaded this thumbnail, we shouldn't load it one more time
                        if let image = ImageFileManager.shared.getImage(
                            withName: state.coverArtInfo!.attributes.fileName,
                            from: state.manga.mangaFolderName
                           ) {
                            state.thumbnail = image
                            return .none
                        }
                        
                        return env.downloadImage(state.thumbnailURL)
                            .receive(on: env.mainQueue())
                            .catchToEffect(MangaThumbnailAction.thumbnailLoaded)
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error)")
                        return .none
                }
                
            case .thumbnailLoaded(let result):
                switch result {
                    case .success(let image):
                        state.thumbnail = image
                        if let coverArtInfo = state.coverArtInfo {
                            ImageFileManager.shared.saveImage(
                                image: image,
                                withName: coverArtInfo.attributes.fileName,
                                inFolder: state.manga.id.uuidString.lowercased()
                            )
                        }
                        
                        return .none
                    case .failure(let error):
                        print("error on downloading thumbnail: \(error)")
                        return .none
                }
                
            case .mangaAction(_):
                return .none
        }
    }
)
