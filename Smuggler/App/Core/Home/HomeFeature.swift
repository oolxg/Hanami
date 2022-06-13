//
//  HomeFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation
import ComposableArchitecture

struct HomeState: Equatable {
    var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
}

enum HomeAction {
    case onAppear
    case refresh
    case dataLoaded(Result<Response<[Manga]>, APIError>)
    case mangaThumbnailAction(id: UUID, action: MangaThumbnailAction)
}

struct HomeEnvironment {
    var loadHomePage: (JSONDecoder) -> Effect<Response<[Manga]>, APIError>
}

let homeReducer = Reducer<HomeState, HomeAction, SystemEnvironment<HomeEnvironment>>.combine(
    // swiftlint:disable:next trailing_closure
    mangaThumbnailReducer
        .forEach(
            state: \.mangaThumbnailStates,
            action: /HomeAction.mangaThumbnailAction,
            environment: { _ in .live(
                environment: .init(
                    loadThumbnailInfo: downloadThumbnailInfo
                ),
                isMainQueueAnimated: false
            ) }
        ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                if !state.mangaThumbnailStates.isEmpty { return .none }
                
                return env.loadHomePage(env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(HomeAction.dataLoaded)
                
            case .refresh:
                state.mangaThumbnailStates = []
                return env.loadHomePage(env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect(HomeAction.dataLoaded)
                
            case .dataLoaded(let result):
                switch result {
                    case .success(let response):
                        state.mangaThumbnailStates = .init(
                            uniqueElements: response.data.map { MangaThumbnailState(manga: $0) }
                        )
                    case .failure(let error):
                        print("error on downloading home page: \(error)")
                }
                return .none
                
            case .mangaThumbnailAction:
                return .none
        }
    }
)
