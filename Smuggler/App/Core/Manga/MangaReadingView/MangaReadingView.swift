//
//  MangaReadingView.swift
//  Smuggler
//
//  Created by mk.pwnz on 16/06/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher

struct MangaReadingViewEnum: View {
    let store: Store<MangaReadingViewState, MangaReadingViewAction>
    
    var body: some View {
        SwitchStore(store) {
            CaseLet(
                state: /MangaReadingViewState.online,
                action: MangaReadingViewAction.online,
                then: OnlineMangaReadingView.init
            )
            
            CaseLet(
                state: /MangaReadingViewState.offline,
                action: MangaReadingViewAction.offline,
                then: OfflineMangaReadingView.init
            )
        }
    }
}
