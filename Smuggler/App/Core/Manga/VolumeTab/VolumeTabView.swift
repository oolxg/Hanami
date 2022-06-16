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
    @State var areVolumesShown = false

    var body: some View {
        WithViewStore(store) { viewStore in
            DisclosureGroup(isExpanded: $areVolumesShown) {
                ForEachStore(
                    store.scope(
                        state: \.chapterStates,
                        action: VolumeTabAction.chapterAction
                    )
                ) { chapterState in
                    ChapterView(store: chapterState)
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
                    withAnimation(.linear(duration: 0.7)) {
                        areVolumesShown.toggle()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
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
