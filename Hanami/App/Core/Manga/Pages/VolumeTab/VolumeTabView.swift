//
//  VolumeTabView.swift
//  Hanami
//
//  Created by Oleg on 26/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct VolumeTabView: View {
    let store: Store<VolumeTabState, VolumeTabAction>
    
    struct ViewState: Equatable {
        let volumeName: String
        let splitChapterIndexes: [[Int]]
        
        init(state: VolumeTabState) {
            volumeName = state.volume.volumeName
            // splitting chapter indexes as subsequences, e.g.
            // [1, 2, 3, 5, 9, 10] will be [[1, 2, 3], [5], [9, 10]]
            splitChapterIndexes = state.childrenChapterIndexes.getAllSubsequences()
        }
    }

    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack {
                HStack {
                    Text(viewStore.volumeName)
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    chapterIndexesList
                        .font(.headline)
                }
                
                Rectangle()
                    .frame(height: 1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 5)
            
            ForEachStore(
                store.scope(
                    state: \.chapterStates,
                    action: VolumeTabAction.chapterAction
                ),
                content: ChapterView.init
            )
            .padding(.leading, 5)
        }
        .padding(.leading, 10)
    }
}

struct VolumeTabView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeTabView(
            store: .init(
                initialState: .init(
                    volume: .init(chapters: [], volumeIndex: 99999), parentManga: dev.manga, online: false
                ),
                reducer: volumeTabReducer,
                environment: .init(
                    databaseClient: .live,
                    imageClient: .live,
                    cacheClient: .live,
                    mangaClient: .live,
                    hudClient: .live
                )
            )
        )
    }
}

extension VolumeTabView {
    var chapterIndexesList: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack {
                if !viewStore.splitChapterIndexes.isEmpty {
                    Text("Ch.")
                        .fontWeight(.light)

                    ForEach(viewStore.splitChapterIndexes, id: \.self) { subsequence in
                        let delimeter = subsequence == viewStore.splitChapterIndexes.last ? "" : ","
                        if subsequence.count == 1 {
                            Text("\(subsequence.first!)\(delimeter)")
                                .fontWeight(.light)
                        } else {
                            let start = subsequence.first!.description
                            let end = subsequence.last!.description
                            
                            Text("\(start)-\(end)\(delimeter)")
                                .fontWeight(.light)
                        }
                    }
                }
            }
            .lineLimit(1)
        }
    }
}
