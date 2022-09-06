//
//  OnlineMangaReadingView.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct OnlineMangaReadingView: View {
    private let store: Store<OnlineMangaReadingViewState, OnlineMangaReadingViewAction>
    private let viewStore: ViewStore<OnlineMangaReadingViewState, OnlineMangaReadingViewAction>
    @State private var shouldShowNavBar = true
    @State private var currentPageIndex = 0
    
    init(store: Store<OnlineMangaReadingViewState, OnlineMangaReadingViewAction>) {
        self.store = store
        viewStore = ViewStore(store)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if shouldShowNavBar {
                    navigationBar
                        .frame(height: geo.size.height * 0.05)
                        .zIndex(1)
                }
                
                readingContent
                    .zIndex(0)
            }
            .frame(height: UIScreen.main.bounds.height * 1.05)
        }
        .navigationBarHidden(true)
        .gesture(tapGesture)
        .gesture(swipeGesture)
        .onChange(of: viewStore.pagesInfo) { _ in
            if viewStore.shouldSendUserToTheLastPage && viewStore.pagesCount != nil {
                currentPageIndex = viewStore.pagesCount! - 1
            } else {
                currentPageIndex = 0
            }
        }
        .onChange(of: currentPageIndex) {
            viewStore.send(.userChangedPage(newPageIndex: $0))
        }
    }
}

extension OnlineMangaReadingView {
    private var backButton: some View {
        Button {
            viewStore.send(.userLeftMangaReadingView)
        } label: {
            Image(systemName: "xmark")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.vertical)
        }
    }
    
    private var readingContent: some View {
        ZStack {
            WithViewStore(store) { viewStore in
                if let urls = viewStore.pagesInfo?.dataSaverURLs {
                    TabView(selection: $currentPageIndex) {
                        Color.clear
                            .tag(-1)
                        
                        ForEach(urls.indices, id: \.self) { pageIndex in
                            ZoomableScrollView {
                                KFImage.url(
                                    urls[pageIndex],
                                    cacheKey: urls[pageIndex].absoluteString
                                )
                                .retry(maxCount: 3)
                                .placeholder {
                                    ProgressView()
                                        .frame(width: 120)
                                }
                                .resizable()
                                .scaledToFit()
                            }
                        }
                        
                        Color.clear
                            .tag(urls.count)
                    }
                } else {
                    TabView {
                        ProgressView()
                            .frame(width: 120)
                    }
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .transition(.opacity)
    }
    
    private var navigationBar: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            HStack(spacing: 15) {
                backButton
                    .padding(.horizontal)
                
                Spacer()
                
                VStack {
                    if let chapterIndex = viewStore.chapterIndex {
                        Text("Chapter \(chapterIndex.clean())")
                    }
                    
                    if let pagesCount = viewStore.pagesCount, currentPageIndex < pagesCount, currentPageIndex + 1 > 0 {
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
    }
    
        // MARK: - Gestures
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 100, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height > 100 {
                    viewStore.send(.userLeftMangaReadingView)
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
                reducer: onlineMangaReadingViewReducer,
                environment: .init(
                    databaseClient: .live,
                    cacheClient: .live,
                    imageClient: .live,
                    mangaClient: .live,
                    hudClient: .live
                )
            )
        )
    }
}
