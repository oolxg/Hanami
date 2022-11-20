//
//  SettingsStore.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import Foundation
import ComposableArchitecture
import Nuke

struct SettingsFeature: ReducerProtocol {
    struct State: Equatable {
        @BindableState var autolockPolicy: AutoLockPolicy = .never
        @BindableState var blurRadius = Defaults.Security.minBlurRadius
        @BindableState var useHighResImagesForCaching = false
        @BindableState var useHighResImagesForOnlineReading = false
        // size of all loaded mangas and coverArts, excluding cache and info in DB
        var usedStorageSpace = 0.0
        var confirmationDialog: ConfirmationDialogState<Action>?
    }
    
    enum Action: BindableAction, Equatable {
        case initSettings
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case recomputeCacheSize
        case clearMangaCache
        
        case clearMangaCacheConfirmed
        case cancelTapped
        case cacheSizeComputed(Result<Double, AppError>)
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.settingsClient) private var settingsClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.logger) private var logger
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.hapticClient) private var hapticClient

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
                    state.blurRadius = config.blurRadius
                    state.autolockPolicy = config.autolockPolicy
                    state.useHighResImagesForCaching = config.useHighResImagesForCaching
                    state.useHighResImagesForOnlineReading = config.useHighResImagesForOnlineReading
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to retrieve settings config: \(error)")
                    return .none
                }
                
            case .recomputeCacheSize:
                return cacheClient.computeCacheSize()
                    .receive(on: DispatchQueue.main)
                    .eraseToEffect(Action.cacheSizeComputed)
                
            case .clearMangaCache:
                state.confirmationDialog = ConfirmationDialogState(
                    title: TextState("Delete all manga and cached images from device?"),
                    message: TextState("Delete all manga and cached images from device?"),
                    buttons: [
                        .destructive(TextState("Delete"), action: .send(.clearMangaCacheConfirmed)),
                        .cancel(TextState("Cancel"), action: .send(.cancelTapped))
                    ]
                )
                
                return .none
                
            case .clearMangaCacheConfirmed:
                Nuke.DataLoader.sharedUrlCache.removeAllCachedResponses()
                Nuke.ImageCache.shared.removeAll()

                return .concatenate(
                    databaseClient.deleteAllMangas().fireAndForget(),
                    
                    cacheClient.clearCache().fireAndForget(),
                    
                    .task { .recomputeCacheSize }
                )
                
            case .cancelTapped:
                state.confirmationDialog = nil
                return .none
                
            case .cacheSizeComputed(let result):
                switch result {
                case .success(let size):
                    state.usedStorageSpace = size
                    return .none
                    
                case .failure(let error):
                    logger.error("Failed to compute cache size: \(error)")
                    return .none
                }
                
            case .binding(\.$autolockPolicy):
                if state.autolockPolicy != .never && state.blurRadius == Defaults.Security.minBlurRadius {
                    state.blurRadius = Defaults.Security.blurRadiusStep
                }
                
                return settingsClient.saveSettingsConfig(
                    SettingsConfig(
                        autolockPolicy: state.autolockPolicy,
                        blurRadius: state.blurRadius,
                        useHighResImagesForOnlineReading: state.useHighResImagesForOnlineReading,
                        useHighResImagesForCaching: state.useHighResImagesForCaching
                    )
                )
                .fireAndForget()
                
            case .binding(\.$blurRadius):
                if state.blurRadius == Defaults.Security.minBlurRadius {
                    state.autolockPolicy = .never
                }
                
                return settingsClient.saveSettingsConfig(
                    SettingsConfig(
                        autolockPolicy: state.autolockPolicy,
                        blurRadius: state.blurRadius,
                        useHighResImagesForOnlineReading: state.useHighResImagesForOnlineReading,
                        useHighResImagesForCaching: state.useHighResImagesForCaching
                    )
                )
                .fireAndForget()
                
            case .binding(\.$useHighResImagesForCaching):
                return settingsClient.saveSettingsConfig(
                    SettingsConfig(
                        autolockPolicy: state.autolockPolicy,
                        blurRadius: state.blurRadius,
                        useHighResImagesForOnlineReading: state.useHighResImagesForOnlineReading,
                        useHighResImagesForCaching: state.useHighResImagesForCaching
                    )
                )
                .fireAndForget()
                
            case .binding(\.$useHighResImagesForOnlineReading):
                return settingsClient.saveSettingsConfig(
                    SettingsConfig(
                        autolockPolicy: state.autolockPolicy,
                        blurRadius: state.blurRadius,
                        useHighResImagesForOnlineReading: state.useHighResImagesForOnlineReading,
                        useHighResImagesForCaching: state.useHighResImagesForCaching
                    )
                )
                .fireAndForget()
        
            case .binding:
                return .none
            }
        }
    }
}
