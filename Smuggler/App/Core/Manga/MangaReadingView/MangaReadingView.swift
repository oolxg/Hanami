//
//  MangaReadingView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct MangaReadingView: View {
    @Environment(\.presentationMode) private var presentationMode
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
                self.presentationMode.wrappedValue.dismiss()
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
                if let pagesInfo = viewStore.pagesInfo {
                    ForEach(0..<pagesInfo.dataSaverURLs.count, id: \.self) { pageIndex in
                        ZoomableScrollView {
                            KFImage.url(
                                pagesInfo.dataSaverURLs[pageIndex],
                                cacheKey: pagesInfo.dataSaverURLs[pageIndex].absoluteString
                            )
                                .placeholder {
                                    ActivityIndicator()
                                        .frame(width: 120)
                                }
                                .resizable()
                                .scaledToFit()
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}
