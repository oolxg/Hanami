//
//  MangaThumbnailView.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct MangaThumbnailView: View {
    init(store: Store<MangaThumbnailState, MangaThumbnailAction>, compact: Bool = false) {
        self.store = store
        isCompact = compact
    }
    
    private let isCompact: Bool
    private let store: Store<MangaThumbnailState, MangaThumbnailAction>
    @State private var isNavigationLinkActive = false
    
    var body: some View {
        VStack {
            if isCompact {
                compactVersion
            } else {
                fullVersion
            }
        }
        .background(
            NavigationLink(
                isActive: $isNavigationLinkActive,
                destination: { mangaView },
                label: { EmptyView() }
            )
        )
    }
    
    private var coverArt: some View {
        WithViewStore(store.actionless) { viewStore in
            if viewStore.isOnline {
                KFImage.url(viewStore.coverArtInfo?.coverArtURL256)
                    .placeholder {
                        Color.black
                            .opacity(0.45)
                            .redacted(reason: .placeholder)
                    }
                    .backgroundDecode()
                    .fade(duration: 0.5)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 150)
                    .clipped()
                    .cornerRadius(10)
            } else {
                ZStack {
                    if let coverArt = viewStore.offlineMangaState?.coverArt {
                        Image(uiImage: coverArt)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.black
                            .opacity(0.45)
                            .redacted(reason: .placeholder)
                    }
                }
                .frame(width: 100, height: 150)
                .clipped()
                .cornerRadius(10)
            }
        }
    }
    
    private var mangaView: some View {
        WithViewStore(store.actionless) { viewStore in
            if viewStore.isOnline {
                IfLetStore(
                    store.scope(
                        state: \.onlineMangaState,
                        action: MangaThumbnailAction.onlineMangaAction
                    ),
                    then: OnlineMangaView.init
                )
            } else {
                IfLetStore(
                    store.scope(
                        state: \.offlineMangaState,
                        action: MangaThumbnailAction.offlineMangaAction
                    ),
                    then: OfflineMangaView.init
                )
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
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live,
                    cacheClient: .live,
                    imageClient: .live,
                    hudClient: .live,
                    hapticClient: .live
                )
            ),
            compact: true
        )
    }
}

// MARK: - Full version
extension MangaThumbnailView {
    private var fullVersion: some View {
        WithViewStore(store) { viewStore in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.darkGray.opacity(0.6))
                
                HStack(alignment: .top) {
                    coverArt
                    
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
                }
                .padding(10)
            }
            .frame(height: 150)
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onTapGesture {
                isNavigationLinkActive.toggle()
            }
            .onChange(of: isNavigationLinkActive) { isNavLinkActive in
                viewStore.send(isNavLinkActive ? .userOpenedMangaView : .userLeftMangaView)
            }
        }
    }
    
    private var statistics: some View {
        WithViewStore(store.actionless) { viewStore in
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
            .font(.footnote)
        }
    }
}

// MARK: - Compact
extension MangaThumbnailView {
    private var compactVersion: some View {
        WithViewStore(store) { viewStore in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.darkGray.opacity(0.6))
                
                HStack(alignment: .top) {
                    coverArt
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewStore.manga.title)
                            .lineLimit(3)
                            .foregroundColor(.white)
                            .font(.callout)
                        
                        HStack {
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
                        }
                        .font(.caption)
                        
                        if let mangaDescription = viewStore.manga.description {
                            Text(LocalizedStringKey(mangaDescription))
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 250, height: 150)
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onTapGesture {
                isNavigationLinkActive.toggle()
            }
            .onChange(of: isNavigationLinkActive) { isNavLinkActive in
                viewStore.send(isNavLinkActive ? .userOpenedMangaView : .userLeftMangaView)
            }
        }
    }
}
