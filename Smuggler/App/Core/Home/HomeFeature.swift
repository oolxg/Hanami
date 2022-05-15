    //
    //  HomeFeature.swift
    //  Smuggler
    //
    //  Created by mk.pwnz on 13/05/2022.
    //

import Foundation
import ComposableArchitecture

struct HomeState: Equatable {
    var downloadedManga: IdentifiedArrayOf<Manga> = []
    var mangaThumbnailStates: IdentifiedArrayOf<MangaThumbnailState> = []
}

enum HomeAction: Equatable {
    case onAppear
    case dataLoaded(Result<Response<[Manga]>, APIError>)
    case mangaThumbnailActon(id: UUID, action: MangaThumbnailAction)
}

struct HomeEnvironment {
    var loadHomePage: (JSONDecoder) -> Effect<Response<[Manga]>, APIError>
}

let homeReducer = Reducer<HomeState, HomeAction, SystemEnvironment<HomeEnvironment>>.combine(
    mangaThumbnailReducer
        .forEach(
            state: \.mangaThumbnailStates,
            action: /HomeAction.mangaThumbnailActon,
            environment: { _ in .live(environment: .init(loadThumbnail: downloadThumbnailInfo)) }
        ),
    Reducer { state, action, env in
        switch action {
            case .onAppear:
                return env.loadHomePage(env.decoder())
                    .receive(on: env.mainQueue())
                    .catchToEffect()
                    .map(HomeAction.dataLoaded)
            case .dataLoaded(let result):
                switch result {
                    case .success(let response):
                        state.downloadedManga = .init(uniqueElements: response.data)
                        state.mangaThumbnailStates = .init(uniqueElements: response.data.map { MangaThumbnailState(manga: $0) })
                    case .failure(let error):
                        break
                }
                return .none
                
            case .mangaThumbnailActon(id: _, action: _):
                return .none
        }
    })
