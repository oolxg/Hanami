//
//  MangaReadingView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import SwiftUI
import ComposableArchitecture


struct MangaReadingView: View {
    @Environment(\.dismiss) private var dismiss
    let store: Store<MangaReadingViewState, MangaReadingViewAction>
    @State private var shouldShowNavBar = true
    
    var body: some View {
        WithViewStore(store) { viewStore in
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
                .frame(height: UIScreen.main.bounds.height)
            }
            .navigationBarHidden(true)
            .onAppear {
                viewStore.send(.userStartedReadingChapter)
            }
            .onDisappear {
                viewStore.send(.userLeftMangaReadingView)
            }
            .onTapGesture {
                withAnimation(.linear) {
                    shouldShowNavBar.toggle()
                }
            }
        }
    }
}

extension MangaReadingView {
    private var backButton: some View {
        WithViewStore(store) { viewStore in
            Button {
                viewStore.send(.userLeftMangaReadingView)
                self.dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .foregroundColor(.white)
                    .padding(.vertical)
            }
        }
    }
}

extension MangaReadingView {
    private var readingContent: some View {
        WithViewStore(store) { viewStore in
            if viewStore.pagesInfo == nil {
                ActivityIndicator()
                    .frame(width: 120)
            } else {
                pagesSlider
            }
        }
        .transition(.opacity)
    }
    
    private var navigationBar: some View {
        ZStack {
            WithViewStore(store) { viewStore in
                Color.black
                    .ignoresSafeArea()
                
                HStack(spacing: 15) {
                    backButton
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("prev") {
                        viewStore.send(.userTappedOnPreviousChapterButton)
                    }
                    
                    Button("next") {
                        viewStore.send(.userTappedOnNextChapterButton)
                    }
                    .padding(.trailing)
                }
            }
        }
    }
    
    private var pagesSlider: some View {
        WithViewStore(store) { viewStore in
            TabView {
                ForEach(0..<viewStore.pages.count, id: \.self) { pageIndex in
                    ZStack {
                        if let page = viewStore.pages[pageIndex] {
                            ZoomableScrollView {
                                Image(uiImage: page)
                                    .resizable()
                                    .scaledToFit()
                                    .animation(.linear, value: viewStore.pages)
                                    .onAppear {
                                        viewStore.send(.imageAppear(index: pageIndex))
                                    }
                            }
                        } else {
                            ActivityIndicator()
                                .frame(width: 120)
                                .onAppear {
                                    viewStore.send(.progressViewAppear(index: pageIndex))
                                }
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}
