//
//  SettingsStore.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import Foundation
import ComposableArchitecture
import Kingfisher
import ModelKit
import Utils
import Logger
import SettingsClient

struct SettingsFeature: ReducerProtocol {
    struct State: Equatable {
        @BindingState var config = SettingsConfig(
            autolockPolicy: .never,
            blurRadius: Defaults.Security.minBlurRadius,
            useHigherQualityImagesForOnlineReading: false,
            useHigherQualityImagesForCaching: false,
            colorScheme: 0,
            readingFormat: SettingsConfig.ReadingFormat.vertical,
            iso639Language: ISO639Language.deviceLanguage ?? .en
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
        case cachedMangaRetrieved([CoreDataMangaEntry])
        case cancelTapped
        case cacheSizeComputed(Result<Double, AppError>)
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.imageClient) private var imageClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .initSettings:
                return .run { send in
                    let result = await settingsClient.retireveSettingsConfig()
                    await send(.settingsConfigRetrieved(result))
                    await send(.recomputeCacheSize)
                }
                
            case .settingsConfigRetrieved(let result):
                switch result {
                case .success(let config):
                    state.config = config
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to retrieve settings config: \(error)")
                    // for the case when app launched for the first time
                    settingsClient.updateSettingsConfig(state.config)
                    return .none
                }
                
            case .recomputeCacheSize:
                return .run { send in
                    let result = await cacheClient.computeCacheSize()
                    await send(.cacheSizeComputed(result))
                }
                    
                
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
                imageClient.clearCache()
                return .none
                
            case .clearMangaCacheConfirmed:
                cacheClient.clearCache()
                
                return .run { send in
                    let cachedManga = await databaseClient.retrieveAllCachedMangas()
                    await send(.cachedMangaRetrieved(cachedManga))
                }
                
            case .cancelTapped:
                state.confirmationDialog = nil
                return .none
                
            case .cachedMangaRetrieved(let cachedManga):
                for entry in cachedManga {
                    cacheClient.removeAllCachedChapterIDsFromMemory(for: entry.manga.id)
                }
                
                databaseClient.deleteAllManga()
                
                return .run { await $0(.recomputeCacheSize) }
                
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
                settingsClient.updateSettingsConfig(state.config)
                return .none
            }
        }
    }
}
