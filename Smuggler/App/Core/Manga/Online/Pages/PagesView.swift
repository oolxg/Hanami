//
//  PagesView.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/07/2022.
//

import SwiftUI
import ComposableArchitecture

struct PagesView: View {
    let store: Store<PagesState, PagesAction>
    private let viewStore: ViewStore<PagesState, PagesAction>
    
    init(store: Store<PagesState, PagesAction>) {
        self.store = store
        viewStore = ViewStore(store)
    }
    
    var body: some View {
        LazyVStack {
            pages

            footer.transition(.identity)
        }
        .animation(.linear, value: viewStore.currentPageIndex)
    }
}

struct PagesView_Previews: PreviewProvider {
    static var previews: some View {
        PagesView(
            store: .init(
                initialState: .init(mangaVolumes: [], chaptersPerPage: 1),
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
    private var pages: some View {
        ForEachStore(
            store.scope(state: \.volumeTabStatesOnCurrentPage, action: PagesAction.volumeTabAction),
            content: VolumeTabView.init
        )
        .disabled(viewStore.lockPage)
    }

    private var footer: some View {
        HStack {
            Button {
                viewStore.send(.changePage(newPageIndex: viewStore.currentPageIndex - 1))
            } label: {
                Image(systemName: "arrow.left")
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 5)
            .opacity(viewStore.currentPageIndex != 0 ? 1 : 0)
            
            makePageLabel(for: 1)
                .opacity(viewStore.currentPageIndex != 0 ? 1 : 0)
                .disabled(viewStore.currentPageIndex == 0)
            
            Text("...")
                .font(.headline)
                .opacity(viewStore.currentPageIndex - 2 > 0 ? 1 : 0)
            
            makePageLabel(for: viewStore.currentPageIndex, bgColor: .theme.darkGray)
                .opacity(viewStore.currentPageIndex > 1 ? 1 : 0)
            
            pagesPicker
            
            makePageLabel(for: viewStore.currentPageIndex + 2, bgColor: .theme.darkGray)
                .opacity(viewStore.currentPageIndex + 2 < viewStore.pagesCount ? 1 : 0)
            
            Text("...")
                .font(.headline)
                .opacity(viewStore.currentPageIndex + 2 < viewStore.pagesCount - 1 ? 1 : 0)
            
            makePageLabel(for: viewStore.pagesCount)
                .opacity(viewStore.currentPageIndex + 1 != viewStore.pagesCount ? 1 : 0)
            
            Button {
                viewStore.send(.changePage(newPageIndex: viewStore.currentPageIndex + 1))
            } label: {
                Image(systemName: "arrow.right")
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 5)
            .opacity(viewStore.currentPageIndex + 1 != viewStore.pagesCount ? 1 : 0)
        }
        .padding(.bottom, 5)
    }
    
    private var pagesPicker: some View {
        Menu {
            Picker(
                selection: viewStore.binding(
                    get: \.currentPageIndex,
                    send: PagesAction.changePage
                )
            ) {
                ForEach(0..<viewStore.pagesCount, id: \.self) { pageIndex in
                    Text("Page \(pageIndex + 1)")
                }
            } label: { EmptyView() }
        } label: {
            Text("\(viewStore.currentPageIndex + 1)")
                .foregroundColor(.white)
                .font(.subheadline)
                .frame(width: 30, height: 30, alignment: .center)
                .padding(7)
                .background(Color.theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    private func makePageLabel(for pageIndex: Int, bgColor: Color = .theme.darkGray) -> some View {
        Text("\(pageIndex)")
            .foregroundColor(.white)
            .font(.subheadline)
            .frame(width: 25, height: 25, alignment: .center)
            .padding(7)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                viewStore.send(.changePage(newPageIndex: pageIndex - 1))
            }
    }
}
