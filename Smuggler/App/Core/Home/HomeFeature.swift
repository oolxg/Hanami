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
}

enum HomeAction: Equatable {
    case onAppear
    case dataLoaded(Result<Response<[Manga]>, APIError>)
    case mangaActon(id: UUID, action: MangaViewAction)
}

enum MangaViewAction: Equatable {
}


struct HomeEnvironment {
    var loadHomePage: (JSONDecoder) -> Effect<Response<[Manga]>, APIError>
    let decoder: () -> JSONDecoder
}

let homeReducer = Reducer<HomeState, HomeAction, SystemEnvironment<HomeEnvironment>> { state, action, env in
    switch action {
        case .onAppear:
            return env.loadHomePage(JSONDecoder())
                .receive(on: env.mainQueue())
                .catchToEffect()
                .map(HomeAction.dataLoaded)
        case .dataLoaded(let result):
            switch result {
                case .success(let response):
                    state.downloadedManga = .init(uniqueElements: response.data)
                case .failure(let error):
                    break
            }
            return .none
    }
}
