//
//  ChapterView.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct ChapterView: View {
    let store: Store<ChapterState, ChapterAction>
    @Environment(\.openURL) private var openURL
    
    private struct ViewState: Equatable {
        let chapter: Chapter
        let chaptersCount: Int
        let isOnline: Bool
        let chapterDetailsList: IdentifiedArrayOf<ChapterDetails>
        let cachedChaptersStates: Set<ChapterState.CachedChapterState>
        
        init(state: ChapterState) {
            chapter = state.chapter
            chaptersCount = state.chaptersCount
            isOnline = state.isOnline
            chapterDetailsList = state.chapterDetailsList
            cachedChaptersStates = state.cachedChaptersStates
        }
    }

    var body: some View {
        WithViewStore(store) { viewStore in
            DisclosureGroup(isExpanded: viewStore.binding(\.$areChaptersShown)) {
                disclosureGroupBody
            } label: {
                disclosureGroupLabel
            }
            .buttonStyle(PlainButtonStyle())
            .animation(.linear, value: viewStore.chapterDetailsList.isEmpty)
            .padding(5)
            .confirmationDialog(
                store.scope(state: \.confirmationDialog),
                dismiss: .cancelTapped
            )
            
            Divider()
        }
    }
}

struct ChapterView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterView(
            store: .init(
                initialState: ChapterState(chapter: dev.chapter, parentManga: dev.manga),
                reducer: chapterReducer,
                environment: .init(
                    databaseClient: .live,
                    imageClient: .live,
                    cacheClient: .live,
                    mangaClient: .live,
                    hudClient: .live
                )
            )
        )
    }
}

extension ChapterView {
    private var disclosureGroupLabel: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack {
                Circle()
                    .fill(.white)
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
            .onTapGesture {
                viewStore.send(.fetchChapterDetailsIfNeeded, animation: .linear)
            }
        }
    }
    
    private var disclosureGroupBody: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if viewStore.chapterDetailsList.isEmpty {
                ProgressView()
                    .frame(width: 40, height: 40)
                    .padding()
                    .transition(.opacity)
            } else {
                LazyVStack {
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
                    .lineLimit(nil)
                    .padding(5)
                
                Spacer()
                
                cacheStatusLabel(for: chapter)
            }
            
            makeScanlationGroupView(for: chapter)
            
            Rectangle()
                .fill(.white)
                .frame(height: 1.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // if manga has externalURL, means we can only read it on some other website, not in app
            if let url = chapter.attributes.externalURL {
                openURL(url)
            } else {
                ViewStore(store).send(.userTappedOnChapterDetails(chapter: chapter))
            }
        }
    }
    
    private func cacheStatusLabel(for chapter: ChapterDetails) -> some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if chapter.attributes.externalURL != nil {
                Image(systemName: "arrow.up.forward.square")
                    .font(.callout)
                    .padding(5)
            } else if let chapterState = viewStore.cachedChaptersStates.first(where: { $0.chapterID == chapter.id }) {
                switch chapterState.status {
                    case .cached:
                        Button {
                            viewStore.send(.deleteChapter(chapterID: chapter.id))
                        } label: {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.callout)
                                .foregroundColor(.green)
                                .padding(5)
                        }
                        
                    case .downloadInProgress:
                        ProgressView(
                            value: Double(chapterState.pagesFetched) / Double(chapterState.pagesCount)
                        )
                        .progressViewStyle(.linear)
                        .padding(.top)
                        .frame(width: 40)
                        .onTapGesture {
                            viewStore.send(.cancelChapterDownload(chapterID: chapter.id))
                        }
                        
                    case .downloadFailed:
                        Button {
                            viewStore.send(.downloadChapterForOfflineReading(chapter: chapter))
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.callout)
                                .foregroundColor(.red)
                                .padding(5)
                        }
                }
            } else if viewStore.isOnline {
                Button {
                    viewStore.send(.downloadChapterForOfflineReading(chapter: chapter))
                } label: {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.callout)
                        .foregroundColor(.white)
                        .padding(5)
                }
            }
        }
    }
    
    private func makeScanlationGroupView(for chapter: ChapterDetails) -> some View {
        WithViewStore(store.actionless) { viewStore in
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
