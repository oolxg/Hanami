//
//  FiltersFeature.swift
//  Hanami
//
//  Created by Oleg on 30/05/2022.
//

import Foundation
import ComposableArchitecture

struct FiltersFeature: ReducerProtocol {
    struct State: Equatable {
        // MARK: - Tags
        var allTags: IdentifiedArrayOf<FiltersTag> = []
        
        // All the types defined inside one enum to display more comfortable
        var genres: IdentifiedArrayOf<FiltersTag> {
            allTags.filter { $0.type == .genre }
        }
        var themeTypes: IdentifiedArrayOf<FiltersTag> {
            allTags.filter { $0.type == .theme }
        }
        var formatTypes: IdentifiedArrayOf<FiltersTag> {
            allTags.filter { $0.type == .format }
        }
        var contentTypes: IdentifiedArrayOf<FiltersTag> {
            allTags.filter { $0.type == .content }
        }
        // MARK: - Options
        var publicationDemographics: IdentifiedArrayOf<PublicationDemographic> = [
            .init(tag: .josei), .init(tag: .seinen), .init(tag: .shoujo), .init(tag: .shounen)
        ]
        var contentRatings: IdentifiedArrayOf<ContentRatings> = [
            .init(tag: .erotica), .init(tag: .pornographic),
            .init(tag: .safe), .init(tag: .suggestive, state: .selected)
        ]
        var mangaStatuses: IdentifiedArrayOf<MangaStatus> = [
            .init(tag: .cancelled), .init(tag: .completed), .init(tag: .hiatus), .init(tag: .ongoing)
        ]
        
        var isAnyFilterApplied: Bool {
            !allTags.filter { $0.state == .selected || $0.state == .banned }.isEmpty ||
            // 'mangaStatuses', 'publicationDemographics' and 'contentRatings' can't have .state as 'banned', so we don't check this type
            !publicationDemographics.filter { $0.state == .selected }.isEmpty ||
            !contentRatings.filter { $0.state == .selected && $0.tag != .suggestive }.isEmpty ||
            !mangaStatuses.filter { $0.state == .selected }.isEmpty
        }
    }
    
    enum Action {
        case fetchFilterTagsIfNeeded
        case filterListDownloaded(Result<Response<[Tag]>, AppError>)
        case filterTagButtonTapped(FiltersTag)
        case resetFilterButtonPressed
        
        case mangaStatusButtonTapped(MangaStatus)
        case contentRatingButtonTapped(ContentRatings)
        case publicationDemographicButtonTapped(PublicationDemographic)
    }
    
    @Dependency(\.hapticClient) private var hapticClient
    @Dependency(\.searchClient) private var searchClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue

    // swiftlint:disable:next cyclomatic_complexity
    func reduce(into state: inout State, action: Action) -> EffectPublisher<Action, Never> {
        switch action {
        case .fetchFilterTagsIfNeeded:
            guard state.allTags.isEmpty else { return .none }
            
            return searchClient.fetchTags()
                .receive(on: mainQueue)
                .catchToEffect(Action.filterListDownloaded)
            
        case .filterListDownloaded(let result):
            switch result {
            case .success(let response):
                state.allTags = .init(
                    uniqueElements: response.data
                        .map { FiltersTag(tag: $0, state: .notSelected) }
                        .sorted(by: <)
                )
                
                return .none
                
            case .failure(let error):
                logger.error("Failed to load list of filters: \(error)")
                return .none
            }
            
        case .filterTagButtonTapped(let tappedTag):
            state.allTags[id: tappedTag.id]?.toggleState()
            return hapticClient.generateFeedback(.light).fireAndForget()
            
        case .resetFilterButtonPressed:
            for tagID in state.allTags.map(\.id) {
                state.allTags[id: tagID]!.state = .notSelected
            }
            
            for tagID in state.mangaStatuses.map(\.id) {
                state.mangaStatuses[id: tagID]!.state = .notSelected
            }
            
            for tagID in state.publicationDemographics.map(\.id) {
                state.publicationDemographics[id: tagID]!.state = .notSelected
            }
            
            for tagID in state.contentRatings.map(\.id) {
                if state.contentRatings[id: tagID]!.tag != .suggestive {
                    state.contentRatings[id: tagID]!.state = .notSelected
                } else {
                    state.contentRatings[id: tagID]!.state = .selected
                }
            }
            
            return .none
            
        case .mangaStatusButtonTapped(let tag):
            if tag.state == .selected {
                state.mangaStatuses[id: tag.id]!.state = .notSelected
            } else {
                state.mangaStatuses[id: tag.id]!.state = .selected
            }
            
            return hapticClient.generateFeedback(.light).fireAndForget()
            
        case .contentRatingButtonTapped(let tag):
            if tag.state == .selected {
                state.contentRatings[id: tag.id]!.state = .notSelected
            } else {
                state.contentRatings[id: tag.id]!.state = .selected
            }
            
            return hapticClient.generateFeedback(.light).fireAndForget()
            
        case .publicationDemographicButtonTapped(let tag):
            if tag.state == .selected {
                state.publicationDemographics[id: tag.id]!.state = .notSelected
            } else {
                state.publicationDemographics[id: tag.id]!.state = .selected
            }
            
            return hapticClient.generateFeedback(.light).fireAndForget()
        }
    }
    
    enum TagState: String, Codable {
        case selected, notSelected, banned
    }
    
    struct FiltersTag: FiltersTagProtocol, Comparable {
        let tag: Tag
        var name: String {
            tag.name
        }
        var state: TagState = .notSelected
        var type: Tag.Attributes.Group { tag.attributes.group }
        var id: UUID { tag.id }
        
        static func < (lhs: FiltersTag, rhs: FiltersTag) -> Bool {
            lhs.name < rhs.name
        }
        
        mutating func toggleState() {
            switch state {
            case .selected:
                state = .banned
            case .notSelected:
                state = .selected
            case .banned:
                state = .notSelected
            }
        }
    }
    
    struct PublicationDemographic: FiltersTagProtocol {
        let tag: Manga.Attributes.PublicationDemographic
        var state: TagState = .notSelected
        var name: String {
            tag.rawValue
        }
        var id: String {
            tag.rawValue
        }
    }
    
    struct ContentRatings: FiltersTagProtocol {
        let tag: Manga.Attributes.ContentRatings
        var name: String {
            tag.rawValue
        }
        var state: TagState = .notSelected
        var id: String {
            tag.rawValue
        }
    }
    
    struct MangaStatus: FiltersTagProtocol {
        let tag: Manga.Attributes.Status
        var name: String {
            tag.rawValue
        }
        var state: TagState = .notSelected
        var id: String {
            tag.rawValue
        }
    }
    
    enum QuerySortOption: String, Codable {
        // can only be desc
        case relevance
        // can be desc and asc
        case latestUploadedChapter, title, rating
        case createdAt, followedCount, year
        
        enum Order: String, Codable {
            case asc, desc
        }
    }
}

protocol FiltersTagProtocol: Identifiable, Equatable, Hashable, Codable {
    var state: FiltersFeature.TagState { get set }
    var name: String { get }
}

extension FiltersTagProtocol {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state
    }
}
