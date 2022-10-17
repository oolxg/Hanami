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
    @State private var shouldShowNavBar = true
    @State private var currentPageIndex = 0
    
    private struct ViewState: Equatable {
        let pagesURLs: [URL]
        let pagesCount: Int?
        let startFromLastPage: Bool
        let chapterIndex: Double?
        let chapterIndexes: [Double]
        let afterLastPageIndex: Int
        
        init(state: OnlineMangaReadingFeature.State) {
            pagesURLs = state.pagesInfo?.pagesURLs ?? []
            pagesCount = state.pagesCount
            startFromLastPage = state.startFromLastPage
            chapterIndex = state.chapterIndex
            chapterIndexes = state.sameScanlationGroupChapters.compactMap(\.chapterIndex)
            afterLastPageIndex = state.afterLastPageIndex
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            TabView(selection: $currentPageIndex) {
                Color.clear
                    .tag(-1)
                
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
                
                Color.clear
                    .tag(viewStore.afterLastPageIndex)
            }
            .onChange(of: viewStore.pagesCount) { _ in
                if viewStore.startFromLastPage && viewStore.pagesCount != nil {
                    currentPageIndex = viewStore.pagesCount! - 1
                } else {
                    currentPageIndex = 0
                }
            }
            .onChange(of: currentPageIndex) {
                viewStore.send(.userChangedPage(newPageIndex: $0))
            }
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
    }
}

extension OnlineMangaReadingView {
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
                                   currentPageIndex != viewStore.afterLastPageIndex,
                                   currentPageIndex + 1 > 0 {
                                    Text("\(currentPageIndex + 1)/\(pagesCount)")
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
                                .stroke(viewStore.chapterIndex == chapterIndex ? Color.theme.accent : .white)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.black)
                                )
                                .frame(width: 50, height: 50)
                                .overlay(Text(chapterIndex.clean()))
                                .id(chapterIndex)
                                .onTapGesture {
                                    viewStore.send(.changeChapter(newChapterIndex: chapterIndex))
                                }
                        }
                        
                        Color.clear.frame(width: 10)
                    }
                    .onAppear {
                        proxy.scrollTo(viewStore.chapterIndex)
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
            )
        )
    }
}
