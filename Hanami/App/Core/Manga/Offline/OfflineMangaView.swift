//
//  OfflineMangaView.swift
//  Hanami
//
//  Created by Oleg on 23/07/2022.
//

import SwiftUI
import ComposableArchitecture
import NukeUI

struct OfflineMangaView: View {
    let store: StoreOf<OfflineMangaFeature>
    let blurRadius: CGFloat
    @State private var headerOffset: CGFloat = 0
    @State private var showMangaDeletionDialog = false
    @Namespace private var tabAnimationNamespace
    @Environment(\.dismiss) private var dismiss
    
    private var isCoverArtDisappeared: Bool {
        headerOffset <= -350
    }
    
    private  struct ViewState: Equatable {
        let manga: Manga
        let currentPageIndex: Int?
        let coverArtPath: URL?
        let selectedTab: OfflineMangaFeature.Tab
        
        init(state: OfflineMangaFeature.State) {
            manga = state.manga
            currentPageIndex = state.pagesState?.currentPageIndex
            coverArtPath = state.coverArtPath
            selectedTab = state.selectedTab
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ScrollView(showsIndicators: false) {
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
                }
            }
            .animation(.linear, value: isCoverArtDisappeared)
            .animation(.default, value: viewStore.currentPageIndex)
            .onAppear { viewStore.send(.onAppear) }
            .overlay(
                Rectangle()
                    .fill(.black)
                    .frame(height: 50)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isCoverArtDisappeared ? 1 : 0)
            )
            .navigationBarHidden(true)
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)
            .fullScreenCover(isPresented: ViewStore(store).binding(\.$isUserOnReadingView), content: mangaReadingView)
            .tint(.theme.accent)
        }
    }
}

#if DEBUG
struct OfflineMangaView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}
#endif

extension OfflineMangaView {
    private func mangaReadingView() -> some View {
        IfLetStore(
            store.scope(
                state: \.mangaReadingViewState,
                action: OfflineMangaFeature.Action.mangaReadingViewAction
            )
        ) { readingStore in
            OfflineMangaReadingView(
                store: readingStore,
                blurRadius: blurRadius
            )
        }
    }
    
    private var footer: some View {
        HStack(spacing: 0) {
            Text("All information on this page provided by ")
            
            Text("MANGADEX")
                .fontWeight(.semibold)
        }
        .font(.caption2)
        .foregroundColor(.gray)
        .padding(.horizontal)
        .padding(.bottom, 5)
    }
    
    @MainActor private var header: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            GeometryReader { geo in
                let minY = geo.frame(in: .named("scroll")).minY
                let height = geo.size.height + minY
                
                LazyImage(url: viewStore.coverArtPath, resizingMode: .aspectFill)
                    .frame(width: geo.size.width, height: height > 0 ? height : 0, alignment: .center)
                    .overlay(headerOverlay)
                    .cornerRadius(0)
                    .offset(y: -minY)
            }
            .frame(height: 350)
        }
    }
    
    private var headerOverlay: some View {
        WithViewStore(store.actionless, observe: ViewState.init) { viewStore in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [ .black.opacity(0.1), .black.opacity(0.8) ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        backButton
                        
                        Spacer()
                        
                        deleteButton
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
                                .foregroundColor(.white)
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
                .padding(.top, 40)
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
    
    
    private var deleteButton: some View {
        Button {
            showMangaDeletionDialog = true
        } label: {
            Image(systemName: "trash")
                .foregroundColor(.white)
        }
        .confirmationDialog(
            "Are you sure you want delete this manga and all chapters from device?",
            isPresented: $showMangaDeletionDialog
        ) {
            Button("Delete", role: .destructive) {
                self.dismiss()
                ViewStore(store).send(.deleteMangaButtonTapped)
            }
            
            Button("Cancel", role: .cancel) {
                showMangaDeletionDialog = false
            }
        } message: {
            Text("Are you sure you want delete this manga and all chapters from device?")
        }
    }
    
    private var mangaBodyView: some View {
        WithViewStore(store.actionless, observe: ViewState.init) { viewStore in
            switch viewStore.selectedTab {
            case .chapters:
                IfLetStore(
                    store.scope(
                        state: \.pagesState,
                        action: OfflineMangaFeature.Action.pagesAction
                    ),
                    then: PagesView.init
                )
            case .info:
                aboutTab
            }
        }
        .padding(.horizontal, 5)
    }
    
    private var aboutTab: some View {
        WithViewStore(store.actionless, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                if !viewStore.manga.authors.isEmpty {
                    VStack(alignment: .leading) {
                        Text(viewStore.manga.authors.count > 1 ? "Authors" : "Author")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        FlexibleView(
                            data: viewStore.manga.authors.map(\.attributes.name),
                            spacing: 10,
                            alignment: .leading,
                            content: makeChipsView
                        )
                        .padding(.horizontal, 5)
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
        WithViewStore(store.actionless, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.black)
                
                Divider()
                
                FlexibleView(
                    data: viewStore.manga.attributes.tags.map(\.name.capitalized),
                    spacing: 10,
                    alignment: .leading,
                    content: makeChipsView
                )
                .padding(.horizontal, 5)
                
                if let demographic = viewStore.manga.attributes.publicationDemographic?.rawValue {
                    VStack(alignment: .leading) {
                        Text("Demographic")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        makeChipsView(text: demographic.capitalized)
                            .padding(5)
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
            Image(systemName: "arrow.left")
                .foregroundColor(.white)
                .padding(.vertical)
        }
        .transition(.opacity)
    }
    
    private var pinnedNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 25) {
                backButton
                    .opacity(isCoverArtDisappeared ? 1 : 0)
                
                ForEach(OfflineMangaFeature.Tab.allCases, content: makeTabLabel)
                    .offset(x: isCoverArtDisappeared ? 0 : -40)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 5)
        }
        .animation(.linear(duration: 0.2), value: isCoverArtDisappeared)
        .background(Color.black)
        .offset(y: headerOffset > 0 ? 0 : -headerOffset / 10)
        .modifier(
            MangaViewOffsetModifier(
                offset: $headerOffset
            )
        )
    }
    
    /// Makes label for navigation through MangaView
    private func makeTabLabel(for tab: OfflineMangaFeature.Tab) -> some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(spacing: 12) {
                Text(tab.rawValue)
                    .fontWeight(.semibold)
                    .foregroundColor(viewStore.selectedTab == tab ? .white : .gray)
                
                ZStack {
                    if viewStore.selectedTab == tab {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.white)
                            .matchedGeometryEffect(id: "tab", in: tabAnimationNamespace)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewStore.send(.mangaTabButtonTapped(tab), animation: .easeInOut)
            }
        }
    }
    
    struct MangaViewOffsetModifier: ViewModifier {
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
    
    struct MangaViewOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
