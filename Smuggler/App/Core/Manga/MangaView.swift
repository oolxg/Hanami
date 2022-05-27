//
//  MangaView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct MangaView: View {
    let store: Store<MangaViewState, MangaViewAction>
    
    @State var isExpanded = false
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView {
                ForEachStore(store.scope(state: \.volumeTabStates, action: MangaViewAction.volumeTabAction)) { volumeStore in
                    VolumeTabView(store: volumeStore)
                    
                    Divider()
                }
                Text(viewStore.manga.id.uuidString.lowercased())
                Text(viewStore.manga.attributes.title.availableLang)
            }
            .onAppear {
                print(viewStore.manga.id.uuidString.lowercased())
                viewStore.send(.onAppear)
            }
            .onDisappear {
                viewStore.send(.onDisappear)
            }
            .navigationTitle(viewStore.manga.title)
        }
    }
}

struct MangaView_Previews: PreviewProvider {
    static var previews: some View {
        MangaView(
            store: .init(
                initialState: .init(
                    manga: dev.manga
                ),
                reducer: mangaViewReducer,
                environment: .live(
                    environment: .init(
                        downloadMangaVolumes: downloadChaptersForManga
                    )
                )
            )
        )
    }
}
