//
//  ChapterView.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import SwiftUI
import ComposableArchitecture

struct ChapterView: View {
    let store: Store<ChapterState, ChapterAction>
    @Environment(\.openURL) private var openURL
    @State private var showConfirmationDialog = false

    var body: some View {
        WithViewStore(store) { viewStore in
            DisclosureGroup(isExpanded: viewStore.binding(\.$areChaptersShown)) {
                disclosureGroupBody
            } label: {
                disclosureGroupLabel
            }
            .buttonStyle(PlainButtonStyle())
            .padding(5)
        }
    }
}

struct ChapterView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterView(
            store: .init(
                initialState: ChapterState(chapter: dev.chapter),
                reducer: chapterReducer,
                environment: .init(
                    databaseClient: .live,
                    mangaClient: .live
                )
            )
        )
    }
}

extension ChapterView {
    private var disclosureGroupLabel: some View {
        WithViewStore(store) { viewStore in
            HStack {
                Circle()
                    .fill(.white)
                    .frame(width: 5, height: 5)
                    .padding(.trailing, 5)
                
                Text(viewStore.chapter.chapterName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.vertical, 3)
                
                if viewStore.shouldShowActivityIndicator {
                    Spacer()
                    
                    ActivityIndicator(lineWidth: 2)
                        .frame(width: 15)
                        .transition(.opacity)
                }
            }
            .animation(.linear, value: viewStore.shouldShowActivityIndicator)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                viewStore.send(.userTappedOnChapter, animation: .linear)
            }
        }
    }
    
    private var disclosureGroupBody: some View {
        WithViewStore(store) { viewStore in
            LazyVStack {
                ForEach(viewStore.chapterDetails) { chapter in
                    makeChapterDetailsView(for: chapter)
                        .onTapGesture {
                                // if manga has externalURL, means we can only read it on some other website, not in app
                            if let url = chapter.attributes.externalURL {
                                openURL(url)
                            } else {
                                viewStore.send(
                                    .userTappedOnChapterDetails(chapter: chapter)
                                )
                            }
                        }
                }
                .transition(.opacity)
                .animation(.linear, value: viewStore.areChaptersShown)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func makeChapterDetailsView(for chapter: ChapterDetails) -> some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Text(chapter.chapterName)
                        .fontWeight(.medium)
                        .font(.headline)
                        .lineLimit(nil)
                        .padding(5)
                    
                    Spacer()
                    
                    if chapter.attributes.externalURL != nil {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.callout)
                            .padding(5)
                    } else {
                        if viewStore.cachedChaptersIDs.contains(chapter.id) {
                            Button {
                                viewStore.send(.userWantsToDeleteChapter(chapter: chapter))
                            } label: {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.callout)
                                    .foregroundColor(.green)
                                    .padding(5)
                            }
                            .confirmationDialog(
                                store.scope(state: \.confiramtionDialog),
                                dismiss: .cancelTapped
                            )
                        } else {
                            Button {
                                viewStore.send(.downloadChapterForOfflineReading(chapter: chapter))
                            } label: {
                                Image(systemName: "arrow.down.to.line.circle")
                                    .font(.callout)
                                    .foregroundColor(.white)
                                    .padding(5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                makeScanlationGroupView(for: chapter)
                
                Rectangle()
                    .fill(.white)
                    .frame(height: 1.5)
            }
            .contentShape(Rectangle())
        }
    }
    private func makeScanlationGroupView(for chapter: ChapterDetails) -> some View {
        WithViewStore(store.actionless) { viewStore in
            HStack {
                VStack(alignment: .leading) {
                    Text("Translated by:")
                        .fontWeight(.light)
                    
                    if viewStore.chapterDetails[id: chapter.id]?.scanltaionGroupID != nil {
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
