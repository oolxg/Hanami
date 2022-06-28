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
    @State private var shouldHideNavigationBar = false
    
    var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                if viewStore.pagesInfo == nil {
                    ActivityIndicator()
                } else {
                    pagesSlider
                }
            }
            .transition(.opacity)
            .animation(.linear, value: viewStore.pagesInfo == nil)
            .frame(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(shouldHideNavigationBar)
            .onAppear {
                viewStore.send(.userStartedReadingChapter)
            }
            .onDisappear {
                viewStore.send(.userLeftMangaReadingView)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("prev") {
                        viewStore.send(.userTappedOnPreviousChapterButton)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("next") {
                        viewStore.send(.userTappedOnNextChapterButton)
                    }
                }
            }
        }
        .onTapGesture {
            withAnimation(.linear) {
                shouldHideNavigationBar.toggle()
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
