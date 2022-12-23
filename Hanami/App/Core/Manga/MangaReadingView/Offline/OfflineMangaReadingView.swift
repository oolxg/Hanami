//
//  OfflineMangaReadingView.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import SwiftUI
import ComposableArchitecture
import NukeUI

struct OfflineMangaReadingView: View {
    let store: StoreOf<OfflineMangaReadingFeature>
    let blurRadius: CGFloat
    @State private var shouldShowNavBar = true
    // `mainBlockOpacity` for fixing UI bug on changing chapters(n -> n+1)
    @State private var mainBlockOpacity = 1.0
    
    private struct ViewState: Equatable {
        let chapterIndex: Double?
        let chapterID: UUID
        let pagesCount: Int
        let cachedPagesPaths: [URL?]
        let chapterIndexes: [Double]
        let pageIndex: Int
        let pageIndexToDisplay: Int?
        let mostLeftPageIndex: Int
        let mostRightPageIndex: Int
        let isReadingFormatVeritcal: Bool
        
        init(state: OfflineMangaReadingFeature.State) {
            chapterIndex = state.chapter.attributes.chapterIndex
            chapterID = state.chapter.id
            pagesCount = state.pagesCount
            chapterIndexes = state.sameScanlationGroupChapters.compactMap(\.attributes.chapterIndex)
            cachedPagesPaths = state.cachedPagesPaths
            pageIndex = state.pageIndex
            pageIndexToDisplay = state.pageIndexToDisplay
            mostLeftPageIndex = state.mostLeftPageIndex
            mostRightPageIndex = state.mostRightPageIndex
            isReadingFormatVeritcal = state.readingFormat == .vertical
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ZStack {
                if viewStore.isReadingFormatVeritcal {
                    verticalReader
                } else {
                    horizontalReader
                        .gesture(swipeGesture)
                }
            }
            .onChange(of: viewStore.chapterID) { _ in
                mainBlockOpacity = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    mainBlockOpacity = 1
                }
            }
        }
        .background(Color.theme.background)
        .overlay(navigationBlock)
        .navigationBarHidden(true)
        .gesture(tapGesture)
        .autoBlur(radius: blurRadius)
    }
}

extension OfflineMangaReadingView {
    private var verticalReader: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if !viewStore.cachedPagesPaths.isEmpty {
                VerticalReaderView(pagesURLs: viewStore.cachedPagesPaths)
            } else {
                Color.theme.background.frame(maxHeight: .infinity)
            }
        }
    }
    
    @MainActor private var horizontalReader: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            TabView(
                selection: viewStore.binding(
                    get: \.pageIndex,
                    send: OfflineMangaReadingFeature.Action.currentPageIndexChanged
                )
            ) {
                Color.clear
                    .tag(viewStore.mostLeftPageIndex)
                
                ForEach(viewStore.cachedPagesPaths.indices, id: \.self) { pagePathIndex in
                    ZoomableScrollView {
                        LazyImage(url: viewStore.cachedPagesPaths[pagePathIndex]) { state in
                            if let image = state.image {
                                image.resizingMode(.aspectFit)
                            } else if state.isLoading || state.error != nil {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .tint(.theme.accent)
                            }
                        }
                    }
                }
                .opacity(mainBlockOpacity)
                
                Color.clear
                    .tag(viewStore.mostRightPageIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
    
    private var navigationBlock: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if shouldShowNavBar {
                VStack {
                    ZStack {
                        Color.theme.background
                            .ignoresSafeArea(.all, edges: .top)
                        
                        HStack(spacing: 15) {
                            backButton
                                .padding(.horizontal)
                            
                            Spacer()
                            
                            VStack {
                                if let chapterIndex = viewStore.chapterIndex {
                                    Text("Chapter \(chapterIndex.clean())")
                                }
                                
                                if let pageIndex = viewStore.pageIndexToDisplay {
                                    Text("\(pageIndex)/\(viewStore.pagesCount)")
                                }
                            }
                            .font(.callout)
                            .padding(.horizontal)
                            .animation(.linear, value: viewStore.pagesCount)
                            .animation(.linear, value: viewStore.chapterIndex)

                            Spacer()
                            
                            // to align VStack in center
                            backButton
                                .padding(.horizontal)
                                .opacity(0)
                                .disabled(true)
                        }
                    }
                    .frame(height: 60)

                    Spacer()
                    
                    chaptersCarousel
                }
            }
        }
    }
    
    private var chaptersCarousel: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    LazyHStack(spacing: 3) {
                        Color.clear.frame(width: 10)
                        
                        ForEach(viewStore.chapterIndexes, id: \.self) { chapterIndex in
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewStore.chapterIndex == chapterIndex ? Color.theme.accent : .theme.foreground)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.theme.background)
                                )
                                .frame(width: 50, height: 50)
                                .overlay { Text(chapterIndex.clean()) }
                                .id(chapterIndex)
                                .onTapGesture {
                                    viewStore.send(.chapterCarouselButtonTapped(newChapterIndex: chapterIndex))
                                }
                        }
                        
                        Color.clear.frame(width: 10)
                    }
                    .onChange(of: viewStore.chapterIndexes.isEmpty) { _ in
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(viewStore.chapterIndex)
                        }
                    }
                    .onAppear {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(viewStore.chapterIndex)
                        }
                    }
                }
            }
            .frame(height: 60)
        }
    }
    
    // MARK: - Gestures
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 100, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height > 100 {
                    ViewStore(store).send(.userLeftMangaReadingView)
                }
            }
    }
    
    private var tapGesture: some Gesture {
        TapGesture().onEnded {
            withAnimation(.linear) {
                shouldShowNavBar.toggle()
            }
        }
    }
    
    private var backButton: some View {
        Button {
            ViewStore(store).send(.userLeftMangaReadingView)
        } label: {
            Image(systemName: "xmark")
                .font(.title3)
                .foregroundColor(.theme.foreground)
                .padding(.vertical)
        }
    }
}
