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
                TabView(selection: viewStore.binding(\.$currentPage)) {
                    Color.clear
                        .tag(-1)
                    
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
                        .tag(pageIndex)
                    }
                    
                    Color.clear
                        .tag(urls.count)
                }
            } else {
                TabView {
                    ActivityIndicator()
                        .frame(width: 120)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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
                    
                    VStack {
                        if let chapterIndex = viewStore.chapterIndex {
                            Text("Chapter \(chapterIndex.clean())")
                        }
                        
                        if let pagesCount = viewStore.pagesInfo?.dataSaverURLs.count,
                           viewStore.currentPage < pagesCount && viewStore.currentPage + 1 > 0 {
                            Text("\(viewStore.currentPage + 1)/\(pagesCount)")
                        }
                    }
                    .font(.callout)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // to align VStack in center
                    backButton
                        .padding(.horizontal)
                        .opacity(0)
                        .disabled(true)
                }
            }
        }
    }
}
