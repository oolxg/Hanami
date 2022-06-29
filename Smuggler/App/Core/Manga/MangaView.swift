//
//  MangaView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct MangaView: View {
    let store: Store<MangaViewState, MangaViewAction>
    
    // i don't know how does it work https://www.youtube.com/watch?v=ATi5EnY5IYE
    @State private var headerOffset: (CGFloat, CGFloat) = (10, 10)
    @Namespace private var tabAnimationNamespace
    @Environment(\.presentationMode) var presentationMode

    private var isViewScrolledDown: Bool {
        headerOffset.0 < 10
    }
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                ScrollView(showsIndicators: false) {
                    header
                    
                    LazyVStack(pinnedViews: .sectionHeaders) {
                        Section {
                            mangaBodyView
                        } header: {
                            pinnedNavigation
                        }
                    }
                }
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .overlay(
                    Rectangle()
                        .fill(.black)
                        .frame(height: 50)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .opacity(isViewScrolledDown ? 1 : 0)
                )
                .navigationBarHidden(true)
                .coordinateSpace(name: "scroll")
                .ignoresSafeArea(.container, edges: .vertical)
                .padding(.bottom, 1)
                .background(
                    // swiftlint:disable:next trailing_closure
                    NavigationLink(
                        destination: mangaReadingView,
                        isActive: viewStore.binding(\.$isUserOnReadingView),
                        label: { EmptyView() }
                    )
                )
            }
        }
    }
}

struct MangaView_Previews: PreviewProvider {
    static var previews: some View {
        MangaView(
            store: .init(
                initialState: .init(
                    manga: dev.manga
                ),
                reducer: mangaViewReducer,
                environment: .live(
                    environment: .init(
                        fetchMangaVolumes: fetchChaptersForManga,
                        fetchAllCoverArtsInfo: fetchAllCoverArtsInfoForManga,
                        fetchMangaStatistics: fetchMangaStatistics
                    )
                )
            )
        )
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
                let size = geo.size
                let height = size.height + minY
                
                if let coverArt = viewStore.coverArt {
                    Image(uiImage: coverArt)
                        .resizable()
                        .scaledToFill()
                        .frame(height: height > 0 ? height : 0, alignment: .center)
                        .overlay(
                            ZStack(alignment: .bottom) {
                                LinearGradient(
                                    colors: [ .clear, .black.opacity(0.8) ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    backButton
                                    
                                    Spacer()
                                    
                                    Text("MANGA")
                                        .font(.callout)
                                        .foregroundColor(.gray)
                                    
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
            }
            .frame(height: 250)
        }
    }
    
    private var mangaBodyView: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                if viewStore.selectedTab == .about {
                    mangaInfoView
                }
                
                if viewStore.selectedTab == .chapters {
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
                    } else {
                        VStack {
                            ForEachStore(
                                store.scope(state: \.volumeTabStates, action: MangaViewAction.volumeTabAction)
                            ) { volumeStore in
                                LazyView(
                                    VolumeTabView(store: volumeStore)
                                )
                                
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundColor(.theme.darkGray)
                            }
                        }
                    }
                }
                
                if viewStore.selectedTab == .coverArt {
                    GeometryReader { geo in
                        let columnsCount = Int(geo.size.width / 150)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columnsCount)
                        ) {
                            ForEach(0..<viewStore.allCoverArts.count, id: \.self) { index in
                                Image(uiImage: viewStore.allCoverArts[index])
                                    .resizable()
                                    .scaledToFit()
                                    .padding(.horizontal, 5)
                                    .overlay(
                                        ZStack(alignment: .bottom) {
                                            if let volumeName = viewStore.allCoverArtsInfo[index].attributes.volume {
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
                    }
                    .padding()
                    .onAppear {
                        viewStore.send(.userOpenedCoverArtSection)
                    }
                }
            }
            .transition(.opacity)
            .frame(minHeight: 400, alignment: .top)
        }
    }
    
    private var mangaInfoView: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                if let statistics = viewStore.statistics {
                    HStack(alignment: .top, spacing: 10) {
                        HStack(alignment: .top, spacing: 0) {
                            Image(systemName: "star.fill")
                            
                            Text(statistics.rating.average?.clean() ?? statistics.rating.bayesian.clean())
                        }
                        
                        HStack(alignment: .top, spacing: 0) {
                            Image(systemName: "bookmark.fill")
                            
                            Text(statistics.follows.abbreviation)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .font(.subheadline)
                }
                
                descriptionSection
                
                tagsSection
            }
        }
    }
    
    private var descriptionSection: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                Text("Description")
                    .font(.headline)
                    .fontWeight(.black)
                    .padding()
                
                Divider()
                
                Text(LocalizedStringKey(viewStore.manga.description ?? "No description"))
                    .padding()
            }
        }
    }
    
    private var tagsSection: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.black)
                    .padding()
                
                Divider()
                
                GridChipsView(
                    viewStore.manga.attributes.tags,
                    width: UIScreen.main.bounds.width
                ) { tag in
                    Text(tag.name.capitalized)
                        .font(.callout)
                        .lineLimit(1)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.theme.darkGray)
                        .cornerRadius(10)
                }
                .padding()
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
                if isViewScrolledDown {
                    backButton
                }
                
                ForEach(MangaViewState.SelectedTab.allCases) { tab in
                    makeSectionFor(tab: tab)
                }
            }
            .animation(.easeInOut, value: isViewScrolledDown)
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
    
    @ViewBuilder private func makeSectionFor(tab: MangaViewState.SelectedTab) -> some View {
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
