//
//  MangaThumbnailView.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct MangaThumbnailView: View {
    let store: Store<MangaThumbnailState, MangaThumbnailAction>
    @State private var isNavigationLinkActive = false
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.theme.darkGray)
                
                HStack(alignment: .top) {
                    coverArt
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewStore.manga.title)
                            .lineLimit(2)
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        statistics
                            
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
                environment: .live(
                    environment: .init(
                        loadThumbnailInfo: downloadThumbnailInfo
                    )
                )
            )
        )
    }
}

extension MangaThumbnailView {
    // all the stuff here is to make NavigationLink 'lazy'
    private var coverArt: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                if let coverArt = viewStore.coverArt {
                    Image(uiImage: coverArt)
                        .resizable()
                        .scaledToFill()
                        .background(
                            NavigationLink(
                                isActive: $isNavigationLinkActive,
                                destination: { navigationLinkDestination },
                                label: { EmptyView() }
                            )
                        )
                        .onChange(of: isNavigationLinkActive) { isNavLinkActive in
                            viewStore.send(isNavLinkActive ? .userOpenedMangaView : .userLeftMangaView)
                        }
                } else {
                    Color.black
                        .opacity(0.45)
                        .redacted(reason: .placeholder)
                }
            }
        }
        .frame(width: 100, height: 150)
        .clipped()
        .cornerRadius(10)
    }
    
    private var navigationLinkDestination: some View {
        ZStack {
            if isNavigationLinkActive {
                MangaView(
                    store: store.scope(
                        state: \.mangaState,
                        action: MangaThumbnailAction.mangaAction
                    )
                )
            }
        }
    }
    
    private var statistics: some View {
        WithViewStore(store) { viewStore in
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
            }
            .font(.footnote)
        }
    }
}
