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
    @State private var areChaptersShown = false

    var body: some View {
        WithViewStore(store.actionless) { viewStore in
            DisclosureGroup(isExpanded: $areChaptersShown) {
                ForEachStore(
                    store.scope(
                        state: \.chapterStates,
                        action: VolumeTabAction.chapterAction
                    )
                ) { chapterState in
                    ChapterView(store: chapterState)
                    
                    Divider()
                }
            } label: {
                HStack {
                    Text(viewStore.volume.volumeName)
                        .font(.title2)
                        .fontWeight(.heavy)
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
            .transition(.opacity)
            .padding(10)
            .animation(.linear, value: areChaptersShown)
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.theme.darkGray)
                .frame(height: 1.5)
                .padding(.leading, 50)
        }
    }
}

struct VolumeTabView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeTabView(
            store: .init(
                initialState: .init(
                    volume: .init(
                        dummyInit: true
                    )
                ),
                reducer: volumeTabReducer,
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live
                )
            )
        )
    }
}
