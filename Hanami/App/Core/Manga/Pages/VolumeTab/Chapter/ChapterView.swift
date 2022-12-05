//
//  ChapterView.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct ChapterView: View {
    let store: StoreOf<ChapterFeature>
    
    private struct ViewState: Equatable {
        let chapter: Chapter
        let chaptersCount: Int
        let online: Bool
        let chapterDetailsList: IdentifiedArrayOf<ChapterDetails>
        let cachedChaptersStates: Set<ChapterFeature.CachedChapterState>
        let areChaptersShown: Bool
        let scanlationGroups: [UUID: ScanlationGroup]
        
        init(state: ChapterFeature.State) {
            chapter = state.chapter
            chaptersCount = state.chaptersCount
            online = state.online
            chapterDetailsList = state.chapterDetailsList
            cachedChaptersStates = state.cachedChaptersStates
            areChaptersShown = state.areChaptersShown
            scanlationGroups = state.scanlationGroups
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            DisclosureGroup(
                isExpanded: viewStore.binding(
                    get: \.areChaptersShown, send: .fetchChapterDetailsIfNeeded
                )
            ) {
                disclosureGroupBody
            } label: {
                disclosureGroupLabel
            }
            .buttonStyle(.plain)
            .animation(.linear, value: viewStore.chapterDetailsList.isEmpty)
            .padding(5)
            .confirmationDialog(
                store.scope(state: \.confirmationDialog),
                dismiss: .cancelTapped
            )
            .onAppear {
                viewStore.send(.onAppear)
            }
            
            Divider()
        }
    }
}

#if DEBUG
struct ChapterView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterView(
            store: .init(
                initialState: ChapterFeature.State(chapter: dev.chapter, parentManga: dev.manga),
                reducer: ChapterFeature()._printChanges()
            )
        )
    }
}
#endif

extension ChapterView {
    private var disclosureGroupLabel: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack {
                Circle()
                    .fill(Color.theme.foreground)
                    .frame(width: 5, height: 5)
                    .padding(.trailing, 5)
                
                Text(viewStore.chapter.chapterName)
                    .font(.title3)
                    .fontWeight(.light)
                    .padding(.vertical, 3)
                
                Spacer()
                
                if viewStore.chaptersCount > 1 {
                    Text("\(viewStore.chaptersCount) translations")
                        .font(.subheadline)
                        .fontWeight(.thin)
                        .padding(.vertical, 3)
                } else {
                    Text("1 translation")
                        .font(.subheadline)
                        .fontWeight(.thin)
                        .padding(.vertical, 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }
    
    private var disclosureGroupBody: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            LazyVStack {
                if viewStore.chapterDetailsList.isEmpty {
                    ProgressView()
                        .frame(width: 40, height: 40)
                        .padding()
                        .transition(.opacity)
                } else {
                    ForEach(
                        viewStore.chapterDetailsList,
                        content: makeChapterDetailsView
                    )
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func makeChapterDetailsView(for chapter: ChapterDetails) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text(chapter.chapterName)
                    .fontWeight(.medium)
                    .font(.headline)
                    .lineLimit(2)
                    .padding(5)
                
                Spacer()
                
                cacheStatusLabel(for: chapter)
            }
            
            makeScanlationGroupView(for: chapter)
            
            Rectangle()
                .fill(Color.theme.foreground)
                .frame(height: 1.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            ViewStore(store).send(.userTappedOnChapterDetails(chapter: chapter))
        }
    }
    
    private func cacheStatusLabel(for chapter: ChapterDetails) -> some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if chapter.attributes.externalURL != nil {
                Image(systemName: "arrow.up.forward.square")
                    .font(.callout)
                    .padding(5)
            } else if let chapterState = viewStore.cachedChaptersStates.first(where: { $0.id == chapter.id }) {
                switch chapterState.status {
                case .cached:
                    Button {
                        viewStore.send(.chapterDeleteButtonTapped(chapterID: chapter.id))
                    } label: {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.callout)
                            .foregroundColor(.green)
                            .padding(5)
                    }
                    
                case .downloadInProgress:
                    ProgressView(
                        value: Double(chapterState.pagesFetched),
                        total: Double(chapterState.pagesCount)
                    )
                    .progressViewStyle(.linear)
                    .padding(.top, 5)
                    .padding(5)
                    .frame(width: 40)
                    .tint(.theme.accent)
                    .onTapGesture {
                        viewStore.send(.cancelChapterDownloadButtonTapped(chapterID: chapter.id), animation: .linear)
                    }
                    
                case .downloadFailed:
                    Button {
                        viewStore.send(.downloadChapterButtonTapped(chapter: chapter))
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.callout)
                            .foregroundColor(.red)
                            .padding(5)
                    }
                }
            } else if viewStore.online {
                Button {
                    viewStore.send(.downloadChapterButtonTapped(chapter: chapter), animation: .linear)
                } label: {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.callout)
                        .foregroundColor(.theme.foreground)
                        .padding(5)
                }
            }
        }
    }
    
    private func makeScanlationGroupView(for chapter: ChapterDetails) -> some View {
        WithViewStore(store.actionless, observe: ViewState.init) { viewStore in
            HStack {
                VStack(alignment: .leading) {
                    Text("Translated by:")
                        .fontWeight(.light)
                    
                    if viewStore.chapterDetailsList[id: chapter.id]?.scanlationGroupID != nil {
                        Text(viewStore.scanlationGroups[chapter.id]?.name ?? .placeholder(length: 35))
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .redacted(if: viewStore.scanlationGroups[chapter.id]?.name == nil)
                    } else {
                        Text("No group")
                            .fontWeight(.bold)
                    }
                }
                .font(.caption)
                .foregroundColor(.theme.secondaryText)
                .padding(.horizontal, 5)
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.theme.secondaryText)
                
                Text(chapter.attributes.createdAt.timeAgo)
                    .font(.caption)
                    .foregroundColor(.theme.secondaryText)
            }
            .transition(.opacity)
        }
    }
}
