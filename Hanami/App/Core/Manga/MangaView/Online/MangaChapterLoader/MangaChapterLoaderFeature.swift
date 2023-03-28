//
//  MangaChapterLoaderFeature.swift
//  Hanami
//
//  Created by Oleg on 19.03.23.
//

import Foundation
import ComposableArchitecture

struct MangaChapterLoaderFeature: ReducerProtocol {
    struct State: Equatable {
        let manga: Manga
        var chapters: IdentifiedArrayOf<ChapterDetails> = []
        var allLanguages: [String] {
            chapters.compactMap(\.attributes.translatedLanguage).removeDuplicates()
        }
        
        var prefferedLanguage: String?
    }
    
    enum Action {
        case startChapterFetching
        case feedFetched(Result<Response<[ChapterDetails]>, AppError>, currentOffset: Int)
        case prefferedLanguageChanged(newLang: String?)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.mainQueue) private var mainQueue

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .startChapterFetching:
            return mangaClient
                .fetchMangaFeed(state.manga.id, 0)
                .receive(on: mainQueue)
                .catchToEffect { Action.feedFetched($0, currentOffset: 0) }
            
        case let .feedFetched(result, currentOffset):
            switch result {
            case .success(let response):
                state.chapters.append(contentsOf: response.data.asIdentifiedArray)
                
                if let total = response.total, total > currentOffset + 500 {
                    return mangaClient
                        .fetchMangaFeed(state.manga.id, currentOffset + 500)
                        .receive(on: mainQueue)
                        .catchToEffect { Action.feedFetched($0, currentOffset: currentOffset + 500) }
                }
                
                return .none
                
            case .failure(let error):
                print(error)
                    
                return .none
            }
            
        case let .prefferedLanguageChanged(newLang):
            state.prefferedLanguage = newLang
            return .none
        }
    }
}
