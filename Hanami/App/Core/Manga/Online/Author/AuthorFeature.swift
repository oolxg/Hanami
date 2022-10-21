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
        let author: Author
        var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailFeature.State> = []
        
        var id: UUID { author.id }
    }
    
    // indirect because AuthorFeature is inside MangaFeauture
    // AuthoreFeature -> MangaThumbnailFeature -> OnlineMangaFeature -> AuthorFeature -> MangaThumbnailFeature -> ...
    indirect enum Action {
        case onAppear
        case authorsMangaFetched(Result<Response<[Manga]>, AppError>)
        case mangaThumbnailAction(UUID, MangaThumbnailFeature.Action)
        case mangaStatisticsFetched(Result<MangaStatisticsContainer, AppError>)
    }
    
    @Dependency(\.homeClient) var homeClient
    @Dependency(\.logger) var logger
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
                case .onAppear:
                    let mangaIDs = state.author.relationships.filter { $0.type == .manga }.map(\.id)
                    return homeClient.fetchMangaByIDs(mangaIDs)
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(Action.authorsMangaFetched)
                    
                case .authorsMangaFetched(let result):
                    switch result {
                        case .success(let response):
                            state.mangaThumbnailStates = .init(
                                uniqueElements: response.data.map {
                                    MangaThumbnailFeature.State(manga: $0, online: true)
                                }
                            )
                            
                            let mangaIDs = response.data.map(\.id)
                            return homeClient.fetchStatistics(mangaIDs)
                                .receive(on: DispatchQueue.main)
                                .catchToEffect(Action.mangaStatisticsFetched)
                            
                        case .failure(let error):
                            logger.error(
                                "Failed to fetch authors manga: \(error)",
                                context: [
                                    "authorID": state.author.id.uuidString.lowercased()
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
