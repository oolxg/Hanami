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
    @State private var currentPageIndex = 0
    
    private struct ViewState: Equatable {
        let chapterIndex: Double?
        let chapterID: UUID
        let pagesCount: Int
        let cachedPagesPaths: [URL?]
        let startFromLastPage: Bool
        let chapterIndexes: [Double]
        
        init(state: OfflineMangaReadingFeature.State) {
            chapterIndex = state.chapter.attributes.chapterIndex
            chapterID = state.chapter.id
            pagesCount = state.pagesCount
            startFromLastPage = state.startFromLastPage
            chapterIndexes = state.sameScanlationGroupChapters.compactMap(\.attributes.chapterIndex)
            cachedPagesPaths = state.cachedPagesPaths
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            TabView(selection: $currentPageIndex) {
                Color.clear
                    .tag(-1)
                
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
                    .tag(viewStore.pagesCount)
            }
            .overlay(navigationBlock)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationBarHidden(true)
            .gesture(tapGesture)
            .gesture(swipeGesture)
            .onChange(of: viewStore.chapterID) { _ in
                mainBlockOpacity = 0
                
                if viewStore.startFromLastPage {
                    currentPageIndex = viewStore.pagesCount - 1
                } else {
                    currentPageIndex = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    mainBlockOpacity = 1
                }
            }
            .onChange(of: currentPageIndex) {
                viewStore.send(.currentPageIndexChanged(newPageIndex: $0))
            }
            .autoBlur(radius: blurRadius)
        }
    }
    
    private var navigationBlock: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if shouldShowNavBar {
                VStack {
                    ZStack {
                        Color.black
                            .ignoresSafeArea(.all, edges: .top)
                        
                        HStack(spacing: 15) {
                            backButton
                                .padding(.horizontal)
                            
                            Spacer()
                            
                            VStack {
                                if let chapterIndex = viewStore.chapterIndex {
                                    Text("Chapter \(chapterIndex.clean())")
                                }
                                
                                if let pagesCount = viewStore.pagesCount,
                                   currentPageIndex < pagesCount && currentPageIndex + 1 > 0 {
                                    Text("\(currentPageIndex + 1)/\(pagesCount)")
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
                                .stroke(viewStore.chapterIndex == chapterIndex ? Color.theme.accent : .white)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.black)
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
                .foregroundColor(.white)
                .padding(.vertical)
        }
    }
}
