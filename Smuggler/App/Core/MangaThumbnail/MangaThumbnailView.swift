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
                if let thumbnail = viewStore.thumbnail {
                    VStack(alignment: .center) {
                        Text(viewStore.manga.attributes.title.availableLang)
                        
                        NavigationLink(destination: MangaView(store: store.scope(state: \.mangaState, action: MangaThumbnailAction.mangaAction))) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                        }
                    }
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
                    manga: dev.manga
                ),
                reducer: mangaThumbnailReducer,
                environment: .live(
                    environment: .init(
                        loadThumbnailInfo: downloadThumbnailInfo
                    )
                )
            )
        )
    }
}

