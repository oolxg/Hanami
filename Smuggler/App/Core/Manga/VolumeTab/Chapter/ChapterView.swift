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
    @State private var areChaptersShown = false
    @Environment(\.openURL) var openURL

    var body: some View {
        WithViewStore(store) { viewStore in
            DisclosureGroup(isExpanded: $areChaptersShown) {
                if areChaptersShown {
                    VStack(spacing: 0) {
                        ForEach(viewStore.chapterDetails) { chapter in
                            makeChapterView(chapter: chapter)
                                .transition(.opacity)
                            
                            Rectangle()
                                .fill(.white)
                                .frame(height: 1.5)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        viewStore.send(.onAppear)
                    }
                }
            } label: {
                HStack {
                    Text(viewStore.chapter.chapterName)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .padding(.vertical, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.linear(duration: areChaptersShown ? 0.3 : 0.7)) {
                        areChaptersShown.toggle()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

struct ChapterView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterView(
            store: .init(
                initialState: ChapterState(chapter: dev.chapter),
                reducer: chapterReducer,
                environment: .live(
                    environment: .init(
                        downloadChapterInfo: downloadChapterInfo,
                        fetchScanlationGroupInfo: fetchScanlationGroupInfo
                    )
                )
            )
        )
    }
}

extension ChapterView {
    @ViewBuilder private func makeChapterView(chapter: ChapterDetails) -> some View {
        WithViewStore(store) { viewStore in
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text(chapter.chapterName)
                            .fontWeight(.medium)
                            .font(.headline)
                            .lineLimit(nil)
                            .padding(5)
                        
                        if chapter.attributes.externalURL != nil {
                            Spacer()
                            
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.theme.secondaryText)
                                .font(.callout)
                                .padding(5)
                        }
                    }
                    
                    makeScanlationGroupSection(for: chapter)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // if manga has externalURL, means we can only read it on some other website, not in app
                if let url = chapter.attributes.externalURL {
                    openURL(url)
                } else {
                    viewStore.send(
                        .onTapGesture(chapter: chapter)
                    )
                }
            }
        }
        .padding(0)
    }

    @ViewBuilder private func makeScanlationGroupSection(for chapter: ChapterDetails) -> some View {
        WithViewStore(store) { viewStore in
            HStack {
                VStack(alignment: .leading) {
                    Text("Translated by:")
                        .fontWeight(.light)
                    
                    Text(viewStore.scanlationGroups[chapter.id]?.name ?? .placeholder(length: 35))
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .redacted(if: viewStore.scanlationGroups[chapter.id]?.name == nil)
                }
                .font(.caption)
                .foregroundColor(.theme.secondaryText)
                .padding(.horizontal, 5)
                .padding(.bottom, 5)
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.theme.secondaryText)
                
                Text(chapter.attributes.createdAt.timeAgo)
                    .font(.caption)
                    .foregroundColor(.theme.secondaryText)
            }
            .transition(.opacity)
            .animation(.linear, value: areChaptersShown)
        }
    }
}
