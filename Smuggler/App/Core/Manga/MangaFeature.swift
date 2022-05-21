//
//  MangaFeature.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI

// TODO: - Rewrite logic to make images load not for all available chapters
// Should extract Chapter as a separate component and load chapter info onTap/onSomeAction, after the chapter if opened, should load pages

struct MangaViewState: Equatable {
    let manga: Manga
    // Chapter Index(can be also e.g. `15.3`) - ChapterInfo
    var chaptersInfo: [Double: [Chapter]] = [:]
    // Chapter ID - ChapterPagesInfo
    var chapterPagesInfo: [UUID: ChapterPagesInfo] = [:]
    // Chapter Index - Images
    var chapterPages: [Double: [UIImage?]] = [:]
}

enum MangaViewAction: Equatable {
    case onAppear
    case onDisappear
    case chaptersDownloaded(Result<Response<[Chapter]>, APIError>)
    // UUID - for chapter ID, Int - chapter index in manga
    case chapterPagesInfoDownloaded(Result<ChapterPagesInfo, APIError>, UUID, Double)
    // Double - chapterIndex, String - imageFileName, Int - pageIndex
    case chapterPageDownloaded(Result<UIImage, APIError>, Double, String, Int)
}

struct MangaViewEnvironment {
    // Arguments for downloadChapters - (mangaID: UUID, chaptersCount: Int, offset: Int, decoder: JSONDecoder)
    var downloadChapters: (UUID, Int, Int, JSONDecoder) -> Effect<Response<[Chapter]>, APIError>
    // Arguments for downloadChapterPagesInfo - (chapterID: UUID, force443Port: Bool)
    var downloadChapterPagesInfo: (UUID, Bool) -> Effect<ChapterPagesInfo, APIError>
}


let mangaViewReducer = Reducer<MangaViewState, MangaViewAction, SystemEnvironment<MangaViewEnvironment>> { state, action, env in
    struct CancelPagesLoading: Hashable { }
    
    switch action {
        case .onAppear:
            return env.downloadChapters(state.manga.id, 20, state.chaptersInfo.count, env.decoder())
                .receive(on: env.mainQueue())
                .catchToEffect(MangaViewAction.chaptersDownloaded)
        case .onDisappear:
            state.chapterPagesInfo = [:]
            state.chaptersInfo = [:]
            
            return .cancel(id: CancelPagesLoading())
        case .chaptersDownloaded(let result):
            switch result {
                case .success(let response):
                    var effects: [Effect<MangaViewAction, Never>] = []
                    for chapterInfo in response.data {
                        // if manga has no `chapter` property, we don't know where it belongs to, so we should drop it
                        if let chapterIndex = chapterInfo.attributes.chapterIndex {
                            
                            effects.append(
                                env.downloadChapterPagesInfo(chapterInfo.id, false)
                                    .receive(on: env.mainQueue())
                                    .catchToEffect { MangaViewAction.chapterPagesInfoDownloaded($0, chapterInfo.id, chapterIndex) }
                            )
                            if state.chaptersInfo.contains(where: { $0.key == chapterIndex }) {
                                state.chaptersInfo[chapterIndex]!.append(chapterInfo)
                            } else {
                                state.chaptersInfo[chapterIndex] = [chapterInfo]
                            }
                        }
                    }
                    
                    return .merge(effects)
                case .failure(let error):
                    print("error on chaptersDownloaded")
                    return .none
            }
        case .chapterPagesInfoDownloaded(let result, let chapterID, let chapterIndex):
            switch result {
                case .success(let chapterPagesInfo):
                    state.chapterPagesInfo[chapterID] = chapterPagesInfo
                    
                    var effects: [Effect<MangaViewAction, Never>] = []
                    
                    // reserving enough space to store pages in appropriate order, not to use `.append(page)`
                    state.chapterPages[chapterIndex] = []
                    state.chapterPages[chapterIndex]?.resize(chapterPagesInfo.chapter.dataSaver.count, fillWith: nil)
                    
                    for (imageIndex, imageFileName) in chapterPagesInfo.chapter.dataSaver.enumerated() {
                        if let image = ImageFileManager.shared.getImage(withName: imageFileName, from: state.manga.mangaFolderName, folderType: .cachesDirectory) {
                            state.chapterPages[chapterIndex]![imageIndex] = image
                            continue
                        }
                        
                        let qualityMode = "data-saver"
                        effects.append(
                            env.downloadImage(URL(string: "\(chapterPagesInfo.baseURL)/\(qualityMode)/\(chapterPagesInfo.chapter.hash)/\(imageFileName)"))
                                .receive(on: env.mainQueue())
                                .catchToEffect {
                                    MangaViewAction.chapterPageDownloaded($0, chapterIndex, imageFileName, imageIndex)
                                }
                        )
                    }
                    
                    return .merge(effects)
                        .cancellable(id: CancelPagesLoading(), cancelInFlight: true)
                case .failure(let error):
                    print("error on chapterPagesInfoDownloaded")
                    return .none
            }
        case .chapterPageDownloaded(let result, let chapterIndex, let imageName, let imageIndex):
            // TODO: Rewrite this stuff to make images not be stored in RAM
            switch result {
                case .success(let image):
                    if state.chapterPages.contains(where: { $0.key == chapterIndex }) {
                        state.chapterPages[chapterIndex]![imageIndex] = image
                    } else {
                        print("didn't find `chapterIndex` in state.chapterPages")
                    }
                    
                                        
                    ImageFileManager.shared.saveImage(
                        image: image,
                        withName: imageName,
                        inFolder: state.manga.mangaFolderName,
                        folderType: .cachesDirectory
                    )
                    
                    return .none
                case .failure(let error):
                    print("error on chapterPageDownloaded")
                    return .none
                    
            }
    }
}
