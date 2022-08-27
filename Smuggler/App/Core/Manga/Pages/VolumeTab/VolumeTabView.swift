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
    @State private var areChaptersShown = true

    var body: some View {
        WithViewStore(store.actionless) { viewStore in
            DisclosureGroup(isExpanded: $areChaptersShown) {
                VStack {
                    ForEachStore(
                        store.scope(state: \.chapterStates, action: VolumeTabAction.chapterAction),
                        content: ChapterView.init
                    )
                }
            } label: {
                HStack {
                    Text(viewStore.volume.volumeName)
                        .font(.title2)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        areChaptersShown.toggle()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(10)
            .animation(.linear, value: areChaptersShown)
        }
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
