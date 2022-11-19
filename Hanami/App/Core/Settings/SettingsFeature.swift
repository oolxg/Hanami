//
//  SettingsStore.swift
//  Hanami
//
//  Created by Oleg on 10/10/2022.
//

import Foundation
import ComposableArchitecture


struct SettingsFeature: ReducerProtocol {
    struct State: Equatable {
        @BindableState var autolockPolicy: AutoLockPolicy = .never
        @BindableState var blurRadius = Defaults.Security.minBlurRadius
        @BindableState var useHighResImagesForCaching = false
        @BindableState var useHighResImagesForOnlineReading = false
        // size of all loaded mangas and coverArts, excluding cache and info in DB
        var usedStorageSize = 0.0
    }
    
    enum Action: BindableAction {
        case initSettings
        case settingsConfigRetrieved(Result<SettingsConfig, AppError>)
        case recomputeCacheSize
        case clearMangaCache
        case cacheSizeComputed(Result<Double, AppError>)
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.settingsClient) private var settingsClient
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
                return .concatenate(
                    cacheClient.clearCache().fireAndForget(),
                    
                    .task { .recomputeCacheSize }
                )
                
            case .cacheSizeComputed(let result):
                switch result {
                case .success(let size):
                    state.usedStorageSize = size
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
                
                return .none
                
            case .binding:
                return .none
            }
        }
    }
}
