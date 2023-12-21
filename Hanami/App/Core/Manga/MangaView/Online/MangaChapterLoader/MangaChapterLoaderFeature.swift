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
import Logger
import SettingsClient

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

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .initLoader:
            return .run { [mangaID = state.manga.id] send in
                let settingsConfigResult = await settingsClient.retireveSettingsConfig()
                await send(.settingsConfigRetrieved(settingsConfigResult))
                
                let feedResult = await mangaClient.fetchFeed(forManga: mangaID, offset: 0)
                await send(.feedFetched(feedResult, currentOffset: 0))
            }
            
        case .settingsConfigRetrieved(let result):
            switch result {
            case .success(let config):
                state.prefferedLanguage = config.iso639Language.name
                return .none
                
            case .failure(let error):
                logger.error("Failed to retrieve config at MangaChapterLoaderFeature: \(error.description)")
                return .none
            }
                
        case .feedFetched(let result, let currentOffset):
            switch result {
            case .success(let response):
                state.chapters.append(contentsOf: response.data.asIdentifiedArray)
                
                if let total = response.total, total > currentOffset + 500 {
                    return .run { [mangaID = state.manga.id] send in
                        let result = await mangaClient.fetchFeed(forManga: mangaID, offset: currentOffset + 500)
                        await send(.feedFetched(result, currentOffset: currentOffset + 500))
                    }
                }
                
                return .none
                
            case .failure(let error):
                logger.error("Failed to fetch feed at MangaChapterLoaderFeature: \(error), offset: \(currentOffset)")
                return .none
            }
            
        case .prefferedLanguageChanged(let newLang):
            state.prefferedLanguage = newLang
            
            state.filteredChapters = state.chapters.filter {
                $0.attributes.translatedLanguage.map(ISO639Language.init)??.name == state.prefferedLanguage
            }
            
            return .none
            
        case .downloadButtonTapped(let chapter):
            logger.info("Starting downloading chapter \(chapter.chapterName) at MangaChapterLoaderFeature")
            return .none
        }
    }
}
