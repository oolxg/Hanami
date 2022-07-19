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
            if viewStore.shouldShowNothingToReadMessage {
                emptyMangaMessageView
            } else {
                if viewStore.volumeTabStatesOnCurrentPage.isEmpty {
                    ProgressView()
                        .frame(width: 140, height: 140, alignment: .center)
                        .padding(.top, 150)
                        .transition(.opacity)
                } else {
                    pages
                    
                    footer.transition(.identity)
                }
            }
        }
        .animation(.linear, value: viewStore.currentPageIndex)
        .animation(.linear, value: viewStore.shouldShowNothingToReadMessage)
        .animation(.linear, value: viewStore.areVolumesLoaded)
        .onAppear {
            viewStore.send(.onAppear)
        }
    }
}

struct PagesView_Previews: PreviewProvider {
    static var previews: some View {
        PagesView(
            store: .init(
                initialState: .init(manga: dev.manga, chaptersPerPage: 10),
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
    
    private var emptyMangaMessageView: some View {
        VStack(spacing: 0) {
            Text("Ooops, there's nothing to read")
                .font(.title2)
                .fontWeight(.black)
            
            Text("😢")
                .font(.title2)
                .fontWeight(.black)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
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
            
            if viewStore.currentPageIndex - 2 > 0 {
                Text("...")
                    .font(.headline)
            }
            
            if viewStore.currentPageIndex > 1 {
                makePageLabel(for: viewStore.currentPageIndex, bgColor: .theme.darkGray)
            }
            
            makePageLabel(for: viewStore.currentPageIndex + 1, bgColor: .theme.accent)
            
            if viewStore.currentPageIndex + 2 < viewStore.pagesCount {
                makePageLabel(for: viewStore.currentPageIndex + 2, bgColor: .theme.darkGray)
            }
            
            if viewStore.currentPageIndex + 2 < viewStore.pagesCount - 1 {
                Text("...")
                    .font(.headline)
            }
            
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
