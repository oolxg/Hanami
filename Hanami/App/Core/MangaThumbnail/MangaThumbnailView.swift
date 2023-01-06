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
    let store: StoreOf<MangaThumbnailFeature>
    let blurRadius: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    private struct ViewState: Equatable {
        let online: Bool
        let manga: Manga
        let mangaStatistics: MangaStatistics?
        let thumbnailURL: URL?
        
        init(state: MangaThumbnailFeature.State) {
            online = state.online
            manga = state.manga
            mangaStatistics = state.mangaStatistics
            thumbnailURL = state.thumbnailURL
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            coverArt
            
            ZStack(alignment: .topLeading) {
                if colorScheme == .dark {
                    Color.theme.darkGray
                        .opacity(0.6)
                } else {
                    Color.clear
                }

                textBlock
                    .padding(10)
            }
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            ViewStore(store).binding(\.$navigationLinkActive).wrappedValue.toggle()
        }
        .overlay(navigationLink)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(lineWidth: 1.5)
                .fill(colorScheme == .light ? .black : .clear)
        }
    }
}

#if DEBUG
struct MangaThumbnailView_Previews: PreviewProvider {
    static var previews: some View {
        MangaThumbnailView(
            store: .init(
                initialState: .init(
                    manga: dev.manga
                ),
                reducer: MangaThumbnailFeature()._printChanges()
            ),
            blurRadius: 0
        )
    }
}
#endif

extension MangaThumbnailView {
    private var textBlock: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading, spacing: 10) {
                Text(viewStore.manga.title)
                    .lineLimit(2)
                    .foregroundColor(.theme.foreground)
                    .font(.headline)
                
                if viewStore.online {
                    statistics
                }
                
                if let mangaDescription = viewStore.manga.description {
                    Text(LocalizedStringKey(mangaDescription))
                        .lineLimit(8)
                        .foregroundColor(.theme.foreground)
                        .font(.footnote)
                }
            }
            .onAppear { viewStore.send(.onAppear) }
        }
    }
    
    @MainActor private var coverArt: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            LazyImage(url: viewStore.thumbnailURL) { state in
                ZStack {
                    if let image = state.image {
                        image
                            .resizingMode(.aspectFill)
                            .frame(width: 120)
                    } else {
                        Color.theme.darkGray
                            .frame(width: 120)
                    }
                }
                .redacted(if: state.image.isNil)
            }
        }
        .overlay {
            Rectangle()
                .stroke(lineWidth: 1.5)
                .fill(colorScheme == .light ? .black : .clear)
        }
    }
    
    private var navigationLink: some View {
        WithViewStore(store) { viewStore in
            NavigationLink(
                isActive: viewStore.binding(\.$navigationLinkActive),
                destination: { mangaView },
                label: { EmptyView() }
            )
        }
    }
    
    private var mangaView: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if viewStore.online {
                OnlineMangaView(
                    store: store.scope(
                        state: \.onlineMangaState!,
                        action: MangaThumbnailFeature.Action.onlineMangaAction
                    ),
                    blurRadius: blurRadius
                )
            } else {
                OfflineMangaView(
                    store: store.scope(
                        state: \.offlineMangaState!,
                        action: MangaThumbnailFeature.Action.offlineMangaAction
                    ),
                    blurRadius: blurRadius
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
                        }
                    }
                    .redacted(if: viewStore.mangaStatistics.isNil)
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
                    .redacted(if: viewStore.mangaStatistics.isNil)
                }
                
                HStack(spacing: 5) {
                    let status = viewStore.manga.attributes.status
                    
                    Circle()
                        .fill(status.color)
                        .frame(width: 10, height: 10)
                        .padding(0)
                    
                    Text(status.rawValue.capitalized)
                        .foregroundColor(.theme.foreground)
                        .fontWeight(.semibold)
                }
            }
            .font(.footnote)
            .frame(height: 15)
        }
    }
}

extension MangaThumbnailView {
    @ViewBuilder static func skeleton(colorScheme: ColorScheme) -> some View {
        HStack(alignment: .top, spacing: 0) {
            skeletonCoverArt(colorScheme: colorScheme)
            
            ZStack(alignment: .topLeading) {
                if colorScheme == .dark {
                    Color.theme.darkGray
                        .opacity(0.6)
                } else {
                    Color.clear
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    // manga title
                    Text(String.placeholder(length: 20))
                        .lineLimit(3)
                        .foregroundColor(.theme.foreground)
                        .font(.callout)
                        .redacted(if: true)
                    
                    skeletonRating
                    
                    // description
                    VStack(alignment: .leading) {
                        Text(String.placeholder(length: DeviceUtil.isIpad ? 100 : 20))
                        Text(String.placeholder(length: DeviceUtil.isIpad ? 85 : 15))
                        Text(String.placeholder(length: DeviceUtil.isIpad ? 100 : 20))
                        Text(String.placeholder(length: DeviceUtil.isIpad ? 65 : 10))
                        Text(String.placeholder(length: DeviceUtil.isIpad ? 105 : 20))
                    }
                    .lineLimit(1)
                    .font(.footnote)
                    .redacted(if: true)
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(lineWidth: 1.5)
                .fill(colorScheme == .light ? .black : .clear)
        }
    }
    
    @ViewBuilder private static func skeletonCoverArt(colorScheme: ColorScheme) -> some View {
        Color.theme.darkGray
            .redacted(if: true)
            .frame(width: 120)
            .overlay {
                Rectangle()
                    .stroke(lineWidth: 1.5)
                    .fill(colorScheme == .light ? .black : .clear)
            }
    }
    
    private static var skeletonRating: some View {
        HStack {
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "star.fill")
                
                Text(String.placeholder(length: 3))
                    .redacted(if: true)
            }
            
            HStack(alignment: .top, spacing: 0) {
                Image(systemName: "bookmark.fill")
                
                Text(String.placeholder(length: 7))
                    .redacted(if: true)
            }
        }
        .font(.caption)
    }
}
