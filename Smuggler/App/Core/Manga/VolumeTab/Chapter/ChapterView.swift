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
            DisclosureGroup {
                VStack {
                    ForEach(viewStore.chapterDetails.map(\.key)) { chapterID in
                        makeChapterView(chapterID: chapterID)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear {
                    viewStore.send(.onAppear)
                }
            } label: {
                Text(viewStore.chapter.chapterName)
                    .font(.title3)
                    .fontWeight(.heavy)
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .frame(maxWidth: .infinity)
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
                        downloadChapterInfo: downloadChapterInfo,
                        fetchScanlationGroupInfo: fetchScanlationGroupInfo
                    )
                )
            )
        )
    }
}

extension ChapterView {
    // swiftlint:disable force_unwrapping
    @ViewBuilder private func makeChapterView(chapterID: UUID) -> some View {
        WithViewStore(store) { viewStore in
            HStack {
                Text(viewStore.chapterDetails[chapterID]!.chapterName)
             
                Spacer()
            }
        }
    }
}
