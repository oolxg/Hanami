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
    @State var areChaptersShown = false

    var body: some View {
        WithViewStore(store) { viewStore in
            DisclosureGroup(isExpanded: $areChaptersShown) {
                LazyVStack {
                    ForEachStore(
                        store.scope(
                            state: \.chapterStates,
                            action: VolumeTabAction.chapterAction
                        )
                    ) { chapterState in
                        ChapterView(store: chapterState)
                    }
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
                    // if there a low of chapters in one volume, we should slowly show them,
                    // otherwise 10+ volumes will be shown 'w/o' animation(tooooo fast)
                    withAnimation(
                        .linear(
                            duration: max(Double(viewStore.chapterStates.count / 25), 0.6)
                        )
                    ) {
                        areChaptersShown.toggle()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .transition(.opacity)
            .padding(.vertical)
            .padding(.horizontal, 10)
            .animation(.linear, value: areChaptersShown)
            .frame(maxWidth: .infinity)
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
                environment: .live(
                    environment: .init()
                )
            )
        )
    }
}
