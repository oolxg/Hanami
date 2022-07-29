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
    @State private var showAwardWinning = false
    @State private var showMostFollowed = false

    var body: some View {
        NavigationView {
            WithViewStore(store.stateless) { viewStore in
                VStack {
                    Text("by oolxg")
                        .font(.caption2)
                        .frame(height: 0)
                        .foregroundColor(.black)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                            seasonal
                            
                            selections
                            
                            latestUpdates
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
                            MangaThumbnailView(store: thumbnailStore, compact: true)
                        }
                }
                .padding()
            }
            .frame(height: 170)
        } header: {
            makeSectionHeader(title: "Seasonal")
        }
    }
    
    private var selections: some View {
        Section {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 140, maximum: 500)),
                    GridItem(.flexible(minimum: 140, maximum: 500))
                ]) {
                    awardWinningNavLink
                    mostFollowedNavLink
                }
        } header: {
            makeSectionHeader(title: "Selections")
        }
    }
        
    private var latestUpdates: some View {
        Section {
            LazyVStack {
                ForEachStore(
                    store.scope(
                        state: \.lastUpdatedMangaThumbnailStates,
                        action: HomeAction.mangaThumbnailAction
                    )
                ) { thumbnailViewStore in
                    MangaThumbnailView(store: thumbnailViewStore)
                        .padding()
            }
            }
        } header: {
            makeSectionHeader(title: "Latest Updates")
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


// MARK: - Selections
extension HomeView {
    private var mostFollowedNavLink: some View {
        NavigationLink(isActive: $showMostFollowed) {
            mostFollowed
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.pink, .green, .yellow],
                            startPoint: .bottomLeading,
                            endPoint: .top
                        )
                    )
                    .zIndex(0)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Most")
                    Text("Followed")
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .font(.headline)
                .padding(.bottom, 10)
                .padding(.leading, 10)
                .zIndex(1)
            }
            .frame(height: 125)
            .padding(.trailing)
        }
    }
    
    private var mostFollowed: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Text("by oolxg")
                    .font(.caption2)
                    .frame(height: 0)
                    .foregroundColor(.black)
                
                ScrollView {
                    LazyVStack {
                        ForEachStore(
                            store.scope(
                                state: \.mostFollowedMangaThumbnailStates,
                                action: HomeAction.mostFollowedMangaThumbnailAction
                            )) { thumbnailStore in
                                MangaThumbnailView(store: thumbnailStore)
                                    .padding()
                            }
                    }
                    .navigationTitle("Award Winning")
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showMostFollowed = false
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(.vertical)
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewStore.send(.userOpenedMostFollowedView)
            }
        }
    }
    
    private var awardWinningNavLink: some View {
        NavigationLink(isActive: $showAwardWinning) {
            awardWinning
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.green, .blue, .yellow],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    .zIndex(0)
                
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Award")
                    Text("Winning")
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .font(.headline)
                .padding(.bottom, 10)
                .padding(.leading, 10)
                .zIndex(1)
            }
            .frame(height: 125)
            .padding(.leading)
        }
    }
    
    private var awardWinning: some View {
        WithViewStore(store.stateless) { viewStore in
            VStack {
                Text("by oolxg")
                    .font(.caption2)
                    .frame(height: 0)
                    .foregroundColor(.black)
                
                ScrollView {
                    LazyVStack {
                        ForEachStore(
                            store.scope(
                                state: \.awardWinningMangaThumbnailStates,
                                action: HomeAction.awardWinningMangaThumbnailAction
                            )) { thumbnailStore in
                                MangaThumbnailView(store: thumbnailStore)
                                    .padding()
                            }
                    }
                    .navigationTitle("Award Winning")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showAwardWinning = false
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(.vertical)
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewStore.send(.userOpenedAwardWinningView)
            }
        }
    }
}
