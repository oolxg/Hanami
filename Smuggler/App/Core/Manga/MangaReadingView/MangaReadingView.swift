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
    @State private var shouldHideNavigationBar = true
    
    var body: some View {
        WithViewStore(store) { viewStore in
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    if !shouldHideNavigationBar {
                        ZStack {
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
                        .frame(height: geo.size.height * 0.05)
                        .zIndex(1)
                    }
                    
                    ZStack {
                        if viewStore.pagesInfo == nil {
                            ActivityIndicator()
                                .frame(width: 120)
                        } else {
                            pagesSlider
                                .frame(height: geo.size.height)
                        }
                    }
                    .transition(.opacity)
                    .animation(.linear, value: viewStore.pagesInfo == nil)
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height
                    )
                }
                .zIndex(0)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .navigationBarHidden(true)
            .onAppear {
                viewStore.send(.userStartedReadingChapter)
            }
            .onDisappear {
                viewStore.send(.userLeftMangaReadingView)
            }
            .onTapGesture {
                withAnimation(.linear) {
                    shouldHideNavigationBar.toggle()
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
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("\(pageIndex + 1)/\(viewStore.pages.count)")
                }
            }
        }
    }
}
