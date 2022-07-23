//
//  OfflineMangaThumbnailView.swift
//  Smuggler
//
//  Created by mk.pwnz on 23/07/2022.
//

import SwiftUI
import ComposableArchitecture

struct OfflineMangaThumbnailView: View {
    let store: Store<OfflineMangaThumbnailState, OfflineMangaThumbnailAction>
    @State private var isNavigationLinkActive = false

    var body: some View {
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
}

struct OfflineMangaThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}


extension OfflineMangaThumbnailView {
        // all the stuff here is to make NavigationLink 'lazy'
    private var coverArt: some View {
        WithViewStore(store.actionless) { viewStore in
//            KFImage.url(
//                viewStore.coverArtInfo?.coverArtURL512
//            )
//            .placeholder {
//                Color.black
//                    .opacity(0.45)
//                    .redacted(reason: .placeholder)
//            }
            Image(systemName: "3.square")
            .resizable()
            .scaledToFill()
            .background(
                NavigationLink(
                    isActive: $isNavigationLinkActive,
                    destination: { navigationLinkDestination },
                    label: { EmptyView() }
                )
            )
        }
        .frame(width: 100, height: 150)
        .clipped()
        .cornerRadius(10)
    }
    
    private var navigationLinkDestination: some View {
        ZStack {
            if isNavigationLinkActive {
                OfflineMangaView(
                    store: store.scope(
                        state: \.mangaViewState,
                        action: OfflineMangaThumbnailAction.mangaAction
                    )
                )
            }
        }
    }    
}
