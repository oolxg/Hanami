//
//  VolumeTabView.swift
//  Smuggler
//
//  Created by mk.pwnz on 26/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct VolumeTabView: View {
    let store: Store<VolumeTabState, VolumeTabAction>

    var body: some View {
        WithViewStore(store.actionless) { viewStore in
            VStack {
                HStack(alignment: .bottom) {
                    Text(viewStore.volume.volumeName)
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    chapterIndexesList
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
                    volume: .init(chapters: [], volumeIndex: 99999), isOnline: false
                ),
                reducer: volumeTabReducer,
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live,
                    cacheClient: .live
                )
            )
        )
    }
}

extension VolumeTabView {
    var chapterIndexesList: some View {
        WithViewStore(store) { viewStore in
            HStack {
                // splittin chapter indexes as subsequences, e.g.
                // [1, 2, 3, 5, 9, 10] will be [[1, 2, 3], [5], [9, 10]]
                let allSubsequences = viewStore.childrenChapterIndexes.getAllSubsequences()
                
                Text("Ch.")
                
                ForEach(allSubsequences, id: \.self) { subsequence in
                    let delimeter = subsequence == allSubsequences.last ? "" : ","
                    if subsequence.count == 1 {
                        Text("\(subsequence.first!)\(delimeter)")
                    } else {
                        let start = subsequence.first!.description
                        let end = subsequence.last!.description
                        
                        Text("\(start)-\(end)\(delimeter)")
                    }
                }
            }
            .lineLimit(1)
        }
    }
}
