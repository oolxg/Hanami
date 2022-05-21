//
//  MangaView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct MangaView: View {
    let store: Store<MangaViewState, MangaViewAction>
    
    @State var isExpanded = false

    var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView {
                ForEach(viewStore.chaptersInfo.map(\.key).sorted(), id: \.self) { mangaChapterIndex in
                    ExpandableList(title: "Chapter \(mangaChapterIndex.clean):",
                                   items: viewStore.chaptersInfo[mangaChapterIndex]!) { chapterInfo in
                        ForEach(viewStore.chapterPages[mangaChapterIndex]!, id: \.self) { image in
                            if let image = image {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .scaledToFit()
                            }
                        }
                    }
                }
                Text(viewStore.manga.attributes.title.getAvailableName())
                Text(viewStore.chaptersInfo.count.description)
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onDisappear {
                viewStore.send(.onDisappear)
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
                reducer: mangaViewReducer,
                environment: .live(
                    environment: .init(
                        downloadChapters: downloadChaptersForManga,
                        downloadChapterPagesInfo: downloadPageInfoForChapter
                    )
                )
            )
        )
    }
}
