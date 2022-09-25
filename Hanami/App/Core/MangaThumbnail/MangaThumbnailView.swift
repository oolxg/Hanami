//
//  MangaThumbnailView.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import SwiftUI
import ComposableArchitecture
import NukeUI

struct MangaThumbnailView: View {
    init(store: Store<MangaThumbnailState, MangaThumbnailAction>, compact: Bool = false) {
        self.store = store
        isCompact = compact
    }
    
    private let isCompact: Bool
    private let store: Store<MangaThumbnailState, MangaThumbnailAction>
    @State private var isNavigationLinkActive = false
    
    private struct ViewState: Equatable {
        let isOnline: Bool
        let manga: Manga
        let mangaStatistics: MangaStatistics?
        let coverArtURL: URL?
        
        init(state: MangaThumbnailState) {
            isOnline = state.isOnline
            manga = state.manga
            mangaStatistics = state.mangaStatistics
            coverArtURL = isOnline ? state.coverArtInfo?.coverArtURL256 : state.offlineMangaState?.coverArtPath
        }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            NavigationLink(
                isActive: $isNavigationLinkActive,
                destination: { LazyView(mangaView) },
                label: { EmptyView() }
            )
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.darkGray.opacity(0.6))

            HStack(alignment: .top) {
                coverArt

                textBlock
            }
            .padding(10)
        }
        .frame(width: isCompact ? 250 : nil, height: 150)
        .onTapGesture { isNavigationLinkActive.toggle() }
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
                environment: .init(
                    databaseClient: .live,
                    hapticClient: .live,
                    imageClient: .live,
                    cacheClient: .live,
                    mangaClient: .live,
                    hudClient: .live
                )
            ),
            compact: true
        )
    }
}

extension MangaThumbnailView {
    private var textBlock: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading, spacing: 10) {
                Text(viewStore.manga.title)
                    .lineLimit(2)
                    .foregroundColor(.white)
                    .font(.headline)
                
                if viewStore.isOnline {
                    statistics
                }
                
                if let mangaDescription = viewStore.manga.description {
                    Text(LocalizedStringKey(mangaDescription))
                        .lineLimit(5)
                        .foregroundColor(.white)
                        .font(.footnote)
                }
            }
            .onAppear { viewStore.send(.onAppear) }
            .onChange(of: isNavigationLinkActive) { isNavLinkActive in
                viewStore.send(isNavLinkActive ? .userOpenedMangaView : .userLeftMangaView)
            }
        }
    }
    
    @MainActor private var coverArt: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            LazyImage(url: viewStore.coverArtURL) { state in
                if let image = state.image {
                    image
                        .resizingMode(.aspectFill)
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if state.isLoading || state.error != nil {
                    Color.clear
                        .redacted(reason: .placeholder)
                        .frame(width: 100, height: 150)
                }
            }
        }
    }
    
    private var mangaView: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if viewStore.isOnline {
                OnlineMangaView(
                    store: store.scope(
                        state: \.onlineMangaState!,
                        action: MangaThumbnailAction.onlineMangaAction
                    )
                )
            } else {
                OfflineMangaView(
                    store: store.scope(
                        state: \.offlineMangaState!,
                        action: MangaThumbnailAction.offlineMangaAction
                    )
                )
            }
        }
    }
    
    private var statistics: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack(alignment: .top, spacing: 10) {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: "star.fill")

                    ZStack {
                        if let rating = viewStore.mangaStatistics?.rating {
                            Text(rating.average?.clean(accuracy: 2) ?? rating.bayesian.clean(accuracy: 2))
                        } else {
                            Text(String.placeholder(length: 3))
                                .redacted(reason: .placeholder)
                        }
                    }
                }
                
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: "bookmark.fill")

                    ZStack {
                        if let followsCount = viewStore.mangaStatistics?.follows.abbreviation {
                            Text(followsCount)
                        } else {
                            Text(String.placeholder(length: 7))
                                .redacted(reason: .placeholder)
                        }
                    }
                }
                
                if  !isCompact {
                    HStack(spacing: 5) {
                        let status = viewStore.manga.attributes.status
                        
                        Circle()
                            .fill(status.color)
                            .frame(width: 10, height: 10)
                            .padding(0)
                        
                        Text(status.rawValue.capitalized)
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }
            }
            .font(.footnote)
            .frame(height: 15)
        }
    }
}

extension MangaThumbnailView {
    static func skeleton(isCompact: Bool) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.theme.darkGray.opacity(0.6))
            
            HStack(alignment: .top) {
                skeletonCoverArt
                
                VStack(alignment: .leading, spacing: 10) {
                    // manga title
                    Text(String.placeholder(length: 20))
                        .lineLimit(3)
                        .foregroundColor(.white)
                        .font(.callout)
                        .redacted(reason: .placeholder)
                    
                    skeletonRating
                    
                    // description
                    VStack(alignment: .leading) {
                        Text(String.placeholder(length: AppUtil.isIpad ? 100 : 20))
                        Text(String.placeholder(length: AppUtil.isIpad ? 85 : 15))
                        Text(String.placeholder(length: AppUtil.isIpad ? 100 : 20))
                        Text(String.placeholder(length: AppUtil.isIpad ? 65 : 10))
                    }
                    .lineLimit(1)
                    .font(.footnote)
                    .redacted(reason: .placeholder)
                }
            }
            .padding(10)
        }
        .frame(width: isCompact ? 250 : nil, height: 150)
    }
    
    private static var skeletonCoverArt: some View {
        Color.black
            .opacity(0.45)
            .redacted(reason: .placeholder)
            .frame(width: 100, height: 150)
            .clipped()
            .cornerRadius(10)
    }
    
    private static var skeletonRating: some View {
        HStack {
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "star.fill")
                
                Text(String.placeholder(length: 3))
                    .redacted(reason: .placeholder)
            }
            
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "bookmark.fill")
                
                Text(String.placeholder(length: 7))
                    .redacted(reason: .placeholder)
            }
        }
        .font(.caption)
    }
}
