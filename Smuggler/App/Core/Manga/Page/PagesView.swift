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
        LazyVStack {
            ForEachStore(
                store.scope(state: \.volumeTabStateToBeShown, action: PageAction.volumeTabAction),
                content: VolumeTabView.init
            )
            .transition(.opacity)

            footer
        }
        .frame(maxHeight: .infinity)
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
                    viewStore.send(.changePage(newPageIndex: viewStore.currentPage - 1), animation: .linear)
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 5)
                .opacity(viewStore.currentPage != 0 ? 1 : 0)
                
                makePageLabel(for: 1)
                    .opacity(viewStore.currentPage != 0 ? 1 : 0)
                    .disabled(viewStore.currentPage == 0)
                
                if viewStore.currentPage - 1 > 0 {
                    Text("...")
                        .font(.headline)
                }
                
                if viewStore.currentPage > 1 {
                    makePageLabel(for: viewStore.currentPage, bgColor: .theme.darkGray)
                }
                
                makePageLabel(for: viewStore.currentPage + 1, bgColor: .theme.accent)
                
                if viewStore.currentPage + 2 < viewStore.pagesCount {
                    makePageLabel(for: viewStore.currentPage + 2, bgColor: .theme.darkGray)
                }
                
                if viewStore.currentPage + 2 < viewStore.pagesCount - 1 {
                    Text("...")
                        .font(.headline)
                }
                
                makePageLabel(for: viewStore.pagesCount)
                    .opacity(viewStore.currentPage + 1 != viewStore.pagesCount ? 1 : 0)
                
                Button {
                    viewStore.send(.changePage(newPageIndex: viewStore.currentPage + 1), animation: .linear)
                } label: {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 5)
                .opacity(viewStore.currentPage + 1 != viewStore.pagesCount ? 1 : 0)
            }
        }
        .padding(.bottom, 5)
    }
    
    private func makePageLabel(for pageIndex: Int, bgColor: Color = .theme.darkGray) -> some View {
        WithViewStore(store) { viewStore in
            Text("\(pageIndex)")
                .foregroundColor(.white)
                .font(viewStore.currentPage == pageIndex - 1 ? .headline.bold() : .headline)
                .frame(width: 20, height: 20, alignment: .center)
                .padding(7)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onTapGesture {
                    viewStore.send(.changePage(newPageIndex: pageIndex - 1), animation: .linear)
                }
        }
    }
}
