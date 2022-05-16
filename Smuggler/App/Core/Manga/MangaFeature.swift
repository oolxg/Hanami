//
//  MangaFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture

struct MangaState: Equatable {
    let manga: Manga
    var chaptersInfo: [Chapter] = []
}

enum MangaAction: Equatable {
    case onAppear
    case chaptersDownloaded(Result<Response<[Chapter]>, APIError>)
    case chapterPagesInfoDownloaded(Result<ChapterPagesInfo, APIError>)
}

struct MangaEnvironment {
    // Arguments for loadChaptersInfo - (id: UUID, chaptersCount: Int, offset: Int, decoder: JSONDecoder)
    var downloadChaptersInfo: (UUID, Int, Int, JSONDecoder) -> Effect<Response<[Chapter]>, APIError>
    var downloadChapterPageInfo: (UUID, Bool) -> Effect<ChapterPagesInfo, APIError>
}


let mangaReducer = Reducer<MangaState, MangaAction, SystemEnvironment<MangaEnvironment>> { state, action, env in
    switch action {
        case .onAppear:
            return env.downloadChaptersInfo(state.manga.id, 20, state.chaptersInfo.count, env.decoder())
                .receive(on: env.mainQueue())
                .catchToEffect(MangaAction.chaptersDownloaded)
        case .chaptersDownloaded(let result):
            switch result {
                case .success(let response):
                    response.data.forEach { chapter in
                        if !state.chaptersInfo.contains(chapter) {
                            state.chaptersInfo.append(chapter)
                        }
                    }
                    return .merge(
                        response.data.map { chapter in
                            env.downloadChapterPageInfo(chapter.id, false)
                                .receive(on: env.mainQueue())
                                .catchToEffect(MangaAction.chapterPagesInfoDownloaded)
                        }
                    )
                case .failure(let error):
                    return .none
            }
        case .chapterPagesInfoDownloaded(let result):
            switch result {
                case .success(let response):
                    // TODO: Store this data somehow
                    print(response.chapter)
                    return .none
                case .failure(let error):
                    return .none
            }
    }
}
