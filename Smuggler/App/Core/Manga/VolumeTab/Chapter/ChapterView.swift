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
                LazyVStack(spacing: 0) {
                    ForEach(viewStore.chapterDetails) { chapter in
                        makeChapterView(chapter: chapter)
                        
                        Rectangle()
                            .fill(.white)
                            .frame(height: 1.5)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: viewStore.chapterDetails)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear {
                    viewStore.send(.onAppear)
                }
            } label: {
                Text(viewStore.chapter.chapterName)
                    .font(.title3)
                    .fontWeight(.heavy)
                    .padding(.vertical, 3)
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
    @ViewBuilder private func makeChapterView(chapter: ChapterDetails) -> some View {
        WithViewStore(store) { viewStore in
            HStack {
                VStack(alignment: .leading) {
                    Text(chapter.chapterName)
                        .fontWeight(.medium)
                        .font(.headline)
                        .lineLimit(nil)
                        .padding(5)
                    
                    if let scanlationGroupName = viewStore.scanlationGroups[chapter.id]?.name {
                        HStack {
                            Text("Translated by:")
                                .font(.caption)
                                .foregroundColor(.theme.secondaryText)

                            Text(scanlationGroupName)
                                .font(.caption)
                                .foregroundColor(.theme.secondaryText)
                        }
                        .padding(.horizontal, 5)
                        .padding(.bottom, 5)
                    }
                }
                
                Spacer()
            }
        }
        .padding(0)
    }
}
