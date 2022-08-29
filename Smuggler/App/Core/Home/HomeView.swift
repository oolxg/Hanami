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
    @State private var showHighestRating = false
    @State private var showRecentlyAdded = false

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
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .toolbar { toolbar }
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
                    cacheClient: .live,
                    imageClient: .live,
                    hudClient: .live,
                    hapticClient: .live
                )
            )
        )
    }
}

extension HomeView {
    private var toolbar: some ToolbarContent {
        WithViewStore(store.scope(state: \.isRefreshActionInProgress)) { viewStore in
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewStore.send(.refresh, animation: .linear(duration: 1.5))
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .font(.title3)
                        .rotationEffect(
                            Angle(degrees: viewStore.state ? 360 : 0),
                            anchor: .center
                        )
                }
            }
        }
    }
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
            .padding(.bottom)
        } header: {
            makeSectionHeader(title: "Seasonal")
        }
    }
    
    private var selections: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 140, maximum: 1000)),
                GridItem(.flexible(minimum: 140, maximum: 1000))
            ]
        ) {
            awardWinningNavLink
            mostFollowedNavLink
            
            highestRatingNavLink
            recentlyAddedNavLink
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


// MARK: - Most Followed
extension HomeView {
    private var mostFollowedNavLink: some View {
        NavigationLink(isActive: $showMostFollowed) {
            mostFollowed
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.pink, .blue],
                            startPoint: .bottomLeading,
                            endPoint: .top
                        ),
                        lineWidth: 4
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
                                state: \.mostFollowedMangaThumbnailStates,
                                action: HomeAction.mostFollowedMangaThumbnailAction
                            )) { thumbnailStore in
                                MangaThumbnailView(store: thumbnailStore)
                                    .padding()
                            }
                    }
                }
            }
            .navigationTitle("Most Followed")
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbar { showMostFollowed = false }
            }
            .onAppear {
                viewStore.send(.userOpenedMostFollowedView)
            }
        }
    }
}

// MARK: - Award Winning
extension HomeView {
    private var awardWinningNavLink: some View {
        NavigationLink(isActive: $showAwardWinning) {
            awardWinning
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.pink, .blue],
                            startPoint: .bottomLeading,
                            endPoint: .top
                        ),
                        lineWidth: 4
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
                }
            }
            .navigationTitle("Award Winning")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                toolbar { showAwardWinning = false }
            }
            .onAppear {
                viewStore.send(.userOpenedAwardWinningView)
            }
        }
    }
}

// MARK: - Highest Rating
extension HomeView {
    private var highestRatingNavLink: some View {
        NavigationLink(isActive: $showHighestRating) {
            highestRating
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.pink, .blue],
                            startPoint: .bottomLeading,
                            endPoint: .top
                        ),
                        lineWidth: 4
                    )
                    .zIndex(0)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Highest")
                    Text("Rating")
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
    
    private var highestRating: some View {
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
                                state: \.highestRatingMangaThumbnailStates,
                                action: HomeAction.highestRatingMangaThumbnailAction
                            )) { thumbnailStore in
                                MangaThumbnailView(store: thumbnailStore)
                                    .padding()
                            }
                    }
                }
            }
            .navigationTitle("Highest Rating")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                toolbar { showHighestRating = false }
            }
            .onAppear {
                viewStore.send(.userOpenedHighestRatingView)
            }
        }
    }
}

// MARK: - Recebtly Added
extension HomeView {
    private var recentlyAddedNavLink: some View {
        NavigationLink(isActive: $showRecentlyAdded) {
            recentlyAdded
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.pink, .blue],
                            startPoint: .bottomLeading,
                            endPoint: .top
                        ),
                        lineWidth: 4
                    )
                    .zIndex(0)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recently")
                    Text("Added")
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
    
    private var recentlyAdded: some View {
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
                                state: \.recentlyAddedMangaThumbnailStates,
                                action: HomeAction.recentlyAddedMangaThumbnailAction
                            )) { thumbnailStore in
                                MangaThumbnailView(store: thumbnailStore)
                                    .padding()
                            }
                    }
                }
            }
            .navigationTitle("Recently Added")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                toolbar { showRecentlyAdded = false }
            }
            .onAppear {
                viewStore.send(.userOpenedRecentlyAdded)
            }
        }
    }
    
    private func toolbar(_ action: @escaping () -> Void) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                action()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.vertical)
            }
        }
    }
}
