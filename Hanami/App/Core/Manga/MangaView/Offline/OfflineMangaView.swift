//
//  OfflineMangaView.swift
//  Hanami
//
//  Created by Oleg on 23/07/2022.
//

import SwiftUI
import ComposableArchitecture
import Kingfisher
import ModelKit
import Utils
import UIComponents
import HUD

struct OfflineMangaView: View {
    let store: StoreOf<OfflineMangaFeature>
    let blurRadius: CGFloat
    @State private var headerOffset: CGFloat = 0
    @State private var showMangaDeletionDialog = false
    @State private var headerOverlayGradientColor = Color.clear
    @Namespace private var tabAnimationNamespace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var hud = HUD.liveValue

    private var isCoverArtDisappeared: Bool {
        headerOffset <= -450
    }
    
    private  struct ViewState: Equatable {
        let currentPageIndex: Int?
        let lastReadChapterAvailable: Bool
        let isMangaReadingViewPresented: Bool
        
        init(state: OfflineMangaFeature.State) {
            currentPageIndex = state.pagesState?.currentPageIndex
            lastReadChapterAvailable = state.lastReadChapter.hasValue && state.pagesState.hasValue
            isMangaReadingViewPresented = state.isMangaReadingViewPresented
        }
    }
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            ScrollView(showsIndicators: false) {
                LazyVStack(pinnedViews: .sectionHeaders) {
                    header
                        .id("header")
                    
                    Section {
                        mangaBodyView
                    } header: {
                        pinnedNavigation
                    } footer: {
                        footer
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack {
                    if viewStore.lastReadChapterAvailable {
                        continueReadingButton
                            .frame(maxWidth: .infinity)
                            .transition(.move(edge: .bottom))
                            .offset(y: 40)
                    }
                }
                .animation(.linear, value: viewStore.lastReadChapterAvailable)
            }
            .animation(.linear, value: isCoverArtDisappeared)
            .animation(.default, value: viewStore.currentPageIndex)
            .onAppear { viewStore.send(.onAppear) }
            .overlay(
                Rectangle()
                    .fill(Color.theme.background)
                    .frame(height: DeviceUtil.hasTopNotch ? 50 : 20)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isCoverArtDisappeared ? 1 : 0)
            )
            .navigationBarHidden(true)
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)
            .fullScreenCover(
                isPresented: viewStore.binding(
                    get: \.isMangaReadingViewPresented,
                    send: OfflineMangaFeature.Action.nowReadingViewStateDidUpdate
                ),
                content: mangaReadingView
            )
            .tint(.theme.accent)
            .background(Color.theme.background)
            .hud(
                isPresented: $hud.isPresented,
                message: hud.message,
                iconName: hud.iconName,
                backgroundColor: hud.backgroundColor
            )
        }
    }
}

extension OfflineMangaView {
    private func mangaReadingView() -> some View {
        IfLetStore(
            store.scope(
                state: \.mangaReadingViewState,
                action: OfflineMangaFeature.Action.mangaReadingViewAction
            )
        ) { readingStore in
            OfflineMangaReadingView(
                store: readingStore,
                blurRadius: blurRadius
            )
            .environment(\.colorScheme, colorScheme)
        }
    }
    
    private var footer: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            HStack(spacing: 0) {
                Text("All information on this page provided by ")
                
                Text("MANGADEX")
                    .fontWeight(.semibold)
            }
            .font(.caption2)
            .foregroundColor(.gray)
            .padding(.horizontal)
            .padding(.bottom, viewStore.lastReadChapterAvailable ? 50 : 5)
        }
    }
    
    private var header: some View {
        WithViewStore(store, observe: \.coverArtPath) { viewStore in
            GeometryReader { geo in
                let minY = geo.frame(in: .named("scroll")).minY
                let height = geo.size.height + minY
                
                KFImage(viewStore.state)
                    .onlyFromCache()
                    .onSuccess { result in
                        if let avgColor = result.image.averageColor {
                            headerOverlayGradientColor = Color(uiColor: avgColor)
                        }
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: height > 0 ? height : 0, alignment: .center)
                    .overlay(headerOverlay)
                    .cornerRadius(0)
                    .offset(y: -minY)
            }
            .frame(height: 450)
        }
    }
    
    private var headerOverlay: some View {
        WithViewStore(store, observe: \.manga) { viewStore in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [ headerOverlayGradientColor.opacity(0.1), headerOverlayGradientColor.opacity(0.8) ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .animation(.linear, value: headerOverlayGradientColor)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        backButton
                        
                        Spacer()
                        
                        deleteButton
                    }
                    
                    Spacer()
                    
                    HStack {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(viewStore.state.attributes.status.color)
                                .frame(width: 10, height: 10)
                                // circle disappears on scroll down, 'drawingGroup' helps to fix it
                                .drawingGroup()
                            
                            Text(viewStore.state.attributes.status.rawValue.capitalized)
                                .foregroundColor(.theme.foreground)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    
                    Text(viewStore.state.title)
                        .font(.title.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(5)
                }
                .padding(.horizontal)
                .padding(.top, DeviceUtil.hasTopNotch ? 40 : 15)
                .padding(.bottom, 25)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(headerOverlayOpacity)
        }
    }
    
    // when user scrolls up, we make all text and gradient on header slowly disappear
    private var headerOverlayOpacity: Double {
        if headerOffset < 0 { return 1 }
        
        let opacity = 1 - headerOffset * 0.01
        
        return max(opacity, 0)
    }
    
    
    private var deleteButton: some View {
        Button {
            showMangaDeletionDialog = true
        } label: {
            Image(systemName: "trash")
                .foregroundColor(.theme.foreground)
                .padding(.vertical)
        }
        .confirmationDialog(
            "Are you sure you want delete this manga and all chapters from device?",
            isPresented: $showMangaDeletionDialog
        ) {
            Button("Delete", role: .destructive) {
                self.dismiss()
                store.send(.deleteMangaButtonTapped)
            }
            
            Button("Cancel", role: .cancel) {
                showMangaDeletionDialog = false
            }
        } message: {
            Text("Are you sure you want delete this manga and all chapters from device?")
        }
        .font(.title3)
    }
    
    private var backButton: some View {
        Button {
            self.dismiss()
        } label: {
            Image(systemName: "xmark")
                .foregroundColor(.theme.foreground)
                .padding(.vertical)
        }
        .transition(.opacity)
        .font(.title3)
    }
    
    private var mangaBodyView: some View {
        WithViewStore(store, observe: \.selectedTab) { viewStore in
            switch viewStore.state {
            case .chapters:
                IfLetStore(
                    store.scope(
                        state: \.pagesState,
                        action: OfflineMangaFeature.Action.pagesAction
                    ),
                    then: PagesView.init
                )
                .environment(\.colorScheme, colorScheme)
            case .info:
                aboutTab
            }
        }
        .padding(.horizontal, 5)
    }
    
    private var aboutTab: some View {
        WithViewStore(store, observe: \.manga) { viewStore in
            VStack(alignment: .leading, spacing: 15) {
                if !viewStore.state.authors.isEmpty {
                    VStack(alignment: .leading) {
                        Text(viewStore.state.authors.count > 1 ? "Authors" : "Author")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        FlexibleView(
                            data: viewStore.state.authors.map(\.attributes.name),
                            spacing: 10,
                            alignment: .leading,
                            content: makeChipsView
                        )
                        .padding(.horizontal, 5)
                    }
                }
                
                if let description = viewStore.state.description {
                    VStack(alignment: .leading) {
                        Text("Description")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        Text(LocalizedStringKey(description))
                            .padding(.horizontal, 10)
                    }
                }
                
                tags
            }
        }
    }
    
    private var tags: some View {
        WithViewStore(store, observe: \.manga) { viewStore in
            VStack(alignment: .leading) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.black)
                
                Divider()
                
                FlexibleView(
                    data: viewStore.state.attributes.tags.map(\.name.capitalized),
                    spacing: 10,
                    alignment: .leading,
                    content: makeChipsView
                )
                .padding(.horizontal, 5)
                
                if let demographic = viewStore.state.attributes.publicationDemographic?.rawValue {
                    VStack(alignment: .leading) {
                        Text("Demographic")
                            .font(.headline)
                            .fontWeight(.black)
                        
                        Divider()
                        
                        makeChipsView(text: demographic.capitalized)
                            .padding(5)
                    }
                    .frame(minHeight: 20)
                }
            }
        }
    }
    
    @ViewBuilder private func makeChipsView(text: String) -> some View {
        Text(text)
            .font(.callout)
            .lineLimit(1)
            .padding(10)
            .foregroundColor(.theme.foreground)
            .background(Color.theme.darkGray)
            .cornerRadius(10)
    }
    
    private var pinnedNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 25) {
                backButton
                    .opacity(isCoverArtDisappeared ? 1 : 0)
                
                ForEach(OfflineMangaFeature.Tab.allCases, content: makeTabLabel)
            }
            .offset(x: isCoverArtDisappeared ? 0 : -40)
            .padding(.leading)
            .padding(.top, DeviceUtil.hasTopNotch ? 20 : 0)
            .padding(.bottom, 5)
        }
        .animation(.linear(duration: 0.2), value: isCoverArtDisappeared)
        .background(Color.theme.background)
        .offset(y: headerOffset > 0 ? 0 : DeviceUtil.hasTopNotch ? -headerOffset / 10 : 20)
        .modifier(MangaViewOffsetModifier(offset: $headerOffset))
    }
    
    private var continueReadingButton: some View {
        Button {
            store.send(.continueReadingButtonTapped)
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.theme.accent)
                .overlay {
                    Text("Continue reading!")
                        .foregroundColor(.black)
                        .fontWeight(.semibold)
                        .padding(.bottom, 15)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .padding(.horizontal, 5)
        }
    }
    
    /// Makes label for navigation through MangaView
    private func makeTabLabel(for tab: OfflineMangaFeature.Tab) -> some View {
        WithViewStore(store, observe: \.selectedTab) { viewStore in
            VStack(spacing: 12) {
                Text(tab.rawValue)
                    .fontWeight(.semibold)
                    .foregroundColor(viewStore.state == tab ? .theme.foreground : .gray)
                
                ZStack {
                    if viewStore.state == tab {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.theme.foreground)
                            .matchedGeometryEffect(id: "tab", in: tabAnimationNamespace)
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewStore.send(.mangaTabButtonTapped(tab), animation: .easeInOut)
            }
        }
    }
    
    private struct MangaViewOffsetModifier: ViewModifier {
        @Binding var offset: CGFloat
        @State private var startValue: CGFloat = 0
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: MangaViewOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                            .onPreferenceChange(MangaViewOffsetKey.self) { value in
                                if startValue == 0 {
                                    startValue = value
                                }
                                
                                offset = value - startValue
                            }
                    }
                )
        }
    }
    
    private struct MangaViewOffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
