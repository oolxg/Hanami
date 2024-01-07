//
//  FiltersView.swift
//  Hanami
//
//  Created by Oleg on 02/06/2022.
//

import SwiftUI
import ComposableArchitecture
import UIComponents

// swiftlint:disable multiple_closures_with_trailing_closure
struct FiltersView: View {
    let store: StoreOf<FiltersFeature>
    let blurRadius: CGFloat
    @State private var showFormatFiltersPage = false
    @State private var showThemesFiltersPage = false
    @State private var showGenresFiltersPage = false
    
    private struct ViewState: Equatable {
        let mangaStatuses: IdentifiedArrayOf<FiltersFeature.MangaStatus>
        let contentRatings: IdentifiedArrayOf<FiltersFeature.ContentRatings>
        let publicationDemographics: IdentifiedArrayOf<FiltersFeature.PublicationDemographic>
        let allTags: IdentifiedArrayOf<FiltersFeature.FiltersTag>
        let isContentTypesLoaded: Bool
        
        init(state: FiltersFeature.State) {
            mangaStatuses = state.mangaStatuses
            contentRatings = state.contentRatings
            publicationDemographics = state.publicationDemographics
            allTags = state.allTags
            isContentTypesLoaded = !state.contentTypes.isEmpty
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                filtersList
                
                optionsList
            }
            .navigationTitle("Filters")
            .toolbar(content: toolbar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .transition(.opacity)
        .autoBlur(radius: blurRadius)
        .onAppear {
            store.send(.fetchFilterTagsIfNeeded)
        }
    }
}

extension FiltersView {
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            WithViewStore(store, observe: \.isAnyFilterApplied) { viewStore in
                if viewStore.state {
                    Button {
                        viewStore.send(.resetFilterButtonPressed)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.theme.foreground)
                            .padding(8)
                    }
                }
            }
        }
    }
    
    private var optionsList: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    makeTitle("Status")
                    
                    FlexibleView(
                        data: viewStore.mangaStatuses,
                        spacing: 10,
                        alignment: .leading
                    ) { mangaStatus in
                        makeChipsViewFor(mangaStatus)
                            .onTapGesture {
                                viewStore.send(.mangaStatusButtonTapped(mangaStatus))
                            }
                    }
                    .padding(15)
                }
                
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.theme.darkGray)
                
                VStack(alignment: .leading) {
                    makeTitle("Content rating")
                    
                    FlexibleView(
                        data: viewStore.contentRatings,
                        spacing: 10,
                        alignment: .leading
                    ) { contentRating in
                        makeChipsViewFor(contentRating)
                            .onTapGesture {
                                viewStore.send(.contentRatingButtonTapped(contentRating))
                            }
                    }
                    .padding(15)
                }
                
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.theme.darkGray)
                
                VStack(alignment: .leading) {
                    makeTitle("Demographic")
                    
                    FlexibleView(
                        data: viewStore.publicationDemographics,
                        spacing: 10,
                        alignment: .leading
                    ) { demographic in
                        makeChipsViewFor(demographic)
                            .onTapGesture {
                                viewStore.send(.publicationDemographicButtonTapped(demographic))
                            }
                    }
                    .padding(15)
                }
                
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(.theme.darkGray)
                
                if viewStore.isContentTypesLoaded {
                    VStack(alignment: .leading) {
                        makeTitle("Content")
                        
                        makeFiltersViewFor(\.contentTypes)
                            .padding(15)
                    }
                    
                    Rectangle()
                        .frame(height: 3)
                        .foregroundColor(.theme.darkGray)
                }
            }
        }
    }
    
    private var filtersList: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            if !viewStore.allTags.isEmpty {
                makeNavigationLinkLabel(title: "Format", \.formatTypes, isActive: $showFormatFiltersPage) {
                    makeFiltersViewFor(\.formatTypes, navTitle: "Format", isActive: $showFormatFiltersPage)
                        .padding()
                }
                
                makeNavigationLinkLabel(title: "Themes", \.themeTypes, isActive: $showThemesFiltersPage) {
                    ScrollView(showsIndicators: false) {
                        makeFiltersViewFor(\.themeTypes, navTitle: "Themes", isActive: $showThemesFiltersPage)
                            .padding()
                    }
                }
                
                makeNavigationLinkLabel(title: "Genres", \.genres, isActive: $showGenresFiltersPage) {
                    makeFiltersViewFor(\.genres, navTitle: "Genres", isActive: $showGenresFiltersPage)
                        .padding()
                }
            }
        }
    }
    
    private func makeTitle(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.theme.foreground)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
    
    @ViewBuilder private func makeNavigationLinkLabel<T, Content>(
        title: String,
        _ path: KeyPath<FiltersFeature.State, IdentifiedArrayOf<T>>,
        isActive: Binding<Bool>,
        _ content: @escaping () -> Content
    ) -> some View where Content: View, T: FiltersTagProtocol {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationLink(isActive: isActive) {
                content()
            } label: {
                HStack {
                    Text(title)
                        .foregroundColor(.theme.foreground)
                        .font(.callout)
                    
                    Spacer()
                    
                    if !viewStore.state[keyPath: path].filter({ $0.state != .notSelected }).isEmpty {
                        Circle()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.theme.green)
                            .padding(.horizontal)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.theme.foreground)
                        .font(.headline)
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.theme.foreground, lineWidth: 1.5)
                )
            }
            .frame(height: 20, alignment: .leading)
            .padding()
            .foregroundColor(.theme.background)
        }
    }
    
    @ViewBuilder private func makeFiltersViewFor(
        _ path: KeyPath<FiltersFeature.State, IdentifiedArrayOf<FiltersFeature.FiltersTag>>,
        navTitle: String? = nil,
        isActive: Binding<Bool>? = nil
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if let navTitle {
                Color.clear
                    .navigationTitle(navTitle)
            }
            
            WithViewStore(store, observe: { $0 }) { viewStore in
                FlexibleView(
                    data: viewStore.state[keyPath: path],
                    spacing: 10,
                    alignment: .leading
                ) { tag in
                    makeChipsViewFor(tag)
                        .onTapGesture {
                            viewStore.send(.filterTagButtonTapped(tag))
                        }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isActive?.wrappedValue = false
                    } label: {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.theme.foreground)
                            .padding(.vertical)
                    }
                    .opacity(isActive.isNil ? 0 : 1)
                }
            }
        }
    }
    
    @ViewBuilder private func makeChipsViewFor(_ filterTag: any FiltersTagProtocol) -> some View {
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
        .foregroundColor(filterTag.state == .selected ? .black : .white)
        .background(getColorForTag(filterTag))
        .cornerRadius(10)
    }
    
    private func getColorForTag(_ tag: any FiltersTagProtocol) -> Color {
        if tag.state == .notSelected {
            return .theme.darkGray
        } else if tag.state == .selected {
            return .theme.accent
        } else {
            return .black
        }
    }
}
// swiftlint:enable multiple_closures_with_trailing_closure
