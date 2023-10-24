//
//  AuthorView.swift
//  Hanami
//
//  Created by Oleg on 21/10/2022.
//

import SwiftUI
import ComposableArchitecture
import ModelKit

struct AuthorView: View {
    let store: StoreOf<AuthorFeature>
    let blurRadius: CGFloat
    @Environment(\.dismiss) private var dismiss
    
    private struct ViewState: Equatable {
        let author: Author?
        let authorTitlesCount: Int
        
        init(state: AuthorFeature.State) {
            author = state.author
            authorTitlesCount = state.mangaThumbnailStates.count
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            NavigationView {
                VStack {
                    Text("by oolxg")
                        .font(.caption2)
                        .frame(height: 0)
                        .foregroundColor(.clear)
                    
                    ScrollView {
                       biograpySection

                       mangaList
                    }
                    .animation(.linear, value: viewStore.author.isNil)
                }
                .navigationTitle(viewStore.author?.attributes.name ?? "Loading...")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { backButton }
            }
            .autoBlur(radius: blurRadius)
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

extension AuthorView {
    private var backButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                self.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.theme.foreground)
                    .padding(.vertical)
            }
        }
    }
    
    private var biograpySection: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                if let bio = viewStore.author?.attributes.biography?.availableText {
                    Text("Biography")
                        .font(.headline)
                        .fontWeight(.black)
                    
                    Text(LocalizedStringKey(bio))
                        .padding(.horizontal, 10)
                    
                    Divider()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
        }
    }
    
    private var mangaList: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading) {
                Text("Works (\(viewStore.authorTitlesCount))")
                    .font(.headline)
                    .fontWeight(.black)
                    .padding(.bottom, 10)
                    .padding(.leading, 10)
                
                ForEachStore(
                    store.scope(
                        state: \.mangaThumbnailStates,
                        action: AuthorFeature.Action.mangaThumbnailAction
                    )) { thumbnailStore in
                        MangaThumbnailView(
                            store: thumbnailStore,
                            blurRadius: blurRadius
                        )
                        .padding(5)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
