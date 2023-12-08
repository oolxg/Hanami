//
//  OnlineMangaView.swift
//  Hanami
//
//  Created by Oleg on 16/05/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher
import PopupView
import ModelKit
import UIComponents
import Utils

struct OnlineMangaView: View {
    private let store: StoreOf<OnlineMangaFeature>
    private let blurRadius: CGFloat
    @State private var headerOffset: CGFloat = 0
    @State private var showFirstChaptersPopup = false
    @State private var showChapterLoaderSheet = false
    @Namespace private var tabAnimationNamespace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    
    private var isCoverArtDisappeared: Bool {
        headerOffset <= -450
    }
    
    init(store: StoreOf<OnlineMangaFeature>, blurRadius: CGFloat) {
        self.store = store
        self.blurRadius = blurRadius
    }
    
    private struct ViewState: Equatable {
        let manga: Manga
        let selectedTab: OnlineMangaFeature.Tab
        let coverArtURL: URL?
        let thumbnailCoverArtURL: URL?
        let allCoverArtURLs: [URL]
        let allCoverArtsInfo: [CoverArtInfo]
        let statistics: MangaStatistics?
        let lastReadChapterAvailable: Bool
        let areChaptersFetched: Bool
        let firstChapterOptions: [ChapterDetails]?
        let isMangaReadingViewPresented: Bool
        let isErrorOccured: Bool
        let showAuthorView: Bool
        
        init(state: OnlineMangaFeature.State) {
            manga = state.manga
            selectedTab = state.selectedTab
            coverArtURL = state.mainCoverArtURL
            thumbnailCoverArtURL = state.coverArtURL256
            allCoverArtURLs = state.croppedCoverArtURLs
            allCoverArtsInfo = state.allCoverArtsInfo
            statistics = state.statistics
            lastReadChapterAvailable = state.lastReadChapterID.hasValue && state.pagesState.hasValue
            areChaptersFetched = state.pagesState.hasValue
            firstChapterOptions = state.firstChapterOptions
            isMangaReadingViewPresented = state.isMangaReadingViewPresented
            isErrorOccured = state.isErrorOccured
            showAuthorView = state.showAuthorView
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ScrollView(showsIndicators: false) {
                ScrollViewReader { proxy in
                    LazyVStack(pinnedViews: .sectionHeaders) {
                        header
                            .id("header")
                        
                        Section {
                            mangaBodyView
                        } header: {
                            pinnedNavigation
                        } footer: {
                            footer
                        }
                        .sheet(isPresented: $showChapterLoaderSheet) {
                            IfLetStore(
                                store.scope(
                                    state: \.chapterLoaderState,
                                    action: OnlineMangaFeature.Action.chapterLoaderAcion
                                )
                            ) { loaderStore in
                                MangaChapterLoaderView(store: loaderStore)
                                    .environment(\.colorScheme, colorScheme)
                            }
                        }
                    }
                    .onChange(of: viewStore.selectedTab) { _ in
                        if isCoverArtDisappeared {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.linear) {
                                    proxy.scrollTo("header")
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                readingActionButton
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 5)
            }
            .animation(.linear, value: isCoverArtDisappeared)
            .onAppear { viewStore.send(.onAppear) }
            .overlay(
                Rectangle()
                    .fill(Color.theme.background)
                    .frame(height: DeviceUtil.hasTopNotch ? 50 : 20)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isCoverArtDisappeared ? 1 : 0)
            )
            .navigationBarHidden(true)
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)
            .fullScreenCover(
                isPresented: viewStore.binding(
                    get: \.isMangaReadingViewPresented,
                    send: OnlineMangaFeature.Action.nowReadingViewStateDidUpdate
                ),
                content: mangaReadingView
            )
            .popup(isPresented: $showFirstChaptersPopup) {
                firstChaptersOptions
            } customize: {
                $0
                    .closeOnTap(false)
                    .closeOnTapOutside(true)
                    .backgroundColor(.black.opacity(0.4))
            }
            .tint(.theme.accent)
            .background(Color.theme.background)
        }
    }
}

extension OnlineMangaView {
    private var firstChaptersOptions: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .center) {
                Text("Available chapters")
                    .fontWeight(.bold)
                    .font(.title3)
                    .padding(.bottom, 10)
                
                ForEach(viewStore.firstChapterOptions ?? []) { chapter in
                    LazyVStack(alignment: .leading) {
                        HStack(alignment: .bottom) {
                            Text(chapter.chapterName)
                            
                            Spacer()
                            
                            if chapter.attributes.externalURL.hasValue {
                                Image("ExternalLinkIcon")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                        }
                        
                        if let scanlationGroup = chapter.scanlationGroup {
                            HStack {
                                Text(scanlationGroup.name)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .font(.caption)
                                    .foregroundColor(.theme.secondaryText)
                                
                                if scanlationGroup.attributes.isOfficial {
                                    Image(systemName: "person.badge.shield.checkmark")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.green)
                                        .frame(height: 15)
                                }
                            }
                        }
                        
                        Divider()
                    }
                    .onTapGesture {
                        showFirstChaptersPopup = false
                        viewStore.send(.userTappedOnFirstChapterOption(chapter))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(25)
        .background(Color.theme.background.cornerRadius(20))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var footer: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack(spacing: 0) {
                Text("All information on this page provided by ")
                
                Text("MANGADEX")
                    .fontWeight(.semibold)
                    .onTapGesture {
                        openURL(Defaults.Links.mangaDexTitleLink(mangaID: viewStore.manga.id))
                    }
            }
            .font(.caption2)
            .foregroundColor(.gray)
            .padding(.horizontal)
            .padding(.bottom, viewStore.areChaptersFetched ? 50 : 5)
            .opacity(viewStore.areChaptersFetched ? 1 : 0)
            .animation(.linear, value: viewStore.areChaptersFetched)
        }
    }
    
    @ViewBuilder private func mangaReadingView() -> some View {
        IfLetStore(
            store.scope(
                state: \.mangaReadingViewState,
                action: OnlineMangaFeature.Action.mangaReadingViewAction
            )
        ) { readingStore in
            OnlineMangaReadingView(
                store: readingStore,
                blurRadius: blurRadius
            )
            .environment(\.colorScheme, colorScheme)
        }
    }
    
    private var header: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            GeometryReader { geo in
                let minY = geo.frame(in: .named("scroll")).minY
                let height = geo.size.height + minY
                
                KFImage(viewStore.coverArtURL)
                    .placeholder {
                        KFImage(viewStore.thumbnailCoverArtURL)
                            .onlyFromCache()
                            .resizable()
                            .scaledToFill()
                    }
                    .resizable()
                    .scaledToFill()
                    .animation(nil, value: true)
                    .frame(width: geo.size.width, height: height > 0 ? height : 0, alignment: .center)
                    .overlay(headerOverlay)
                    .cornerRadius(0)
                    .offset(y: -minY)
            }
            .frame(height: 450)
        }
    }
    
    private var headerOverlay: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [ .theme.background.opacity(0.1), .theme.background.opacity(0.8) ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .bottom) {
                        backButton
                        
                        Spacer()
                        
//                        chapterLoaderButton
                        
                        refreshButton
                    }
                    
                    Spacer()
                    
                    HStack {
                        Text("MANGA")
                            .font(.callout)
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(viewStore.manga.attributes.status.color)
                                .frame(width: 10, height: 10)
                                // circle disappears on scroll down, 'drawingGroup' helps to fix it
                                .drawingGroup()
                            
                            Text(viewStore.manga.attributes.status.rawValue.capitalized)
                                .foregroundColor(Color.theme.foreground)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    
                    Text(viewStore.manga.title)
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(5)
                }
                .padding(.horizontal)
                .padding(.top, DeviceUtil.hasTopNotch ? 40 : 15)
                .padding(.bottom, 25)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(headerOverlayOpacity)
        }
    }
    
    // when user scrolls up, we make all text and gradient on header slowly disappear
    private var headerOverlayOpacity: Double {
        if headerOffset < 0 { return 1 }
        
        let opacity = 1 - headerOffset * 0.01
        
        return max(opacity, 0)
    }
    
    private var mangaBodyView: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            switch viewStore.selectedTab {
            case .chapters:
                IfLetStore(
                    store.scope(
                        state: \.pagesState,
                        action: OnlineMangaFeature.Action.pagesAction
                    ),
                    then: PagesView.init,
                    else: {
                        chaptersNotLoadedView
                            .padding(.top, 50)
                            .padding(.bottom, 20)
                    }
                )
                .environment(\.colorScheme, colorScheme)
                .animation(nil, value: viewStore.areChaptersFetched)
            case .info:
                aboutTab
            case .coverArt:
                coverArtTab
            }
        }
        .padding(.horizontal, 5)
    }
    
    private var chaptersNotLoadedView: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if viewStore.isErrorOccured {
                errorMessage
            } else {
                ProgressView()
            }
        }
    }
    
    private var errorMessage: some View {
        VStack(alignment: .center) {
            Text("There's some error...")
                .fontWeight(.bold)

            Text("Sorry...")
                .fontWeight(.bold)

            Text("👉👈")
                .fontWeight(.bold)
        }
        .font(.title3)
    }
    
    private var coverArtTab: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 10)]) {
                ForEach(viewStore.allCoverArtURLs.indices, id: \.self) { coverArtIndex in
                    KFImage(viewStore.allCoverArtURLs[coverArtIndex])
                        .placeholder { progress in
                            ProgressView(value: progress.fractionCompleted)
                                .defaultWithProgress()
                                .frame(width: 30, height: 30)
                        }
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            ZStack(alignment: .bottom) {
                                if let volume = viewStore.allCoverArtsInfo[coverArtIndex].attributes.volume {
                                    LinearGradient(
                                        colors: [.clear, .clear, .theme.background],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    
                                    Text("Volume \(volume)")
                                        .font(.callout)
                                }
                            }
                        )
                        .frame(height: 240)
                        .padding(.horizontal, 5)
                }
            }
            .padding()
        }
    }
    
    private var aboutTab: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                if let statistics = viewStore.statistics {
                    Text("Rating")
                        .font(.headline)
                        .fontWeight(.black)
                    
                    Divider()
                    
                    HStack(alignment: .top, spacing: 10) {
                        HStack(alignment: .top, spacing: 0) {
                            Image(systemName: "star.fill")
                            
                            Text(statistics.rating.average?.clean() ?? statistics.rating.bayesian.clean())
                        }
                        
                        HStack(alignment: .top, spacing: 0) {
                            Image(systemName: "bookmark.fill")
                            
                            Text(statistics.follows.abbreviation)
                        }
                    }
                    .padding(.horizontal)
                    .font(.subheadline)
                }
                
                if !viewStore.manga.authors.isEmpty {
                    VStack(alignment: .leading) {
                        Text(viewStore.manga.authors.count > 1 ? "Authors" : "Author")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        FlexibleView(
                            data: viewStore.manga.authors,
                            spacing: 10,
                            alignment: .leading
                        ) { author in
                            makeChipsView(text: author.attributes.name)
                                .onTapGesture {
                                    viewStore.send(.authorNameTapped(author))
                                }
                        }
                        .padding(.horizontal, 5)
                        .fullScreenCover(
                            isPresented: viewStore.binding(
                                get: \.showAuthorView,
                                send: OnlineMangaFeature.Action.showAuthorViewValueDidChange
                            )
                        ) {
                            IfLetStore(
                                store.scope(
                                    state: \.authorViewState,
                                    action: OnlineMangaFeature.Action.authorViewAction
                                )
                            ) { authorStore in
                                AuthorView(
                                    store: authorStore,
                                    blurRadius: blurRadius
                                )
                                .environment(\.colorScheme, colorScheme)
                            }
                        }
                    }
                }
                
                if let description = viewStore.manga.description {
                    VStack(alignment: .leading) {
                        Text("Description")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        Text(LocalizedStringKey(description))
                            .padding(.horizontal, 10)
                    }
                }
                
                tags
            }
        }
    }
    
    private var tags: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.black)
                
                Divider()
                
                FlexibleView(
                    data: viewStore.manga.attributes.tags,
                    spacing: 10,
                    alignment: .leading
                ) { tag in
                    makeChipsView(text: tag.name.capitalized)
                }
                .padding(.horizontal, 5)
                
                if let demographic = viewStore.manga.attributes.publicationDemographic?.rawValue {
                    VStack(alignment: .leading) {
                        Text("Demographic")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        makeChipsView(text: demographic.capitalized)
                            .padding(.horizontal, 5)
                    }
                    .frame(minHeight: 20)
                }
            }
        }
    }
    
    @ViewBuilder private func makeChipsView(text: String) -> some View {
        Text(text)
            .font(.callout)
            .lineLimit(1)
            .padding(10)
            .foregroundColor(.white)
            .background(Color.theme.darkGray)
            .cornerRadius(10)
    }
    
    private var backButton: some View {
        Button {
            self.dismiss()
        } label: {
            Image(systemName: "xmark")
                .foregroundColor(Color.theme.foreground)
                .padding(.vertical)
        }
        .transition(.opacity)
        .font(.title3)
    }
    
    private var chapterLoaderButton: some View {
        Button {
            ViewStore(store, observe: { _ in 0 }).send(.userTappedOnChapterLoaderButton)
            showChapterLoaderSheet = true
        } label: {
            Image(systemName: "arrow.down.to.line.circle")
                .foregroundColor(Color.theme.foreground)
                .padding(.vertical)
        }
        .transition(.opacity)
        .font(.title3)
    }
    
    private var refreshButton: some View {
        Button {
            ViewStore(store, observe: { _ in 0 }).send(.refreshButtonTapped)
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(Color.theme.foreground)
                .padding(.vertical)
        }
        .transition(.opacity)
        .font(.title3)
    }
    
    private var pinnedNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 25) {
                backButton
                    .opacity(isCoverArtDisappeared ? 1 : 0)
                
                ForEach(OnlineMangaFeature.Tab.allCases, content: makeTabLabel)
            }
            .offset(x: isCoverArtDisappeared ? 0 : -40)
            .padding(.leading)
            .padding(.top, DeviceUtil.hasTopNotch ? 20 : 0)
            .padding(.bottom, 5)
        }
        .animation(.linear(duration: 0.2), value: isCoverArtDisappeared)
        .background(Color.theme.background)
        .offset(y: headerOffset > 0 ? 0 : DeviceUtil.hasTopNotch ? -headerOffset / 10 : 20)
        .modifier(MangaViewOffsetModifier(offset: $headerOffset))
    }
    
    private var readingActionButton: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            Button {
                viewStore.send(
                    viewStore.lastReadChapterAvailable ? .continueReadingButtonTapped : .startReadingButtonTapped
                )
                
                if viewStore.firstChapterOptions.hasValue && !viewStore.lastReadChapterAvailable {
                    showFirstChaptersPopup = true
                }
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewStore.lastReadChapterAvailable ? Color.theme.accent : .theme.green)
                    .overlay {
                        Text(viewStore.lastReadChapterAvailable ? "Continue reading!" : "Start reading!")
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .padding(.horizontal, 5)
            }
            .opacity(viewStore.areChaptersFetched ? 1 : 0)
            .animation(.linear, value: viewStore.areChaptersFetched)
            .onChange(of: viewStore.firstChapterOptions.hasValue) { _ in
                showFirstChaptersPopup = !viewStore.isMangaReadingViewPresented
            }
        }
    }
    
    /// Makes label for navigation through MangaView
    private func makeTabLabel(for tab: OnlineMangaFeature.Tab) -> some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(spacing: 12) {
                Text(tab.rawValue)
                    .fontWeight(.semibold)
                    .foregroundColor(viewStore.selectedTab == tab ? .theme.foreground : .gray)
                
                ZStack {
                    if viewStore.selectedTab == tab {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.theme.foreground)
                            .matchedGeometryEffect(id: "tab", in: tabAnimationNamespace)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewStore.send(.navigationTabButtonTapped(tab), animation: .easeInOut)
            }
        }
    }
    
    private struct MangaViewOffsetModifier: ViewModifier {
        @Binding var offset: CGFloat
        @State private var startValue: CGFloat = 0
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: MangaViewOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                            .onPreferenceChange(MangaViewOffsetKey.self) { value in
                                if startValue == 0 {
                                    startValue = value
                                }
                                
                                offset = value - startValue
                            }
                    }
                )
        }
    }
    
    private struct MangaViewOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
