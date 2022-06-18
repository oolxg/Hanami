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
        WithViewStore(store) { viewStore in
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
            .tint(.theme.accent)
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
                    environment: .init(getListOfTags: downloadTagsList),
                    isMainQueueAnimated: true
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
            VStack(alignment: .leading) {
                makeTitle("Status")
                
                GridChipsView(viewStore.mangaStatuses) { mangaStatus in
                    makeChipsViewFor(mangaStatus)
                        .onTapGesture {
                            viewStore.send(.mangaStatusButtonTapped(mangaStatus))
                        }
                }
                .frame(height: 100)
                .padding(5)
            }
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(.theme.darkGray)
            
            VStack(alignment: .leading) {
                makeTitle("Content rating")
                
                GridChipsView(viewStore.contentRatings) { contentRating in
                    makeChipsViewFor(contentRating)
                        .onTapGesture {
                            viewStore.send(.contentRatingButtonTapped(contentRating))
                        }
                }
                .frame(height: 100)
                .padding(5)
            }
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(.theme.darkGray)
            
            VStack(alignment: .leading) {
                makeTitle("Demographic")
                
                GridChipsView(viewStore.publicationDemographics) { demographic in
                    makeChipsViewFor(demographic)
                        .onTapGesture {
                            viewStore.send(.publicationDemogrphicButtonTapped(demographic))
                        }
                }
                // it's a little hack
                // GridChipsView is fucking hard to frame
                // if tag has state '.selected' or '.banned', its width will be bigger
                // so we need to adjust more height for this view
                .frame(height: viewStore.publicationDemographics
                    .filter { $0.state != .notSelected }.isEmpty ? 60 : 100)
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
    
    private var filtersList: some View {
        WithViewStore(store) { viewStore in
            NavigationLink {
                makeFiltersViewFor(\.formatTypes, navTitle: "Format")
                    .padding()
            } label: {
                makeLabelForTagNavLink(title: "Format", \.formatTypes)
            }
            .frame(height: 20, alignment: .leading)
            .padding()
            .foregroundColor(.theme.background)
            
            NavigationLink {
                ScrollView(showsIndicators: false) {
                    makeFiltersViewFor(\.themeTypes, navTitle: "Themes")
                        .padding()
                    // this fucked up hack is to get normal height of the view
                    // just skip it, this works somehow...
                        .frame(
                            height: UIScreen.main.bounds.height * (
                                0.9 + CGFloat(viewStore.themeTypes.filter { $0.state != .notSelected }.count) * 0.005
                            )
                        )
                }
            } label: {
                makeLabelForTagNavLink(title: "Themes", \.themeTypes)
            }
            .frame(height: 20, alignment: .leading)
            .padding()
            .foregroundColor(.theme.background)
            
            NavigationLink {
                makeFiltersViewFor(\.genres, navTitle: "Genres")
                    .padding()
            } label: {
                makeLabelForTagNavLink(title: "Genres", \.genres)
            }
            .frame(height: 20, alignment: .leading)
            .padding()
            .foregroundColor(.theme.background)
        }
    }
    
    @ViewBuilder private func makeTitle(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.white)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
    
    @ViewBuilder private func makeLabelForTagNavLink<T: FilterTagProtocol>(
        title: String, _ path: KeyPath<FiltersState, IdentifiedArrayOf<T>>
    ) -> some View {
        WithViewStore(store) { viewStore in
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.callout)
                
                Spacer()
                
                if !viewStore.state[keyPath: path].filter { $0.state != .notSelected }.isEmpty {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.theme.red)
                        .padding(.horizontal)
                }
            }
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        Color.theme.accent, lineWidth: 2.5
                    )
            )
        }
    }
    
    @ViewBuilder private func makeFiltersViewFor(
        _ path: KeyPath<FiltersState, IdentifiedArrayOf<FilterTag>>, navTitle: String? = nil
    ) -> some View {
        ZStack {
            if navTitle != nil {
                Color.clear
                    .navigationTitle(navTitle!)
            }
            
            WithViewStore(store) { viewStore in
                GridChipsView(viewStore.state[keyPath: path]) { tag in
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
        .cornerRadius(40)
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
