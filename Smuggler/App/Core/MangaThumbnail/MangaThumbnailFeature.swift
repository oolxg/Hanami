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
    let manga: Manga
    var coverArtInfo: CoverArtInfo?
    var coverArt: UIImage? {
        mangaState.coverArt
    }
    
    var mangaStatistics: MangaStatistics? {
        mangaState.statistics
    }
    
    var id: UUID { manga.id }
    
    var coverArtURL: URL? {
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
    case userOpenedMangaView
    case userLeftMangaView
    case userLeftMangaViewDelayCompleted
    case mangaAction(MangaViewAction)
}

struct MangaThumbnailEnvironment {
    var loadThumbnailInfo: (UUID, JSONDecoder) -> Effect<Response<CoverArtInfo>, APIError>
}

// This struct is to cancel deletion cache manga info.
// This was put not in reducer because manga instance can be destroyed outside(e.g. destroyed in SearchView),
// so we must have an opportunity to cancel all cancellables outside too.
// This struct is in this file because user can switch to another tab, e.g. search, so .onDisappear() in MangaView will fire.
// It's better to control in from ThumbnailView, and because of it this struct here.
struct CancelClearCacheForManga: Hashable { let mangaID: UUID }

// swiftlint:disable:next line_length
let mangaThumbnailReducer = Reducer<MangaThumbnailState, MangaThumbnailAction, SystemEnvironment<MangaThumbnailEnvironment>>.combine(
    // swiftlint:disable:next trailing_closure
    mangaViewReducer.pullback(
        state: \.mangaState,
        action: /MangaThumbnailAction.mangaAction,
        environment: { _ in .live(
            environment: .init(
                fetchMangaVolumes: fetchChaptersForManga,
                fetchMangaStatistics: fetchMangaStatistics
            )
        ) }
    ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                // if we already loaded info about cover and cover, we don't need to do it one more time
                guard state.coverArtInfo == nil && state.coverArt == nil else { return .none }
                
                // if we have only cover info loaded, we load the image, otherwise we load all
                if state.coverArtInfo != nil && state.coverArt == nil {
                    return env.downloadImage(state.coverArtURL)
                        .receive(on: env.mainQueue())
                        .catchToEffect(MangaThumbnailAction.thumbnailLoaded)
                }
                
                guard let coverArtID = state.manga.relationships.first(where: { $0.type == .coverArt })?.id else {
                    return .none
                }
                
                return env.loadThumbnailInfo(coverArtID, env.decoder())
                    .catchToEffect(MangaThumbnailAction.thumbnailInfoLoaded)
                
            case .thumbnailInfoLoaded(let result):
                switch result {
                    case .success(let response):
                        state.coverArtInfo = response.data
                        // if we already loaded this thumbnail, we shouldn't load it one more time
                        if let coverArt = ImageFileManager.shared.getImage(
                            withName: state.coverArtInfo!.attributes.fileName,
                            from: state.manga.mangaFolderName
                           ) {
                            state.mangaState.coverArt = coverArt
                            return .none
                        }
                        
                        return env.downloadImage(state.coverArtURL)
                            .receive(on: env.mainQueue())
                            .catchToEffect(MangaThumbnailAction.thumbnailLoaded)
                        
                    case .failure(let error):
                        print("error on downloading thumbnail info: \(error)")
                        return .none
                }
                
            case .thumbnailLoaded(let result):
                switch result {
                    case .success(let returnedCoverArt):
                        state.mangaState.coverArt = returnedCoverArt
                        
                        ImageFileManager.shared.saveImage(
                            image: returnedCoverArt,
                            withName: state.coverArtInfo!.attributes.fileName,
                            inFolder: state.manga.mangaFolderName
                        )
                        
                        return .none
                    case .failure(let error):
                        print("error on downloading thumbnail: \(error)")
                        return .none
                }
                
            case .userOpenedMangaView:
                // when users enters the view, we must cancel clearing manga info
                return .cancel(id: CancelClearCacheForManga(mangaID: state.manga.id))
                
            case .userLeftMangaView:
                // Runs a delay(60 sec.) when user leaves MangaView, after that all downloaded data will be deleted to save RAM
                // Can be cancelled if user returns wihing 60 sec.
                return Effect(value: MangaThumbnailAction.userLeftMangaViewDelayCompleted)
                    .delay(for: .seconds(60), scheduler: env.mainQueue())
                    .eraseToEffect()
                    .cancellable(id: CancelClearCacheForManga(mangaID: state.manga.id))
                
            case .userLeftMangaViewDelayCompleted:
                state.mangaState.reset()
                return .none
                
            case .mangaAction:
                return .none
        }
    }
)
