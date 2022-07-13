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
    @State private var headerOffset: (CGFloat, CGFloat) = (100, 10)
    @State private var artSectionHeight = 0.0
    @Namespace private var tabAnimationNamespace
    @Environment(\.presentationMode) private var presentationMode

    private var isViewScrolledDown: Bool {
        headerOffset.0 < 8
    }
    
    private var isHeaderBackButtonVisible: Bool {
        headerOffset.0 > 80
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
                        .animation(.linear, value: isViewScrolledDown)
                        
                        Color.clear.frame(height: UIScreen.main.bounds.height * 0.1)
                    }
                    .onChange(of: viewStore.pagesState?.currentPage) { _ in
                        withAnimation(.easeInOut) {
                            proxy.scrollTo("header")
                        }
                    }
                }
            }
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
            .ignoresSafeArea()
            .background(
                NavigationLink(
                    destination: mangaReadingView,
                    isActive: viewStore.binding(\.$isUserOnReadingView),
                    label: { EmptyView() }
                )
            )
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
    private var mangaReadingView: some View {
        IfLetStore(
            store.scope(
                state: \.mangaReadingViewState,
                action: MangaViewAction.mangaReadingViewAction
            ),
            then: MangaReadingView.init
        )
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
                                colors: [ .black.opacity(0.3), .black.opacity(0.8) ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    backButton
                                    
                                    Spacer()
                                    
                                    Button {
//                                    fatalError("Разделить reducer в MangaFeature на два подстейта - когда есть и когда нет сети")
                                        // глянуть также SwitchStore или как то так
                                    } label: {
                                        Image(systemName: "bookmark")
                                            .foregroundColor(.white)
                                            .padding(.vertical)
                                    }
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
                    )
                    .cornerRadius(0)
                    .offset(y: -minY)
            }
            .frame(height: 250)
        }
    }
    
    private var mangaBodyView: some View {
        WithViewStore(store.actionless) { viewStore in
            switch viewStore.selectedTab {
                case .about:
                    aboutSection
                case .chapters:
                    chaptersSection
                case .coverArt:
                    coverArtSection
            }
        }
        .transition(.opacity.animation(.linear(duration: 0.2)))
        .padding(.horizontal, 5)
    }
    
    private var chaptersSection: some View {
        IfLetStore(store.scope(state: \.pagesState, action: MangaViewAction.pagesAction), then: PagesView.init) {
            WithViewStore(store) { viewStore in
                if viewStore.shouldShowEmptyMangaMessage {
                    VStack(spacing: 0) {
                        Text("Ooops, there's nothing to read")
                            .font(.title2)
                            .fontWeight(.black)
                        
                        Text("😢")
                            .font(.title2)
                            .fontWeight(.black)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                }
            }
        }
    }
    
    private var coverArtSection: some View {
        WithViewStore(store.actionless) { viewStore in
            GeometryReader { geo in
                let columnsCount = Int(geo.size.width / 160)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columnsCount)) {
                    ForEach(viewStore.coverArtURLs.indices, id: \.self) { coverArtIndex in
                        let coverArtURL = viewStore.coverArtURLs[coverArtIndex]
                        
                        KFImage.url(coverArtURL)
                            .fade(duration: 0.3)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 240)
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
                    artSectionHeight = ceil(Double(viewStore.coverArtURLs.count) / Double(columnsCount)) * 248 - 20
                    artSectionHeight = artSectionHeight > 0 ? artSectionHeight : 248
                }
                .onChange(of: viewStore.coverArtURLs.hashValue & columnsCount.hashValue) { _ in
                    withAnimation {
                        artSectionHeight = ceil(Double(viewStore.coverArtURLs.count) / Double(columnsCount)) * 248 - 20
                        artSectionHeight = artSectionHeight > 0 ? artSectionHeight : 248
                    }
                }
            }
            .frame(height: artSectionHeight)
            .padding()
        }
    }
    
    private var aboutSection: some View {
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
            .padding(.leading)
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
                
                HStack {
                    ForEach(MangaViewState.SelectedTab.allCases) { tab in
                        makeSectionFor(tab: tab)
                    }
                    .offset(x: isHeaderBackButtonVisible ? -50 : 0)
                }
            }
            .animation(.linear, value: isHeaderBackButtonVisible)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 5)
        }
        .background(Color.black)
        .offset(y: headerOffset.1 > 0 ? 0 : -headerOffset.1 / 10)
        .modifier(
            MangaViewOffsetModifier(
                offset: $headerOffset.0,
                returnFromStart: false
            )
        )
        .modifier(
            MangaViewOffsetModifier(
                offset: $headerOffset.1
            )
        )
    }
    
    private func makeSectionFor(tab: MangaViewState.SelectedTab) -> some View {
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
                .animation(.easeInOut, value: viewStore.selectedTab)
                .padding(.horizontal, 8)
                .frame(height: 8)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut) {
                    viewStore.send(.mangaTabChanged(tab))
                }
            }
        }
    }
    
    struct MangaViewOffsetModifier: ViewModifier {
        @Binding var offset: CGFloat
        @State private var startValue: CGFloat = 0
        var returnFromStart = true
        
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
                                
                                offset = value - (returnFromStart ? startValue : 0)
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
