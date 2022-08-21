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
        NavigationView {
            VStack {
                Text("by oolxg")
                    .font(.caption2)
                    .frame(height: 0)
                    .foregroundColor(.black)

                WithViewStore(store.actionless) { viewStore in
                    if viewStore.cachedMangaThumbnailStates.isEmpty {
                        Text("Wow, such empty here...")
                            .font(.title2)
                            .fontWeight(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
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
                        .transition(.opacity)
                        .animation(.linear, value: viewStore.cachedMangaThumbnailStates.count)
                    }
                }
            }
            .navigationTitle("Downloads")
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
                    mangaClient: .live,
                    cacheClient: .live,
                    imageClient: .live,
                    hudClient: .live,
                    hapticClient: .live
                )
            )
        )
    }
}
