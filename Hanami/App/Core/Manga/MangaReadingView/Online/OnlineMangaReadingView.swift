//
//  OnlineMangaReadingView.swift
//  Hanami
//
//  Created by Oleg on 23/08/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher
import UIComponents

struct OnlineMangaReadingView: View {
    let store: StoreOf<OnlineMangaReadingFeature>
    let blurRadius: CGFloat
    @State private var showNavBar = true
    @State private var timer = Timer.publish(every: 4, on: .main, in: .default).autoconnect()
    
    private struct ViewState: Equatable {
        let pagesURLs: [URL]
        let pagesCount: Int?
        let chapterIndex: Double?
        let chapterIndexes: [Double]
        let mostRightPageIndex: Int
        let mostLeftPageIndex: Int
        let pageIndex: Int
        let pageIndexToDisplay: Int?
        let isReadingFormatVeritcal: Bool
        let chapterCachingProgress: Double?
        let isChapterCached: Bool
        
        init(state: OnlineMangaReadingFeature.State) {
            pagesURLs = state.pagesURLs ?? []
            pagesCount = state.pagesCount
            chapterIndex = state.chapterIndex
            chapterIndexes = state.sameScanlationGroupChapters.compactMap(\.index).removeDuplicates()
            mostRightPageIndex = state.mostRightPageIndex
            mostLeftPageIndex = state.mostLeftPageIndex
            pageIndex = state.pageIndex
            pageIndexToDisplay = state.pageIndexToDisplay
            isReadingFormatVeritcal = state.readingFormat == .vertical
            
            if let loader = state.chapterLoader, let total = loader.pagesCount {
                chapterCachingProgress = Double(loader.pagesFetched) / Double(total)
            } else {
                chapterCachingProgress = nil
            }
            
            isChapterCached = state.isChapterCached
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ZStack {
                if viewStore.isReadingFormatVeritcal {
                    verticalReader
                        .gesture(tapGesture)
                } else {
                    horizontalReader
                        .gesture(swipeGesture)
                        .gesture(longPressGesture)
                }
            }
            .overlay {
                if viewStore.pagesURLs.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .tint(.theme.accent)
                }
            }
        }
        .overlay(navigationBlock)
        .navigationBarHidden(true)
        .statusBarHidden(!showNavBar)
        .autoBlur(radius: blurRadius)
        .onReceive(timer) { _ in
            timer.upstream.connect().cancel()
            withAnimation(.linear) {
                showNavBar = false
            }
        }
    }
}

extension OnlineMangaReadingView {
    private var verticalReader: some View {
        WithViewStore(store, observe: \.pagesURLs) { viewStore in
            if let pagesURLs = viewStore.state {
                VerticalReaderView(pagesURLs: pagesURLs)
            } else {
                Color.theme.background.frame(maxHeight: .infinity)
            }
        }
    }
    
    private var horizontalReader: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            TabView(
                selection: viewStore.binding(
                    get: \.pageIndex,
                    send: OnlineMangaReadingFeature.Action.currentPageIndexChanged
                )
            ) {
                Color.clear
                    .tag(viewStore.mostLeftPageIndex)
                
                pagesList
                    .opacity(viewStore.pagesCount.isNil ? 0 : 1)
                
                Color.clear
                    .tag(viewStore.mostRightPageIndex)
            }
            .background(Color.theme.background)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
    }
    
    private var pagesList: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ForEach(viewStore.pagesURLs.indices, id: \.self) { pageIndex in
                ZoomableScrollView {
                    KFImage(viewStore.pagesURLs[pageIndex])
                        .placeholder { progress in
                            ProgressView(value: progress.fractionCompleted)
                                .defaultWithProgress()
                                .frame(width: 30, height: 30)
                        }
                        .resizable()
                        .scaledToFit()
                        .id(pageIndex)
                }
            }
        }
    }
    
    private var backButton: some View {
        Button {
            store.send(.userLeftMangaReadingView)
        } label: {
            Image(systemName: "xmark")
                .font(.title3)
                .foregroundColor(.theme.foreground)
        }
    }
    
    private var downloadButton: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            Button {
                viewStore.send(.downloadChapterButtonTapped)
            } label: {
                if viewStore.isChapterCached {
                    Image(systemName: "externaldrive.badge.checkmark")
                        .font(.title3)
                        .foregroundColor(.theme.green)
                } else if let progress = viewStore.chapterCachingProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(GaugeProgressStyle(strokeColor: .theme.accent))
                        .frame(width: 30, height: 30)
                        .overlay(alignment: .center) {
                            Image(systemName: "xmark")
                                .font(.subheadline)
                                .foregroundColor(.theme.red)
                        }
                        .onTapGesture {
                            viewStore.send(.cancelDownloadButtonTapped)
                        }
                } else {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.title3)
                        .foregroundColor(.theme.foreground)
                }
            }
        }
    }
    
    private var navigationBlock: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if showNavBar {
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
                            
                            downloadButton
                                .padding(.horizontal)
                        }
                    }
                    .frame(height: 40)
                    
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
                                    RoundedRectangle(cornerRadius: 6)
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
                            proxy.scrollTo(viewStore.chapterIndex, anchor: UnitPoint(x: 0.95, y: 0))
                        }
                    }
                    .onAppear {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(viewStore.chapterIndex, anchor: UnitPoint(x: 0.95, y: 0))
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
                    store.send(.userLeftMangaReadingView)
                }
            }
    }
    
    // Need tapGesture and longPressGesture separately for handling double tap within ZoomableScrollView
    // tapGesture used for vertical reading(longPressGesture blocks scroll) and tap longPressGesture
    private var tapGesture: some Gesture {
        TapGesture().onEnded {
            withAnimation(.linear) {
                showNavBar.toggle()
                
                if showNavBar {
                    timer = Timer.publish(every: 10, on: .main, in: .default).autoconnect()
                }
            }
        }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.1).onEnded { _ in
            withAnimation(.linear) {
                showNavBar.toggle()
                
                if showNavBar {
                    timer = Timer.publish(every: 10, on: .main, in: .default).autoconnect()
                }
            }
        }
    }
}
