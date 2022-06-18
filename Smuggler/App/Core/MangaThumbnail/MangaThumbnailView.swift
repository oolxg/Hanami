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
                        
                        if let statistics = viewStore.mangaStatistics {
                            HStack(alignment: .top, spacing: 10) {
                                HStack(alignment: .top, spacing: 0) {
                                    Image(systemName: "star.fill")
                                    
                                    Text(statistics.rating.average?.clean ?? statistics.rating.bayesian.clean)
                                }
                                
                                HStack(alignment: .top, spacing: 0) {
                                    Image(systemName: "bookmark.fill")
                                    
                                    Text(statistics.follows.abbreviation)
                                }
                            }
                            .font(.footnote)
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
            if let coverArt = viewStore.coverArt {
                Image(uiImage: coverArt)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 150)
                    .clipped()
                    .cornerRadius(10)
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
            }
        }
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
}
