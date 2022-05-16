//
//  MangaView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct MangaView: View {
    let store: Store<MangaState, MangaAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            Text(viewStore.chaptersInfo.count.description)
                .onAppear {
                    viewStore.send(.onAppear)
                }
        }
    }
}

struct MangaView_Previews: PreviewProvider {
    static var previews: some View {
        MangaView(
            store: .init(
                initialState: .init(
                    manga: dev.manga
                ),
                reducer: mangaReducer,
                environment: .live(
                    environment: .init(
                        downloadChaptersInfo: downloadChaptersForManga,
                        downloadChapterPageInfo: downloadPageInfoForChapter
                    )
                )
            )
        )
    }
}
