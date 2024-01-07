//
//  VolumeTabView.swift
//  Hanami
//
//  Created by Oleg on 26/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct VolumeTabView: View {
    let store: StoreOf<VolumeTabFeature>
    
    struct ViewState: Equatable {
        let volumeName: String
        let splitChapterIndexes: [[Int]]
        
        init(state: VolumeTabFeature.State) {
            volumeName = state.volume.volumeName
            // splitting chapter indexes as subsequences, e.g.
            // [1, 2, 3, 5, 9, 10] will be [[1, 2, 3], [5], [9, 10]]
            splitChapterIndexes = state.childrenChapterIndexes.getAllSubsequences()
        }
    }

    var body: some View {
        Group {
            volumeHeader
            
            ForEachStore(
                store.scope(
                    state: \.chapterStates,
                    action: VolumeTabFeature.Action.chapterAction
                ),
                content: ChapterView.init
            )
            .padding(.leading, 5)
        }
        .padding(.leading, 10)
    }
}

extension VolumeTabView {
    private var volumeHeader: some View {
        WithViewStore(store, observe: \.volume.volumeName) { viewStore in
            VStack {
                HStack {
                    Text(viewStore.state)
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
        }
    }
    
    private var chapterIndexesList: some View {
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
