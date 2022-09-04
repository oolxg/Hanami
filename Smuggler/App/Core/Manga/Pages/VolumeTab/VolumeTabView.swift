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
                Text(viewStore.volume.volumeName)
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .frame(height: 1.5)
            }
            
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
