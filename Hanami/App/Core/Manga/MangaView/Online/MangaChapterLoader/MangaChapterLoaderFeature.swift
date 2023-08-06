//
//  MangaChapterLoaderFeature.swift
//  Hanami
//
//  Created by Oleg on 19.03.23.
//

import Foundation
import ComposableArchitecture
import ModelKit
import Utils

struct MangaChapterLoaderFeature: Reducer {
    struct State: Equatable {
        let manga: Manga
        var chapters: IdentifiedArrayOf<ChapterDetails> = []
        // chapters filtered by selected langa
        var filteredChapters: IdentifiedArrayOf<ChapterDetails>?
        var allLanguages: [String] {
            chapters
                .compactMap(\.attributes.translatedLanguage)
                .compactMap(ISO639Language.init)
                .map(\.name)
                .removeDuplicates()
        }
        
        var prefferedLanguage: String?
    }
    
    enum Action {
        case initLoader
        case feedFetched(Result<Response<[ChapterDetails]>, AppError>, currentOffset: Int)
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case prefferedLanguageChanged(to: String?)
        case downloadButtonTapped(chapter: ChapterDetails)
    }
    
    @Dependency(\.mangaClient) private var mangaClient
    @Dependency(\.mainQueue) private var mainQueue
    @Dependency(\.logger) private var logger
    @Dependency(\.settingsClient) private var settingsClient

    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .initLoader:
            return .merge(
                mangaClient
                    .fetchMangaFeed(state.manga.id, 0)
                    .receive(on: mainQueue)
                    .catchToEffect { Action.feedFetched($0, currentOffset: 0) },
                
                settingsClient.retireveSettingsConfig()
                    .receive(on: mainQueue)
                    .catchToEffect(Action.settingsConfigRetrieved)
            )
            
        case let .settingsConfigRetrieved(result):
            switch result {
            case .success(let config):
                state.prefferedLanguage = config.iso639Language.name
                return .none
                
            case .failure(let error):
                logger.error("Failed to retrieve config at MangaChapterLoaderFeature: \(error.description)")
                return .none
            }
                
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
                logger.error("Failed to fetch feed at MangaChapterLoaderFeature: \(error), offset: \(currentOffset)")
                return .none
            }
            
        case let .prefferedLanguageChanged(newLang):
            state.prefferedLanguage = newLang
            
            state.filteredChapters = state.chapters.filter {
                $0.attributes.translatedLanguage.map(ISO639Language.init)??.name == state.prefferedLanguage
            }
            
            return .none
            
        case let .downloadButtonTapped(chapter):
            logger.info("Starting downloading chapter \(chapter.chapterName) at MangaChapterLoaderFeature")
            return .none
        }
    }
}
