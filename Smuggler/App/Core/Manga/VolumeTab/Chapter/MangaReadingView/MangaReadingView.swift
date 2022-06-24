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
    
    var body: some View {
        WithViewStore(store) { viewStore in
            TabView {
                ForEach(0..<viewStore.images.count, id: \.self) { imageIndex in
                    ZStack {
                        if let image = viewStore.images[imageIndex] {
                            ZoomableScrollView {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .animation(.linear, value: viewStore.images)
                                    .onAppear {
                                        viewStore.send(.imageAppear(index: imageIndex))
                                    }
                            }
                        } else {
                            ProgressView("Loading...")
                                .progressViewStyle(RingProgressViewStyle())
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("\(imageIndex + 1)/\(viewStore.images.count)")
                }
            }
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .navigationBarBackButtonHidden(true)
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
