//
//  PagesView.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/07/2022.
//

import SwiftUI
import ComposableArchitecture

struct PagesView: View {
    let store: Store<PagesState, PageAction>
    
    var body: some View {
        VStack {
            ForEachStore(
                store.scope(
                    state: \.volumeTabStateToBeShown, action: PageAction.volumeTabAction)
            ) { voluteTabStore in
                VolumeTabView(store: voluteTabStore)
            }
            .transition(.opacity)
            
            footer
        }
    }
}

struct PagesView_Previews: PreviewProvider {
    static var previews: some View {
        PagesView(
            store: .init(
                initialState: .init(mangaVolumes: [], chaptersPerPage: 0),
                reducer: pagesReducer,
                environment: .init(
                    mangaClient: .live,
                    databaseClient: .live
                )
            )
        )
    }
}

extension PagesView {
    private var footer: some View {
        WithViewStore(store) { viewStore in
            HStack {
                Button {
                    viewStore.send(.userTappedPreviousPageButton)
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .disabled(viewStore.currentPage == 0)
                .opacity(viewStore.currentPage != 0 ? 1 : 0)
                .animation(.linear, value: viewStore.currentPage != 0)
                
                makePageLabel(for: 1)
                    .animation(.linear, value: viewStore.currentPage)
                    .opacity(viewStore.currentPage != 0 ? 1 : 0)
                    .disabled(viewStore.currentPage == 0)
                    .onTapGesture {
                        viewStore.send(.userTappedOnFirstPageButton)
                    }
                
                makePageLabel(for: viewStore.currentPage + 1, bgColor: .theme.accent)
                    .animation(.linear, value: viewStore.currentPage)
                
                makePageLabel(for: viewStore.pagesCount)
                    .animation(.linear, value: viewStore.currentPage)
                    .opacity(viewStore.currentPage + 1 != viewStore.pagesCount ? 1 : 0)
                    .disabled(viewStore.currentPage + 1 == viewStore.pagesCount)
                    .onTapGesture {
                        viewStore.send(.userTappenOnLastPageButton)
                    }
                
                Button {
                    viewStore.send(.userTappedNextPageButton)
                } label: {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .disabled(viewStore.currentPage + 1 == viewStore.pagesCount)
                .opacity(viewStore.currentPage + 1 != viewStore.pagesCount ? 1 : 0)
                .animation(.linear, value: viewStore.currentPage + 1 != viewStore.pagesCount)
            }
        }
        .padding(.bottom, 5)
    }
    
    private func makePageLabel(for pageIndex: Int, bgColor: Color = .theme.darkGray) -> some View {
        Text("\(pageIndex)")
            .foregroundColor(.white)
            .frame(width: 20, height: 20, alignment: .center)
            .padding()
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
