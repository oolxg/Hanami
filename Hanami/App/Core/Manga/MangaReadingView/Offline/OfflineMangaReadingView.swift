//
//  OfflineMangaReadingView.swift
//  Smuggler
//
//  Created by mk.pwnz on 23/08/2022.
//

import SwiftUI
import ComposableArchitecture

struct OfflineMangaReadingView: View {
    private let store: Store<OfflineMangaReadingViewState, OfflineMangaReadingViewAction>
    private let viewStore: ViewStore<OfflineMangaReadingViewState, OfflineMangaReadingViewAction>
    @State private var shouldShowNavBar = true
    @State private var currentPageIndex = 0
    
    init(store: Store<OfflineMangaReadingViewState, OfflineMangaReadingViewAction>) {
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

                WithViewStore(store) { viewStore in
                    TabView(selection: $currentPageIndex) {
                        Color.clear
                            .tag(-1)
                        
                        ForEach(viewStore.cachedPages.indices, id: \.self) { pageIndex in
                            ZoomableScrollView {
                                if let page = viewStore.cachedPages[pageIndex] {
                                    Image(uiImage: page)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    ProgressView()
                                }
                            }
                        }
                        
                        Color.clear
                            .tag(viewStore.pagesCount)
                    }
                }
        
                .zIndex(0)
            }
            .frame(height: UIScreen.main.bounds.height * 1.05)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationBarHidden(true)
        .gesture(tapGesture)
        .gesture(swipeGesture)
        .onChange(of: viewStore.chapter.id) { _ in
            if viewStore.shouldSendUserToTheLastPage {
                currentPageIndex = viewStore.pagesCount - 1
            } else {
                currentPageIndex = 0
            }
        }
        .onChange(of: currentPageIndex) {
            viewStore.send(.userChangedPage(newPageIndex: $0))
        }
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
                    if let chapterIndex = viewStore.chapter.attributes.chapterIndex {
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
}
