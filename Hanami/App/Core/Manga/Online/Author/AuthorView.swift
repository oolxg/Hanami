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
                        VStack {
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
                }
                .navigationTitle(viewStore.author.attributes.name)
                .navigationBarTitleDisplayMode(.large)
                .navigationBarBackButtonHidden(true)
                .toolbar {
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
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

struct AuthorView_Previews: PreviewProvider {
    static var previews: some View {
        AuthorView(
            store: .init(
                initialState: .init(author: dev.author),
                reducer: AuthorFeature()._printChanges()
            )
        )
    }
}
