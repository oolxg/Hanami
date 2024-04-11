//
//  MangaThumbnailView.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher
import WrappingHStack
import ModelKit
import Utils

struct MangaThumbnailView: View {
    let store: StoreOf<MangaThumbnailFeature>
    let blurRadius: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    private struct ViewState: Equatable {
        let online: Bool
        let manga: Manga
        
        init(state: MangaThumbnailFeature.State) {
            online = state.online
            manga = state.manga
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: \.isMangaViewPresented) { viewStore in
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
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(lineWidth: 1.5)
                    .fill(colorScheme == .light ? .black : .clear)
            }
            .onAppear { viewStore.send(.onAppear) }
            .onTapGesture { viewStore.send(.navLinkValueDidChange(to: true)) }
            .fullScreenCover(
                isPresented: viewStore.binding(
                    send: MangaThumbnailFeature.Action.navLinkValueDidChange
                )
            ) {
                mangaView
            }
        }
    }
}

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
                        .lineLimit(6)
                        .foregroundColor(.theme.foreground)
                        .font(.footnote)
                }
            }
        }
    }
    
    private var coverArt: some View {
        WithViewStore(store, observe: \.thumbnailURL) { viewStore in
            KFImage(viewStore.state)
                .retry(maxCount: 2, interval: .seconds(3))
                .placeholder {
                    Color.theme.darkGray
                }
                .resizable()
                .overlay {
                    Rectangle()
                        .stroke(lineWidth: 1.5)
                        .fill(colorScheme == .light ? .black : .clear)
                }
        }
        .frame(width: 120, height: 170, alignment: .center)
    }
    
    private var mangaView: some View {
        WithViewStore(store, observe: \.online) { viewStore in
            if viewStore.state {
                OnlineMangaView(
                    store: store.scope(
                        state: \.onlineMangaState!,
                        action: \.onlineMangaAction
                    ),
                    blurRadius: blurRadius
                )
                .environment(\.colorScheme, colorScheme)
            } else {
                OfflineMangaView(
                    store: store.scope(
                        state: \.offlineMangaState!,
                        action: \.offlineMangaAction
                    ),
                    blurRadius: blurRadius
                )
                .environment(\.colorScheme, colorScheme)
            }
        }
    }
    
    private var statistics: some View {
        WithViewStore(store, observe: \.mangaStatistics) { viewStore in
            WrappingHStack(alignment: .leading, lineSpacing: 10) {
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: "star.fill")

                    ZStack {
                        if let rating = viewStore.state?.rating {
                            Text(rating.average?.clean(accuracy: 2) ?? rating.bayesian.clean(accuracy: 2))
                        } else {
                            Text(String.placeholder(length: 3))
                        }
                    }
                    .redacted(if: viewStore.state.isNil)
                }
                
                HStack(alignment: .top, spacing: 0) {
                    Image(systemName: "bookmark.fill")

                    ZStack {
                        if let followsCount = viewStore.state?.follows.abbreviation {
                            Text(followsCount)
                        } else {
                            Text(String.placeholder(length: 7))
                                .redacted(reason: .placeholder)
                        }
                    }
                    .redacted(if: viewStore.state.isNil)
                }
                
                mangaStatus
            }
            .font(.footnote)
        }
    }
    
    private var mangaStatus: some View {
        WithViewStore(store, observe: \.manga.attributes.status) { viewStore in
            HStack(spacing: 5) {
                Circle()
                    .fill(viewStore.state.color)
                    .frame(width: 10, height: 10)
                    .padding(0)
                
                Text(viewStore.state.rawValue.capitalized)
                    .foregroundColor(.theme.foreground)
                    .fontWeight(.semibold)
            }
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
                        .redacted(reason: .placeholder)
                    
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
                    .redacted(reason: .placeholder)
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 170)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(lineWidth: 1.5)
                .fill(colorScheme == .light ? .black : .clear)
        }
    }
    
    @ViewBuilder private static func skeletonCoverArt(colorScheme: ColorScheme) -> some View {
        Color.theme.darkGray
            .redacted(reason: .placeholder)
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
