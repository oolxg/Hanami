//
//  DownloadsView.swift
//  Smuggler
//
//  Created by mk.pwnz on 19/07/2022.
//

import SwiftUI
import ComposableArchitecture

struct DownloadsView: View {
    let store: Store<DownloadsState, DownloadsAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            NavigationView {
                VStack {
                    ScrollView {
                        if !viewStore.hideThumbnails {
                            ForEachStore(
                                store.scope(
                                    state: \.cachedMangaThumbnailStates,
                                    action: DownloadsAction.cachedMangaThumbnailAction
                                )
                            ) { thumbnailViewStore in
                                MangaThumbnailView(store: thumbnailViewStore)
                                    .padding()
                            }
                        }
                    }
                    .transition(.opacity)
                }
                .navigationTitle("Downloads")
                .onAppear {
                    print("on appear")
                    viewStore.send(.onAppear)
                }
            }
            .animation(.linear, value: viewStore.hideThumbnails)
        }
    }
}

struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadsView(
            store: .init(
                initialState: .init(),
                reducer: downloadsReducer,
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live
                )
            )
        )
    }
}
