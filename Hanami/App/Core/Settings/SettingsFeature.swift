//
//  SettingsStore.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import Foundation
import ComposableArchitecture
import Nuke
import class UIKit.UIApplication

struct SettingsFeature: ReducerProtocol {
    struct State: Equatable {
        @BindableState var config = SettingsConfig(
            autolockPolicy: .never,
            blurRadius: Defaults.Security.minBlurRadius,
            useHigherQualityImagesForOnlineReading: false,
            useHigherQualityImagesForCaching: false,
            colorScheme: 0
        )
        // size of all loaded mangas and coverArts, excluding cache and info in DB
        var usedStorageSpace = 0.0
        var confirmationDialog: ConfirmationDialogState<Action>?
    }
    
    enum Action: BindableAction, Equatable {
        case initSettings
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case recomputeCacheSize
        case clearImageCacheButtonTapped
        case clearMangaCacheButtonTapped
        case clearMangaCacheConfirmed
        case cachedMangaRetrieved(Result<[Manga], Never>)
        case cancelTapped
        case cacheSizeComputed(Result<Double, AppError>)
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    @Dependency(\.cacheClient) private var cacheClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .initSettings:
                return settingsClient.getSettingsConfig()
                    .receive(on: DispatchQueue.main)
                    .catchToEffect(Action.settingsConfigRetrieved)
                
            case .settingsConfigRetrieved(let result):
                switch result {
                case .success(let config):
                    state.config = config
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to retrieve settings config: \(error)")
                    return .none
                }
                
            case .recomputeCacheSize:
                return cacheClient.computeCacheSize()
                    .receive(on: DispatchQueue.main)
                    .eraseToEffect(Action.cacheSizeComputed)
                
            case .clearMangaCacheButtonTapped:
                state.confirmationDialog = ConfirmationDialogState(
                    title: TextState("Delete all manga from device?"),
                    message: TextState("Delete all manga from device?"),
                    buttons: [
                        .destructive(TextState("Delete"), action: .send(.clearMangaCacheConfirmed)),
                        .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                    ]
                )
                
                return .none
                
            case .clearImageCacheButtonTapped:
                Nuke.DataLoader.sharedUrlCache.removeAllCachedResponses()
                Nuke.ImageCache.shared.removeAll()
                return .none
                
            case .clearMangaCacheConfirmed:
                return .concatenate(
                    databaseClient.retrieveAllCachedMangas()
                        .receive(on: DispatchQueue.main)
                        .catchToEffect(Action.cachedMangaRetrieved),
                    
                    cacheClient.clearCache().fireAndForget(),
                    
                    .task { .recomputeCacheSize }
                )
                
            case .cancelTapped:
                state.confirmationDialog = nil
                return .none
                
            case .cachedMangaRetrieved(let result):
                switch result {
                case .success(let mangaList):
                    var effects: [Effect<Action, Never>] = [
                        databaseClient.deleteAllMangas().fireAndForget()
                    ]
                    
                    effects += mangaList.map { manga in
                        cacheClient
                            .removeAllCachedChapterIDsFromMemory(manga.id)
                            .fireAndForget()
                    }
                    
                    return .merge(effects)
                    
                case .failure:
                    return .none
                }
                
            case .cacheSizeComputed(let result):
                switch result {
                case .success(let size):
                    state.usedStorageSpace = size
                    return .none
                    
                case .failure(let error):
                    state.usedStorageSpace = 0
                    logger.error("Failed to compute cache size: \(error)")
                    return .none
                }
                
            case .binding(\.$config.autolockPolicy):
                if state.config.autolockPolicy != .never && state.config.blurRadius == Defaults.Security.minBlurRadius {
                    state.config.blurRadius = Defaults.Security.blurRadiusStep
                }
                
                fallthrough
                
            case .binding(\.$config.blurRadius):
                if state.config.blurRadius == Defaults.Security.minBlurRadius {
                    state.config.autolockPolicy = .never
                }
                
                fallthrough
                
            case .binding:
                return settingsClient.saveSettingsConfig(state.config).fireAndForget()
            }
        }
    }
}
