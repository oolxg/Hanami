//
//  DownloadsView.swift
//  Hanami
//
//  Created by Oleg on 19/07/2022.
//

import SwiftUI
import ComposableArchitecture

struct DownloadsView: View {
    let store: StoreOf<DownloadsFeature>
    
    private struct ViewState: Equatable {
        let cachedMangaCount: Int
        
        init(state: DownloadsFeature.State) {
            cachedMangaCount = state.cachedMangaThumbnailStates.count
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text("by oolxg")
                    .font(.caption2)
                    .frame(height: 0)
                    .foregroundColor(.clear)

                WithViewStore(store, observe: ViewState.init) { viewStore in
                    if viewStore.cachedMangaCount == 0 {
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
                                    action: DownloadsFeature.Action.cachedMangaThumbnailAction
                                )
                            ) { thumbnailViewStore in
                                MangaThumbnailView(store: thumbnailViewStore)
                                    .padding(5)
                            }
                        }
                        .transition(.opacity)
                        .animation(.linear, value: viewStore.cachedMangaCount)
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
                initialState: DownloadsFeature.State(),
                reducer: DownloadsFeature()._printChanges()
            )
        )
    }
}
