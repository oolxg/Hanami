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
                    optionsList
                    
                    VStack(alignment: .leading) {
                        makeTitle("Other filters")
                        
                        filtersList
                            .padding(.top, 10)
                    }
                }
                .navigationTitle("Filters")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        resetFiltersButton
                    }
                }
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
                    isMainQueueWithAnimation: true
                )
            )
        )
        .preferredColorScheme(.dark)
    }
}


extension FiltersView {
    private var resetFiltersButton: some View {
        WithViewStore(store) { viewStore in
            ZStack {
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
                } else {
                    Color.clear
                }
            }
        }
    }
    
    private var optionsList: some View {
        WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                makeTitle("Demographic")
                
                GridChipsView(viewStore.publicationDemographics) { demographic in
                    chipsViewFor(demographic)
                        .onTapGesture {
                            viewStore.send(.publicationDemogrphicButtonTapped(demographic))
                        }
                }
                // it's a little hack
                // GridChipsView is fucking hard to frame
                // if tag has state '.selected' or '.banned', its width will be bigger
                // so we need to adjust more height for this view
                .frame(height: viewStore.publicationDemographics
                    .filter { $0.state != .notSelected }.count > 0 ? 100 : 60)
                .padding(5)
            }
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(.theme.darkGrey)
            
            VStack(alignment: .leading) {
                makeTitle("Status")
                
                GridChipsView(viewStore.mangaStatuses) { mangaStatus in
                    chipsViewFor(mangaStatus)
                        .onTapGesture {
                            viewStore.send(.mangaStatusButtonTapped(mangaStatus))
                        }
                }
                .frame(height: 100)
                .padding(5)
            }
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(.theme.darkGrey)
            
            VStack(alignment: .leading) {
                makeTitle("Content rating")
                
                GridChipsView(viewStore.contentRatings) { contentRating in
                    chipsViewFor(contentRating)
                        .onTapGesture {
                            viewStore.send(.contentRatingButtonTapped(contentRating))
                        }
                }
                .frame(height: 100)
                .padding(5)
            }
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(.theme.darkGrey)
            
            VStack(alignment: .leading) {
                makeTitle("Content")
                
                makeFiltersViewFor(\.contentTypes)
                    .frame(height: 60)
                    .padding(5)
            }
            
            Rectangle()
                .frame(height: 3)
                .foregroundColor(.theme.darkGrey)
        }
    }
    
    private var filtersList: some View {
        WithViewStore(store) { viewStore in
            NavigationLink {
                makeFiltersViewFor(\.formatTypes, navTitle: "Format")
            } label: {
                makeLabelForTagNavLink(title: "Format", \.formatTypes)
            }
            .frame(height: 20, alignment: .leading)
            .padding()
            .foregroundColor(.theme.background)
            
            NavigationLink {
                ScrollView(showsIndicators: false) {
                    makeFiltersViewFor(\.themeTypes, navTitle: "Themes")
                    // this fucked up hack is to get normal height of the view
                    // just skip it, this works somehow...
                        .frame(
                            height: UIScreen.main.bounds.height * (
                                0.8 + CGFloat(viewStore.themeTypes.filter { $0.state != .notSelected}.count) * 0.007
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
                
                if viewStore.state[keyPath: path].filter { $0.state == .notSelected }.count != viewStore.state[keyPath: path].count {
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
                    chipsViewFor(tag)
                        .onTapGesture {
                            viewStore.send(.filterTagButtonTapped(tag))
                        }
                }
            }
        }
    }
    
    @ViewBuilder private func chipsViewFor<T: FilterTagProtocol>(_ filterTag: T) -> some View {
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
            return .theme.darkGrey
        } else if tag.state == .selected {
            return .theme.accent
        } else {
            return .black
        }
    }
}
