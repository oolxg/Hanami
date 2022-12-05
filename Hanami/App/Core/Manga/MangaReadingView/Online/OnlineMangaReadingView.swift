//
//  OnlineMangaReadingView.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import SwiftUI
import ComposableArchitecture
import NukeUI

struct OnlineMangaReadingView: View {
    let store: StoreOf<OnlineMangaReadingFeature>
    let blurRadius: CGFloat
    @State private var shouldShowNavBar = true
    
    private struct ViewState: Equatable {
        let pagesURLs: [URL]
        let pagesCount: Int?
        let startFromLastPage: Bool
        let chapterIndex: Double?
        let chapterIndexes: [Double]
        let mostRightPageIndex: Int
        let mostLeftPageIndex: Int
        let pageIndex: Int
        let pageIndexToDisplay: Int?
        
        init(state: OnlineMangaReadingFeature.State) {
            pagesURLs = state.pagesURLs ?? []
            pagesCount = state.pagesCount
            startFromLastPage = state.startFromLastPage
            chapterIndex = state.chapterIndex
            chapterIndexes = state.sameScanlationGroupChapters.compactMap(\.chapterIndex)
            mostRightPageIndex = state.mostRightPageIndex
            mostLeftPageIndex = state.mostLeftPageIndex
            pageIndex = state.pageIndex
            pageIndexToDisplay = state.pageIndexToDisplay
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            TabView(
                selection: viewStore.binding(
                    get: \.pageIndex,
                    send: OnlineMangaReadingFeature.Action.currentPageIndexChanged
                )
            ) {
                Color.clear
                    .tag(viewStore.mostLeftPageIndex)
                
                ForEach(viewStore.pagesURLs.indices, id: \.self) { pageIndex in
                    ZoomableScrollView {
                        LazyImage(url: viewStore.pagesURLs[pageIndex]) { state in
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
                .opacity(viewStore.pagesCount != nil ? 1 : 0)
                
                Color.clear
                    .tag(viewStore.mostRightPageIndex)
            }
            .background(Color.theme.background)
            .overlay {
                if viewStore.pagesURLs.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .tint(.theme.accent)
                }
            }
        }
        .gesture(tapGesture)
        .gesture(swipeGesture)
        .overlay(navigationBlock)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationBarHidden(true)
        .autoBlur(radius: blurRadius)
    }
}

extension OnlineMangaReadingView {
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
                                
                                if let pagesCount = viewStore.pagesCount, let pageIndex = viewStore.pageIndexToDisplay {
                                    Text("\(pageIndex)/\(pagesCount)")
                                }
                            }
                            .font(.callout)
                            .padding(.horizontal)
                            .animation(.linear, value: viewStore.pagesCount)
                            
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
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 3) {
                        Color.clear.frame(width: 10)
                        
                        ForEach(viewStore.chapterIndexes, id: \.self) { chapterIndex in
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewStore.chapterIndex == chapterIndex ? Color.theme.accent : .theme.foreground)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.theme.background)
                                )
                                .frame(width: 50, height: 50)
                                .overlay(Text(chapterIndex.clean()))
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
}

#if DEBUG
struct OnlineMangaReadingView_Previews: PreviewProvider {
    static var previews: some View {
        OnlineMangaReadingView(
            store: .init(
                initialState: .init(
                    mangaID: .init(),
                    chapterID: .init(),
                    chapterIndex: 0,
                    scanlationGroupID: .init(),
                    translatedLanguage: ""
                ),
                reducer: OnlineMangaReadingFeature()._printChanges()
            ),
            blurRadius: 0
        )
    }
}
#endif
