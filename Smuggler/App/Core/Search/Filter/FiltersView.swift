//
//  FiltersView.swift
//  Smuggler
//
//  Created by mk.pwnz on 02/06/2022.
//

import SwiftUI
import ComposableArchitecture

struct FiltersView: View {
    let store: Store<FiltersState, FiltersAction>
    
    var body: some View {
        WithViewStore(store.stateless) { viewStore in
            NavigationView {
                ScrollView(showsIndicators: false) {
                    filtersList

                    optionsList
                }
                .navigationTitle("Filters")
                .toolbar(content: toolbar)
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

struct FiltersView_Previews: PreviewProvider {
    static var previews: some View {
        FiltersView(
            store: .init(
                initialState: FiltersState(),
                reducer: filterReducer,
                environment: .live(
                    environment: .init(getListOfTags: downloadTagsList)
                )
            )
        )
        .preferredColorScheme(.dark)
    }
}

extension FiltersView {
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            WithViewStore(store) { viewStore in
                if viewStore.isAnyFilterApplied {
                    Button {
                        viewStore.send(.resetFilters)
                    } label: {
                        Text("Reset filters")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    private var optionsList: some View {
        WithViewStore(store) { viewStore in
            let sectionWidth = UIScreen.main.bounds.width / 1.1

            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    makeTitle("Status")
                    
                    GridChipsView(viewStore.mangaStatuses, width: sectionWidth) { mangaStatus in
                        makeChipsViewFor(mangaStatus)
                            .onTapGesture {
                                viewStore.send(.mangaStatusButtonTapped(mangaStatus))
                            }
                    }
                    .padding(5)
                }
                
                
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.theme.darkGray)
                
                VStack(alignment: .leading) {
                    makeTitle("Content rating")
                    
                    GridChipsView(viewStore.contentRatings, width: sectionWidth) { contentRating in
                        makeChipsViewFor(contentRating)
                            .onTapGesture {
                                viewStore.send(.contentRatingButtonTapped(contentRating))
                            }
                    }
                    .padding(5)
                }
                
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.theme.darkGray)
                
                VStack(alignment: .leading) {
                    makeTitle("Demographic")
                    
                    GridChipsView(viewStore.publicationDemographics, width: sectionWidth) { demographic in
                        makeChipsViewFor(demographic)
                            .onTapGesture {
                                viewStore.send(.publicationDemogrphicButtonTapped(demographic))
                            }
                    }
                    .padding(5)
                }
                
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.theme.darkGray)
                
                VStack(alignment: .leading) {
                    makeTitle("Content")
                    
                    makeFiltersViewFor(\.contentTypes)
                        .frame(height: 60)
                        .padding(5)
                }
                
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.theme.darkGray)
            }
        }
    }
    
    private var filtersList: some View {
        Group {
            makeTagNavigationLink(title: "Format", \.formatTypes) {
                makeFiltersViewFor(\.formatTypes, navTitle: "Format")
                    .padding()
            }
            
            makeTagNavigationLink(title: "Themes", \.themeTypes) {
                ScrollView(showsIndicators: false) {
                    makeFiltersViewFor(\.themeTypes, navTitle: "Themes")
                        .padding()
                }
            }
            
            makeTagNavigationLink(title: "Genres", \.genres) {
                makeFiltersViewFor(\.genres, navTitle: "Genres")
                    .padding()
            }
        }
    }
    
    private func makeTitle(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.white)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
    
    @ViewBuilder private func makeTagNavigationLink<T, Content>(
        title: String, _ path: KeyPath<FiltersState, IdentifiedArrayOf<T>>, _ content: @escaping () -> Content
    ) -> some View where Content: View, T: FilterTagProtocol {
        WithViewStore(store.actionless) { viewStore in
            NavigationLink {
                content()
            } label: {
                HStack {
                    Text(title)
                        .foregroundColor(.white)
                        .font(.callout)
                    
                    Spacer()
                    
                    if !viewStore.state[keyPath: path].filter { $0.state != .notSelected }.isEmpty {
                        Circle()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.theme.green)
                            .padding(.horizontal)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            Color.theme.accent, lineWidth: 2.5
                        )
                )
            }
            .frame(height: 20, alignment: .leading)
            .padding()
            .foregroundColor(.theme.background)
        }
    }
    
    @ViewBuilder private func makeFiltersViewFor(
        _ path: KeyPath<FiltersState, IdentifiedArrayOf<FilterTag>>, navTitle: String? = nil
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if navTitle != nil {
                Color.clear
                    .navigationTitle(navTitle!)
            }
            
            WithViewStore(store) { viewStore in
                GridChipsView(viewStore.state[keyPath: path], width: UIScreen.main.bounds.width / 1.1) { tag in
                    makeChipsViewFor(tag)
                        .onTapGesture {
                            viewStore.send(.filterTagButtonTapped(tag))
                        }
                }
            }
        }
    }
    
    @ViewBuilder private func makeChipsViewFor<T: FilterTagProtocol>(_ filterTag: T) -> some View {
        HStack {
            if filterTag.state == .selected {
                Image(systemName: "plus")
                    .font(.callout)
            } else if filterTag.state == .banned {
                Image(systemName: "minus")
                    .font(.callout)
            }
            
            Text(filterTag.name.capitalized)
                .padding(.horizontal, 5)
                .font(.callout)
                .lineLimit(1)
        }
        .padding(10)
        .foregroundColor(.white)
        .background(getColorForTag(filterTag))
        .cornerRadius(10)
    }
    
    private func getColorForTag<T: FilterTagProtocol>(_ tag: T) -> Color {
        if tag.state == .notSelected {
            return .theme.darkGray
        } else if tag.state == .selected {
            return .theme.accent
        } else {
            return .black
        }
    }
}
