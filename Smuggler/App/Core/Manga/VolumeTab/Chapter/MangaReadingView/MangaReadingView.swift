//
//  MangaReadingView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import SwiftUI
import ComposableArchitecture

struct MangaReadingView: View {
    let store: Store<MangaReadingViewState, MangaReadingViewAction>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                ScrollView {
                    ForEach(viewStore.images.compactMap { $0 }, id: \.self) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width)
                    }
                }
            }
            .onAppear {
                viewStore.send(.userStartedReadingChapter)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("next") {
                        viewStore.send(.userTappedOnNextChapterButton)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("prev") {
                        viewStore.send(.userTappedOnPreviousChapterButton)
                    }
                }
            }
        }
    }
}
