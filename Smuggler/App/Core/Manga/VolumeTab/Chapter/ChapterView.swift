//
//  ChapterView.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct ChapterView: View {
    let store: Store<ChapterState, ChapterAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ExpandableForEach(
                title: viewStore.chapter.chapterName,
                items: viewStore.chapterDetails.map(\.value)) { isListExpanded in
                    if isListExpanded {
                        viewStore.send(.listIsExpanded)
                    }
                } content: { (info: ChapterDetails) in
                    HStack {
                        Text(info.chapterName)
                    }
                }
        }
    }
}

struct ChapterView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterView(
            store: .init(
                initialState: ChapterState(chapter: dev.chapter),
                reducer: chapterReducer,
                environment: .live(
                    environment: .init(
                        downloadPagesInfo: downloadPageInfoForChapter,
                        downloadChapterInfo: downloadChapterInfo
                    )
                )
            )
        )
    }
}
