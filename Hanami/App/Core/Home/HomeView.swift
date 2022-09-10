//
//  HomeView.swift
//  Hanami
//
//  Created by Oleg on 12/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct HomeView: View {
    let store: Store<HomeState, HomeAction>
    @State private var showAwardWinning = false
    @State private var showMostFollowed = false
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    private struct ViewState: Equatable {
        let isRefreshActionInProgress: Bool
        let areSeasonalTitlesFetched: Bool
        let areLatestUpdatesFetched: Bool
        
        init(state: HomeState) {
            isRefreshActionInProgress = state.isRefreshActionInProgress
            areSeasonalTitlesFetched = !state.seasonalMangaThumbnailStates.isEmpty
            areLatestUpdatesFetched = !state.lastUpdatedMangaThumbnailStates.isEmpty
        }
    }

    var body: some View {
        if networkMonitor.isConnected {
            homeContent
        } else {
            noInternetConnectionView
        }
    }
    
    private var noInternetConnectionView: some View {
        VStack(alignment: .center, spacing: 15) {
            Image(systemName: "wifi.slash")
                .font(.title)
            
            Text("Looks like you're not connected to the internet")
                .font(.title.bold())
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var homeContent: some View {
        NavigationView {
            WithViewStore(store, observe: ViewState.init) { viewStore in
                VStack {
                    Text("by oolxg")
                        .font(.caption2)
                        .frame(height: 0)
                        .foregroundColor(.clear)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                            seasonal
                            
                            selections
                            
                            latestUpdates
                        }
                    }
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewStore.send(.refresh, animation: .linear(duration: 1.5))
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                                .font(.title3)
                                .rotationEffect(
                                    Angle(degrees: viewStore.isRefreshActionInProgress ? 360 : 0),
                                    anchor: .center
                                )
                        }
                    }
                }
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            store: .init(
                initialState: HomeState(),
                reducer: homeReducer,
                environment: .init(
                    databaseClient: .live,
                    hapticClient: .live,
                    cacheClient: .live,
                    imageClient: .live,
                    mangaClient: .live,
                    homeClient: .live,
                    hudClient: .live
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
                    WithViewStore(store, observe: ViewState.init) { viewStore in
                        if viewStore.areSeasonalTitlesFetched {
                            ForEachStore(
                                store.scope(
                                    state: \.seasonalMangaThumbnailStates,
                                    action: HomeAction.seasonalMangaThumbnailAction
                                )) { thumbnailStore in
                                    MangaThumbnailView(store: thumbnailStore, compact: true)
                                }
                        } else {
                            ForEach(0..<7) { _ in
                                MangaThumbnailView.skeleton(isCompact: true)
                            }
                        }
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
        }
    }
        
    private var latestUpdates: some View {
        Section {
            LazyVStack {
                WithViewStore(store, observe: ViewState.init) { viewStore in
                    if viewStore.areLatestUpdatesFetched {
                        ForEachStore(
                            store.scope(
                                state: \.lastUpdatedMangaThumbnailStates,
                                action: HomeAction.lastUpdatesMangaThumbnailAction
                            )
                        ) { thumbnailViewStore in
                            MangaThumbnailView(store: thumbnailViewStore)
                                .padding()
                        }
                    } else {
                        ForEach(0..<10) { _ in
                            MangaThumbnailView.skeleton(isCompact: false)
                                .padding()
                        }
                    }
                }
            }
        } header: {
            makeSectionHeader(title: "Latest Updates")
        }
    }
    
    @ViewBuilder private func makeSectionHeader(title: String) -> some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.theme.background, .theme.background, .theme.background, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
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
        VStack {
            Text("by oolxg")
                .font(.caption2)
                .frame(height: 0)
                .foregroundColor(.clear)

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
            ViewStore(store).send(.userOpenedMostFollowedView)
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
        VStack {
            Text("by oolxg")
                .font(.caption2)
                .frame(height: 0)
                .foregroundColor(.clear)

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
            ViewStore(store).send(.userOpenedMostFollowedView)
        }
    }
}
