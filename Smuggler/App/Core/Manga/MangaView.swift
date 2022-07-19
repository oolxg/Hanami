//
//  MangaView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

// swiftlint:disable file_length
import SwiftUI
import ComposableArchitecture
import Kingfisher

struct MangaView: View {
    let store: Store<MangaViewState, MangaViewAction>
    // i don't know how does it work https://www.youtube.com/watch?v=ATi5EnY5IYE
    @State private var headerOffset: CGFloat = 0
    @State private var artSectionHeight = 0.0
    @Namespace private var tabAnimationNamespace
    @Environment(\.presentationMode) private var presentationMode

    private var isViewScrolledDown: Bool {
        headerOffset < -320
    }
    
    private var isHeaderBackButtonVisible: Bool {
        headerOffset > -240
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ScrollView(showsIndicators: false) {
                ScrollViewReader { proxy in
                    header
                        .id("header")
                    
                    LazyVStack(pinnedViews: .sectionHeaders) {
                        Section {
                            mangaBodyView
                        } header: {
                            pinnedNavigation
                        }
                    }
                    .onChange(of: viewStore.pagesState.currentPageIndex) { _ in
                        scrollToHeader(proxy: proxy)
                    }
                    .onChange(of: viewStore.selectedTab) { _ in
                        scrollToHeader(proxy: proxy)
                    }
                }
            }
            .animation(.linear, value: isViewScrolledDown)
            .animation(.default, value: viewStore.pagesState.currentPageIndex)
            .onAppear { viewStore.send(.onAppear) }
            .overlay(
                Rectangle()
                    .fill(.black)
                    .frame(height: 50)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isViewScrolledDown ? 1 : 0)
            )
            .navigationBarHidden(true)
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)
            .padding(.bottom, 5)
            .fullScreenCover(isPresented: viewStore.binding(\.$isUserOnReadingView), content: mangaReadingView)
            .hud(
                isPresented: viewStore.binding(\.$hudInfo.show),
                message: viewStore.hudInfo.message,
                iconName: viewStore.hudInfo.iconName,
                hideAfter: 2.5,
                backgroundColor: viewStore.hudInfo.backgroundColor
            )
        }
    }
}


struct MangaView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}


extension MangaView {
    private func mangaReadingView() -> some View {
        IfLetStore(
            store.scope(
                state: \.mangaReadingViewState, action: MangaViewAction.mangaReadingViewAction
            ),
            then: MangaReadingView.init
        )
    }
    
    private func scrollToHeader(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.linear) {
                proxy.scrollTo("header")
            }
        }
    }
    
    private var header: some View {
        WithViewStore(store) { viewStore in
            GeometryReader { geo in
                let minY = geo.frame(in: .named("scroll")).minY
                let height = geo.size.height + minY
                
                KFImage.url(viewStore.mainCoverArtURL)
                    .placeholder {
                        KFImage.url(viewStore.coverArtURL512)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: height > 0 ? height : 0, alignment: .center)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: height > 0 ? height : 0, alignment: .center)
                    .overlay(
                        ZStack(alignment: .bottom) {
                            LinearGradient(
                                colors: [ .black.opacity(0.1), .black.opacity(0.8) ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            
                            VStack(alignment: .leading, spacing: 12) {
                                backButton
                                
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
                            }
                            .padding(.horizontal)
                            .padding(.top, 40)
                            .padding(.bottom, 25)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .opacity(headerTextOpacity)
                    )
                    .cornerRadius(0)
                    .offset(y: -minY)
            }
            .frame(height: 320)
        }
    }

    // when user scrolls up, we make all text and gradient on header slowly disappear
    private var headerTextOpacity: Double {
        if headerOffset < 0 { return 1 }
        
        let opacity = 1 - headerOffset * 0.01
        
        return opacity >= 0 ? opacity : 0
    }
    
    
    private var mangaBodyView: some View {
        WithViewStore(store.actionless) { viewStore in
            switch viewStore.selectedTab {
                case .info:
                    aboutTab
                case .chapters:
                    PagesView(
                        store: store.scope(
                            state: \.pagesState, action: MangaViewAction.pagesAction
                        )
                    )
                case .coverArt:
                    coverArtTab
            }
        }
        .transition(.opacity)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 5)
    }
    
    private var coverArtTab: some View {
        WithViewStore(store.actionless) { viewStore in
            GeometryReader { geo in
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: Int(geo.size.width / 160))
                ) {
                    ForEach(viewStore.croppedCoverArtURLs.indices, id: \.self) { coverArtIndex in
                        let coverArtURL = viewStore.croppedCoverArtURLs[coverArtIndex]
                        
                        KFImage.url(coverArtURL)
                            .placeholder {
                                KFImage.url(viewStore.coverArtURL512)
                            }
                            .fade(duration: 0.3)
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 5)
                            .overlay(
                                ZStack(alignment: .bottom) {
                                    if let volumeName = viewStore.allCoverArtsInfo[coverArtIndex].attributes.volume {
                                        LinearGradient(
                                            colors: [.clear, .clear, .black],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        
                                        Text("Volume \(volumeName)")
                                            .font(.callout)
                                    }
                                }
                            )
                    }
                }
                .onAppear {
                    computeArtSectionHeight(
                        screenWidth: geo.size.width, coverArtsCount: viewStore.croppedCoverArtURLs.count
                    )
                }
                .onChange(of: viewStore.croppedCoverArtURLs.hashValue & geo.size.width.hashValue) { _ in
                    computeArtSectionHeight(
                        screenWidth: geo.size.width, coverArtsCount: viewStore.croppedCoverArtURLs.count
                    )
                }
            }
            .frame(height: artSectionHeight)
            .padding()
        }
    }
    
    private func computeArtSectionHeight(screenWidth: CGFloat, coverArtsCount: Int) {
        withAnimation {
            let columnsCount = Int(screenWidth / 160)
            let rowsCount = ceil(Double(coverArtsCount) / Double(columnsCount))
            artSectionHeight = rowsCount * 248 - 20
            artSectionHeight = artSectionHeight > 0 ? artSectionHeight : 248
        }
    }
    
    private var aboutTab: some View {
        WithViewStore(store.actionless) { viewStore in
            VStack(alignment: .leading, spacing: 10) {
                if let statistics = viewStore.statistics {
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
                    .padding()
                    .font(.subheadline)
                }
                
                VStack(alignment: .leading) {
                    Text("Description")
                        .font(.headline)
                        .fontWeight(.black)
                        .padding(10)
                    
                    Divider()
                    
                    Text(LocalizedStringKey(viewStore.manga.description ?? "No description"))
                        .padding(15)
                }
                
                tags
            }
            .padding(.horizontal)
        }
    }
    
    private var tags: some View {
        WithViewStore(store.actionless) { viewStore in
            VStack(alignment: .leading) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.black)
                    .padding(10)
                
                Divider()
            
                GridChipsView(
                    viewStore.manga.attributes.tags,
                    width: UIScreen.main.bounds.width * 0.95
                ) { tag in
                    Text(tag.name.capitalized)
                        .font(.callout)
                        .lineLimit(1)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.theme.darkGray)
                        .cornerRadius(10)
                }
                .frame(minHeight: 25)
                .padding(15)
                
                if let demographic = viewStore.manga.attributes.publicationDemographic?.rawValue {
                    Text("Demographic")
                        .font(.headline)
                        .fontWeight(.black)
                        .padding(10)
                    
                    Divider()
                    
                    Text(demographic.capitalized)
                        .font(.callout)
                        .lineLimit(1)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.theme.darkGray)
                        .cornerRadius(10)
                        .padding(15)
                }
            }
        }
    }
    
    private var backButton: some View {
        Button {
            self.presentationMode.wrappedValue.dismiss()
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
                    .opacity(isHeaderBackButtonVisible ? 0 : 1)
                
                ForEach(MangaViewState.Tab.allCases, content: makeTabLabel)
                    .offset(x: isHeaderBackButtonVisible ? -50 : 0)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 5)
        }
        .animation(.linear, value: isHeaderBackButtonVisible)
        .background(Color.black)
        .offset(y: headerOffset > 0 ? 0 : -headerOffset / 10)
        .modifier(
            MangaViewOffsetModifier(
                offset: $headerOffset
            )
        )
    }
    
    /// Makes label for navigation through MangaView
    private func makeTabLabel(for tab: MangaViewState.Tab) -> some View {
        WithViewStore(store) { viewStore in
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
            .animation(.easeInOut, value: viewStore.selectedTab)
            .onTapGesture {
                viewStore.send(.mangaTabChanged(tab), animation: .easeInOut)
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
