//
//  AuthorFeature.swift
//  Hanami
//
//  Created by Oleg on 20/10/2022.
//

import Foundation
import ComposableArchitecture

struct AuthorFeature: ReducerProtocol {
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
    
    // indirect because AuthorFeature is inside MangaFeauture
    // AuthorFeature -> MangaThumbnailFeature -> OnlineMangaFeature -> AuthorFeature -> MangaThumbnailFeature -> ...
    enum Action {
        case onAppear
        case authorInfoFetched(Result<Response<Author>, AppError>)
        case authorsMangaFetched(Result<Response<[Manga]>, AppError>)
        indirect case mangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    }
    
    @Dependency(\.homeClient) var homeClient
    @Dependency(\.mangaClient) var mangaClient
    @Dependency(\.logger) var logger
    @Dependency(\.mainQueue) var mainQueue

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.author.isNil else { return .none }
                
                return mangaClient.fetchAuthorByID(state.authorID)
                    .receive(on: mainQueue)
                    .catchToEffect(Action.authorInfoFetched)
                
            case .authorInfoFetched(let result):
                switch result {
                case .success(let response):
                    state.author = response.data
                    let mangaIDs = state.author!.mangaIDs

                    return .concatenate(
                        homeClient.fetchMangaByIDs(mangaIDs)
                            .receive(on: mainQueue)
                            .catchToEffect(Action.authorsMangaFetched),
                        
                        mangaClient.fetchStatistics(mangaIDs)
                            .receive(on: mainQueue)
                            .catchToEffect(Action.mangaStatisticsFetched)
                    )
                    
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
