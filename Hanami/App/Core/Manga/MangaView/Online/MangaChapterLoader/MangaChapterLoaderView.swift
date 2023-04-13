//
//  MangaChapterLoaderView.swift
//  Hanami
//
//  Created by Oleg on 19.03.23.
//

import SwiftUI
import ComposableArchitecture

struct MangaChapterLoaderView: View {
    let store: StoreOf<MangaChapterLoaderFeature>
    
    var body: some View {
        NavigationView {
            WithViewStore(store) { viewStore in
                ScrollView {
                    Menu {
                        Picker(
                            selection: viewStore.binding(
                                get: \.prefferedLanguage,
                                send: MangaChapterLoaderFeature.Action.prefferedLanguageChanged
                            )
                        ) {
                            ForEach(viewStore.allLanguages, id: \.self) { lang in
                                Text(lang)
                                    .id(lang)
                            }
                        } label: { EmptyView() }
                    } label: {
                        Text(viewStore.prefferedLanguage ?? "none")
                    }
                    
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewStore.chapters) { chapter in
                            makeViewFor(chapter: chapter)
                            
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationTitle(viewStore.manga.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#if DEBUG
struct MangaChapterLoaderView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}
#endif

extension MangaChapterLoaderView {
    @ViewBuilder private func makeViewFor(chapter: ChapterDetails) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(chapter.chapterName)
                    .font(.subheadline)
                
                if let scanlationGroup = chapter.scanlationGroup {
                    Text(scanlationGroup.name)
                        .font(.callout)
                        .foregroundColor(.theme.secondaryText)
                }
            }
            
            Spacer()
            
            if let index = chapter.attributes.index {
                Text(index.description)
                    .font(.headline)
            }
            
            Button {
                
            } label: {
                Image(systemName: "arrow.down.to.line.circle")
                    .foregroundColor(Color.theme.foreground)
            }
            .font(.headline)
        }
    }
}
