//
//  PagesView.swift
//  Hanami
//
//  Created by Oleg on 13/07/2022.
//

import SwiftUI
import ComposableArchitecture

struct PagesView: View {
    private let store: StoreOf<PagesFeature>
    private let viewStore: ViewStoreOf<PagesFeature>
    
    init(store: StoreOf<PagesFeature>) {
        self.store = store
        viewStore = ViewStore(store)
    }
    
    var body: some View {
        if viewStore.splitIntoPagesVolumeTabStates.isEmpty {
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
        } else {
            ForEachStore(
                store.scope(
                    state: \.volumeTabStatesOnCurrentPage,
                    action: PagesFeature.Action.volumeTabAction
                ),
                content: VolumeTabView.init
            )
            .disabled(viewStore.lockPage)

            footer
                .transition(.identity)
        }
    }
}

#if DEBUG
struct PagesView_Previews: PreviewProvider {
    static var previews: some View {
        PagesView(
            store: .init(
                initialState: .init(manga: dev.manga, mangaVolumes: [], chaptersPerPage: 1, online: true),
                reducer: PagesFeature()._printChanges()
            )
        )
    }
}
#endif

extension PagesView {
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
        .animation(.linear, value: viewStore.currentPageIndex)
    }
    
    private var pagesPicker: some View {
        Menu {
            Picker(
                selection: viewStore.binding(
                    get: \.currentPageIndex,
                    send: PagesFeature.Action.changePage
                )
            ) {
                ForEach(0..<viewStore.pagesCount, id: \.self) { pageIndex in
                    let volumeIndexes = viewStore.splitIntoPagesVolumeTabStates[pageIndex]
                        .compactMap { $0.volume.volumeIndex?.clean() }
                        .reversed()
                        .joined(separator: ", ")
                    
                    if !volumeIndexes.isEmpty {
                        Text("Page \(pageIndex + 1) (Vol. \(volumeIndexes))")
                    } else {
                        Text("Page \(pageIndex + 1)")
                    }
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
