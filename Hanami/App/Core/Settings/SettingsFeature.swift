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

@Reducer
struct SettingsFeature {
    struct State: Equatable {
        // size of all loaded mangas and coverArts, excluding cache and info in DB
        var usedStorageSpace = 0.0
        
        @BindingState var autolockPolicy: AutoLockPolicy = .never
        @BindingState var blurRadius = Defaults.Security.minBlurRadius
        @BindingState var useHigherQualityImagesForOnlineReading = false
        @BindingState var useHigherQualityImagesForCaching = false
        @BindingState var colorScheme = SettingsConfig.ColorScheme.default
        @BindingState var readingFormat: SettingsConfig.ReadingFormat = .vertical
        @BindingState var readingLanguage = ISO639Language.deviceLanguage ?? .en
        
        @PresentationState var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
    }
    
    enum Action: BindableAction, Equatable {
        case initSettings
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case recomputeCacheSize
        case clearImageCacheButtonTapped
        case clearMangaCacheButtonTapped
        case cachedMangaRetrieved([CoreDataMangaEntry])
        case cacheSizeComputed(Result<Double, AppError>)
        case binding(BindingAction<State>)
        
        case confirmationDialog(PresentationAction<ConfirmationDialog>)
        
        enum ConfirmationDialog {
            case clearMangaCacheConfirmed
            case cancelTapped
        }
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    @Dependency(\.mainQueue) private var mainQueue
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.imageClient) private var imageClient

    var body: some Reducer<State, Action> {
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
                    state.autolockPolicy = config.autolockPolicy
                    state.blurRadius = config.blurRadius
                    state.useHigherQualityImagesForOnlineReading = config.useHigherQualityImagesForOnlineReading
                    state.useHigherQualityImagesForCaching = config.useHigherQualityImagesForCaching
                    state.colorScheme = config.colorScheme
                    state.readingFormat = config.readingFormat
                    state.readingLanguage = config.readingLanguage
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to retrieve settings config: \(error)")
                    // for the case when app launched for the first time
                    let config = SettingsConfig(
                        autolockPolicy: state.autolockPolicy,
                        blurRadius: state.blurRadius,
                        useHigherQualityImagesForOnlineReading: state.useHigherQualityImagesForOnlineReading,
                        useHigherQualityImagesForCaching: state.useHigherQualityImagesForCaching,
                        colorScheme: state.colorScheme,
                        readingFormat: state.readingFormat,
                        iso639Language: state.readingLanguage
                    )
                    settingsClient.updateSettingsConfig(config)
                    return .none
                }
                
            case .recomputeCacheSize:
                return .run { send in
                    let result = await cacheClient.computeCacheSize()
                    await send(.cacheSizeComputed(result))
                }
                    
                
            case .clearMangaCacheButtonTapped:
                state.confirmationDialog = ConfirmationDialogState(
                    title: {
                        TextState("Delete all manga from device?")
                    },
                    actions: {
                        ButtonState(role: .destructive, action: .clearMangaCacheConfirmed) {
                            TextState("Delete")
                        }
                        
                        ButtonState(role: .cancel, action: .cancelTapped) {
                            TextState("Cancel")
                        }
                    }
                )
                
                return .none
                
            case .clearImageCacheButtonTapped:
                imageClient.clearCache()
                return .none
                
            case .confirmationDialog(.presented(.clearMangaCacheConfirmed)):
                cacheClient.clearCache()
                
                return .run { send in
                    let cachedManga = await databaseClient.retrieveAllCachedMangas()
                    await send(.cachedMangaRetrieved(cachedManga))
                }
                
            case .confirmationDialog(.presented(.cancelTapped)):
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
                
            case .binding(\.$autolockPolicy):
                if state.autolockPolicy != .never && state.blurRadius == Defaults.Security.minBlurRadius {
                    state.blurRadius = Defaults.Security.blurRadiusStep
                }
                
                fallthrough
                
            case .binding(\.$blurRadius):
                if state.blurRadius == Defaults.Security.minBlurRadius {
                    state.autolockPolicy = .never
                }
                
                fallthrough
                
            case .binding:
                let config = SettingsConfig(
                    autolockPolicy: state.autolockPolicy,
                    blurRadius: state.blurRadius,
                    useHigherQualityImagesForOnlineReading: state.useHigherQualityImagesForOnlineReading,
                    useHigherQualityImagesForCaching: state.useHigherQualityImagesForCaching,
                    colorScheme: state.colorScheme,
                    readingFormat: state.readingFormat,
                    iso639Language: state.readingLanguage
                )
                settingsClient.updateSettingsConfig(config)

                return .none
                
            case .confirmationDialog:
                return .none
            }
        }
    }
}
