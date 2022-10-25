//
//  AuthorView.swift
//  Hanami
//
//  Created by Oleg on 21/10/2022.
//

import SwiftUI
import ComposableArchitecture

struct AuthorView: View {
    let store: StoreOf<AuthorFeature>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        WithViewStore(store) { viewStore in
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
                    .animation(.linear, value: viewStore.author == nil)
                }
                .navigationTitle(viewStore.author?.attributes.name ?? "Loading...")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { backButton }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

#if DEBUG
struct AuthorView_Previews: PreviewProvider {
    static var previews: some View {
        AuthorView(
            store: .init(
                initialState: .init(authorID: UUID()),
                reducer: AuthorFeature()._printChanges()
            )
        )
    }
}
#endif

extension AuthorView {
    private var backButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                self.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.vertical)
            }
        }
    }
    
    private var biograpySection: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                if let bio = viewStore.author?.attributes.biography?.languageInfo?.language {
                    Text("Biography")
                        .font(.headline)
                        .fontWeight(.black)
                    
                    Text(LocalizedStringKey(bio.trimmingCharacters(in: .whitespacesAndNewlines)))
                        .padding(.horizontal, 10)
                    
                    Divider()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
        }
    }
    
    private var mangaList: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                Text("Works (\(viewStore.mangaThumbnailStates.count))")
                    .font(.headline)
                    .fontWeight(.black)
                    .padding(.bottom, 10)
                    .padding(.leading, 10)
                
                ForEachStore(
                    store.scope(
                        state: \.mangaThumbnailStates,
                        action: AuthorFeature.Action.mangaThumbnailAction
                    )) { thumbnailStore in
                        MangaThumbnailView(store: thumbnailStore)
                            .padding(5)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
