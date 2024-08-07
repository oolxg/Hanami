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
    
    init(store: StoreOf<PagesFeature>) {
        self.store = store
    }
    
    private struct ViewState: Equatable {
        let currentPageIndex: Int
        let pagesCount: Int
        let splitIntoPagesVolumeTabStates: [IdentifiedArrayOf<VolumeTabFeature.State>]
        
        init(state: PagesFeature.State) {
            currentPageIndex = state.currentPageIndex
            pagesCount = state.pagesCount
            splitIntoPagesVolumeTabStates = state.splitIntoPagesVolumeTabStates
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: \.currentPageIndex) { viewStore in
            ForEachStore(
                store.scope(
                    state: \.volumeTabStatesOnCurrentPage,
                    action: PagesFeature.Action.volumeTabAction
                ),
                content: VolumeTabView.init
            )
            .animation(.linear, value: viewStore.state)
            
            footer
                .transition(.identity)
        }
    }
}

extension PagesView {
    private var footer: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack {
                Button {
                    viewStore.send(.pageIndexButtonTapped(newPageIndex: viewStore.currentPageIndex + 1))
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.theme.foreground)
                }
                .padding(.horizontal, 5)
                .opacity(viewStore.currentPageIndex + 1 != viewStore.pagesCount ? 1 : 0)

                makePageLabel(for: viewStore.pagesCount)
                    .opacity(viewStore.currentPageIndex + 1 != viewStore.pagesCount ? 1 : 0)
                
                Text("...")
                    .font(.headline)
                    .opacity(viewStore.currentPageIndex + 2 < viewStore.pagesCount - 1 ? 1 : 0)
                
                makePageLabel(for: viewStore.currentPageIndex + 2, bgColor: .theme.darkGray)
                    .opacity(viewStore.currentPageIndex + 2 < viewStore.pagesCount ? 1 : 0)
                
                pagesPicker

                makePageLabel(for: viewStore.currentPageIndex, bgColor: .theme.darkGray)
                    .opacity(viewStore.currentPageIndex > 1 ? 1 : 0)
                
                Text("...")
                    .font(.headline)
                    .opacity(viewStore.currentPageIndex - 2 > 0 ? 1 : 0)
                
                makePageLabel(for: 1)
                    .opacity(viewStore.currentPageIndex != 0 ? 1 : 0)
                    .disabled(viewStore.currentPageIndex == 0)

                Button {
                    viewStore.send(.pageIndexButtonTapped(newPageIndex: viewStore.currentPageIndex - 1))
                } label: {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.theme.foreground)
                }
                .padding(.horizontal, 5)
                .opacity(viewStore.currentPageIndex != 0 ? 1 : 0)
            }
            .padding(.bottom, 5)
            .animation(.linear, value: viewStore.currentPageIndex)
        }
    }
    
    private var pagesPicker: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            Menu {
                Picker(
                    selection: viewStore.binding(
                        get: \.currentPageIndex,
                        send: PagesFeature.Action.pageIndexButtonTapped
                    )
                ) {
                    let pagesInterval = (0..<viewStore.pagesCount).reversed()
                    ForEach(pagesInterval, id: \.self) { pageIndex in
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
                    .foregroundColor(.black)
                    .font(.subheadline)
                    .frame(width: 30, height: 30, alignment: .center)
                    .padding(7)
                    .background(Color.theme.accent)
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
    }
    
    private func makePageLabel(for pageIndex: Int, bgColor: Color = .theme.darkGray) -> some View {
        Text("\(pageIndex)")
            .foregroundColor(.white)
            .font(.subheadline)
            .frame(width: 25, height: 25, alignment: .center)
            .padding(7)
            .background(bgColor)
            .clipShape(.rect(cornerRadius: 6))
            .onTapGesture {
                store.send(.pageIndexButtonTapped(newPageIndex: pageIndex - 1))
            }
    }
}
