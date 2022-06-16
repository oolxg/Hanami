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
            Text(viewStore.chapterID.uuidString)
                .onAppear {
                    viewStore.send(.onAppear)
                }
        }
    }
}
