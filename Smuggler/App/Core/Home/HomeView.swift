//
//  HomeView.swift
//  Smuggler
//
//  Created by mk.pwnz on 12/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: Store<HomeState, HomeAction>
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                VStack {
                    Text("by oolxg")
                        .font(.caption2)
                        .frame(height: 0)
                        .foregroundColor(.black)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders) {
                            seasonal
                            
                            other
                        }
                        .transition(.opacity)
                    }
                }
                .navigationTitle("Kamakura")
                .navigationBarTitleDisplayMode(.large)
                .onAppear {
                    viewStore.send(.onAppear)
                }
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            store: .init(
                initialState: HomeState(),
                reducer: homeReducer,
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live,
                    homeClient: .live,
                    cacheClient: .live
                )
            )
        )
    }
}

extension HomeView {
    private var seasonal: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 15) {
                    ForEachStore(
                        store.scope(
                            state: \.seasonalMangaThumbnailStates,
                            action: HomeAction.seasonalMangaThumbnailAction
                        )) { thumbnailStore in
                            OnlineMangaThumbnailView(store: thumbnailStore, compact: true)
                                .padding(.vertical)
                        }
                }
                .padding(.vertical)
            }
            .frame(height: 170)
        } header: {
            makeSectionHeader(title: "Seasonal")
        }
        .padding(.horizontal)
    }
    
    private var other: some View {
        Section {
            ForEachStore(
                store.scope(
                    state: \.mangaThumbnailStates,
                    action: HomeAction.mangaThumbnailAction
                )
            ) { thumbnailViewStore in
                OnlineMangaThumbnailView(store: thumbnailViewStore)
                    .padding()
            }
        } header: {
            makeSectionHeader(title: "Other")
        }
    }
    
    @ViewBuilder private func makeSectionHeader(title: String) -> some View {
        Text(title)
            .foregroundColor(.white)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.black, .black, .black, .clear], startPoint: .top, endPoint: .bottom)
            )
    }
}
