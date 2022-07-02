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
            if let urls = viewStore.pagesInfo?.dataSaverURLs {
                TabView {
                    ForEach(0..<urls.count, id: \.self) { pageIndex in
                        ZoomableScrollView {
                            KFImage.url(
                                urls[pageIndex],
                                cacheKey: urls[pageIndex].absoluteString
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
            } else {
                ActivityIndicator()
                    .frame(width: 120)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
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
}
