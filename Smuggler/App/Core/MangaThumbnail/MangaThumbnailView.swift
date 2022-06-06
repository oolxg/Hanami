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
            VStack(alignment: .center) {
                Text(viewStore.manga.title)
                    
                navigationLink
            }
            .onAppear {
                viewStore.send(.onAppear)
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
    private var navigationLink: some View {
        WithViewStore(store) { viewStore in
            if let thumbnail = viewStore.coverArt {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .background(
                        NavigationLink(
                            isActive: $isNavigationLinkActive,
                            destination: { navigationLinkDestination },
                            label: { EmptyView() }
                        )
                    )
                    .onTapGesture {
                        isNavigationLinkActive.toggle()
                    }
                    .onChange(of: isNavigationLinkActive) { isNavLinkActive in
                        if isNavLinkActive {
                            viewStore.send(.userOpenedMangaView)
                        } else {
                            viewStore.send(.userLeftMangaView)
                        }
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
