//
//  AuthorFeature.swift
//  Hanami
//
//  Created by Oleg on 20/10/2022.
//

import Foundation
import ComposableArchitecture
@preconcurrency
import ModelKit
import Utils
import Logger

@Reducer
struct AuthorFeature {
    struct State: Equatable, Identifiable {
        var author: Author?
        var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        let authorID: UUID
        
        var id: UUID {
            authorID
        }
        
        init(authorID: UUID) {
            self.authorID = authorID
        }
    }
    
    enum Action: Sendable {
        case onAppear
        case authorInfoFetched(Result<Response<Author>, AppError>)
        case authorsMangaFetched(Result<Response<[Manga]>, AppError>)
        indirect case mangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    }
    
    @Dependency(\.homeClient) var homeClient
    @Dependency(\.mangaClient) var mangaClient
    @Dependency(\.logger) var logger

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.author.isNil else { return .none }
                
                return .run { [authorID = state.authorID] send in
                    let result = await mangaClient.fetchAuthor(authorID: authorID)
                    await send(.authorInfoFetched(result))
                }
                
            case .authorInfoFetched(let result):
                switch result {
                case .success(let response):
                    state.author = response.data
                    let mangaIDs = state.author!.mangaIDs
                    
                    return .run { send in
                        let mangaFetchResult = await homeClient.fetchManga(ids: mangaIDs)
                        await send(.authorsMangaFetched(mangaFetchResult))
                        
                        let statisticsFetchResult = await mangaClient.fetchStatistics(for: mangaIDs)
                        await send(.mangaStatisticsFetched(statisticsFetchResult))
                    }
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch Author info: \(error)",
                        context: [
                            "authorID": state.authorID.uuidString.lowercased()
                        ]
                    )
                    return .none
                }
                
            case .authorsMangaFetched(let result):
                switch result {
                case .success(let response):
                    state.mangaThumbnailStates = response.data
                        .map { MangaThumbnailFeature.State(manga: $0, online: true) }
                        .asIdentifiedArray
                    
                    return .none
                    
                case .failure(let error):
                    logger.error(
                        "Failed to fetch authors manga: \(error)",
                        context: [
                            "authorID": state.authorID.uuidString.lowercased()
                        ]
                    )
                    
                    return .none
                }
                
            case .mangaStatisticsFetched(let result):
                switch result {
                case .success(let response):
                    for stat in response.statistics {
                        state.mangaThumbnailStates[id: stat.key]?.onlineMangaState!.statistics = stat.value
                    }
                    
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to load statistics for found titles: \(error)")
                    return .none
                }
                
            case .mangaThumbnailAction:
                return .none
            }
        }
        .forEach(\.mangaThumbnailStates, action: /Action.mangaThumbnailAction) {
            MangaThumbnailFeature()
        }
    }
}
