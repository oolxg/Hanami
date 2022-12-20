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
    let blurRadius: CGFloat
    
    private struct ViewState: Equatable {
        let cachedMangaCount: Int
        let currentSortOrder: DownloadsFeature.SortOrder
        
        init(state: DownloadsFeature.State) {
            cachedMangaCount = state.cachedMangaThumbnailStates.count
            currentSortOrder = state.currentSortOrder
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
                                MangaThumbnailView(
                                    store: thumbnailViewStore,
                                    blurRadius: blurRadius
                                )
                                .padding(5)
                            }
                        }
                        .transition(.opacity)
                        .animation(.linear, value: viewStore.cachedMangaCount)
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar(content: toolbar)
        }
    }
}

#if DEBUG
struct DownloadsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadsView(
            store: .init(
                initialState: DownloadsFeature.State(),
                reducer: DownloadsFeature()._printChanges()
            ),
            blurRadius: 0
        )
    }
}
#endif

extension DownloadsView {
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            WithViewStore(store, observe: ViewState.init) { viewStore in
                Menu {
                    ForEach(DownloadsFeature.SortOrder.allCases, id: \.self) { sortOrder in
                        if viewStore.currentSortOrder == sortOrder {
                            Button {
                                viewStore.send(.sortOrderChanged(sortOrder))
                            } label: {
                                Label(sortOrder.rawValue, systemImage: "checkmark")
                            }
                        } else {
                            Button(sortOrder.rawValue) {
                                viewStore.send(.sortOrderChanged(sortOrder))
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .accentColor(.theme.foreground)
                }
            }
        }
    }
}
