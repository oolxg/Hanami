//
//  ChapterView.swift
//  Hanami
//
//  Created by Oleg on 22/05/2022.
//

import SwiftUI
import ComposableArchitecture
import ModelKit
import UIComponents

struct ChapterView: View {
    let store: StoreOf<ChapterFeature>
    
    private struct ViewState: Equatable {
        let chapter: Chapter
        let chaptersCount: Int
        let online: Bool
        let chapterDetailsList: IdentifiedArrayOf<ChapterDetails>
        let cachedChaptersStates: Set<ChapterLoaderFeature.CachedChapterState>
        let areChaptersShown: Bool
        
        init(state: ChapterFeature.State) {
            chapter = state.chapter
            chaptersCount = state.chaptersCount
            online = state.online
            chapterDetailsList = state.chapterDetailsList
            cachedChaptersStates = state.downloader.cachedChaptersStates
            areChaptersShown = state.areChaptersShown
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            DisclosureGroup(
                isExpanded: viewStore.binding(
                    get: \.areChaptersShown,
                    send: .fetchChapterDetailsIfNeeded
                )
            ) {
                disclosureGroupBody
            } label: {
                disclosureGroupLabel
            }
            .buttonStyle(.plain)
            .animation(.linear, value: viewStore.chapterDetailsList.isEmpty)
            .padding(5)
            .onAppear { viewStore.send(.onAppear) }
            
            Divider()
        }
        .confirmationDialog(
            store: store.scope(
                state: \.$confirmationDialog,
                action: \.confirmationDialog
            )
        )
    }
}

extension ChapterView {
    private var disclosureGroupLabel: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack {
                Circle()
                    .fill(Color.theme.foreground)
                    .frame(width: 5, height: 5)
                    .padding(.trailing, 5)
                
                Text(viewStore.chapter.chapterName)
                    .foregroundColor(.theme.foreground)
                    .font(.title3)
                    .fontWeight(.light)
                    .padding(.vertical, 3)
                
                Spacer()
                
                if viewStore.chaptersCount > 1 {
                    Text("\(viewStore.chaptersCount) translations")
                        .foregroundColor(.theme.foreground)
                        .font(.subheadline)
                        .fontWeight(.thin)
                        .padding(.vertical, 3)
                } else {
                    Text("1 translation")
                        .foregroundColor(.theme.foreground)
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
        WithViewStore(store, observe: \.chapterDetailsList) { viewStore in
            LazyVStack {
                if viewStore.state.isEmpty {
                    ProgressView()
                        .frame(width: 40, height: 40)
                        .padding()
                        .transition(.opacity)
                } else {
                    ForEach(
                        viewStore.state,
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
            store.send(.userTappedOnChapterDetails(chapter))
        }
    }
    
    private func cacheStatusLabel(for chapter: ChapterDetails) -> some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if chapter.attributes.externalURL.hasValue {
                Image("ExternalLinkIcon")
                    .resizable()
                    .frame(width: 20, height: 20)
            } else if let chapterState = viewStore.cachedChaptersStates.first(where: { $0.id == chapter.id }) {
                ZStack {
                    switch chapterState.status {
                    case .cached:
                        Button {
                            viewStore.send(.chapterDeleteButtonTapped(chapterID: chapter.id))
                        } label: {
                            Image(systemName: "externaldrive.badge.checkmark")
                                .font(.callout)
                                .foregroundColor(.theme.green)
                        }
                        
                    case .downloadInProgress:
                        ProgressView(
                            value: Double(chapterState.pagesFetched),
                            total: Double(chapterState.pagesCount)
                        )
                        .progressViewStyle(GaugeProgressStyle(strokeColor: .theme.accent))
                        .frame(width: 20)
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
                        }
                    }
                }
                .animation(.linear, value: chapterState.status)
            } else if viewStore.online {
                Button {
                    viewStore.send(.downloadChapterButtonTapped(chapter: chapter), animation: .linear)
                } label: {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.callout)
                        .foregroundColor(.theme.foreground)
                }
            }
        }
        .padding(5)
    }
    
    private func makeScanlationGroupView(for chapter: ChapterDetails) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Translated by")
                    .fontWeight(.light)
                
                if let scanlationGroup = chapter.scanlationGroup {
                    HStack {
                        Text(scanlationGroup.name)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        
                        if scanlationGroup.attributes.isOfficial {
                            Image(systemName: "person.badge.shield.checkmark")
                                .foregroundColor(.theme.green)
                        }
                    }
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
