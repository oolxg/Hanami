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
    @State private var isNavigationLinkActive: Bool = false
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .center) {
                Text(viewStore.manga.title)
                    .transaction { transaction in
                        transaction.animation = nil
                    }

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
            if let thumbnail = viewStore.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
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
            }
        }
    }
    
    // this scope seems to eat a lot of recources 
    private var navigationLinkDestination: some View {
        ZStack {
            if isNavigationLinkActive {
                LazyView(
                    MangaView(
                        store: store.scope(
                            state: \.mangaState,
                            action: MangaThumbnailAction.mangaAction
                        )
                    )
                )
            }
        }
    }
}
