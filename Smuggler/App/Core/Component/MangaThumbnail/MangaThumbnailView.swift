//
//  MangaThumbnailView.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct MangaThumbnailView: View {
    let store: Store<MangaThumbnailState, MangaThumbnailAction>
    
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Text(viewStore.coverArt?.id.uuidString ?? "none")
                    .padding()
                if viewStore.coverArt == nil {
                    Text(viewStore.manga.relationships.filter { $0.type == "cover_art" }.first?.id.uuidString ?? "not defined")
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

struct MangaThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        MangaThumbnailView(
            store: .init(
                initialState: .init(
                    manga: dev.manga,
                    coverArt: dev.coverArt
            ),
                 reducer: mangaThumbnailReducer,
                environment: .live(
                    environment: .init(loadThumbnail: downloadThumbnailInfo)
                )
            )
        )
    }
}
