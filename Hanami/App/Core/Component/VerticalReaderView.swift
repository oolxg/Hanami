//
//  VerticalReaderView.swift
//  Hanami
//
//  Created by Oleg on 23.12.22.
//

import SwiftUI
import NukeUI
import typealias IdentifiedCollections.IdentifiedArrayOf

struct VerticalReaderView: View {
    @State private var scrollerHeight: CGFloat = 0
    @State private var indicatorOffset: CGFloat = 0
    @State private var hideIndicatorLabel = true
    // MARK: - View's start offset after navbar
    @State private var startOffset: CGFloat = 0
    // MARK: - END scroll view declaration props
    
    @State private var timeOut: CGFloat = 0.3
    
    @State private var pages: IdentifiedArrayOf<Page>

    init(pagesURLs: [URL?]) {
        pages = .init(uniqueElements: pagesURLs.enumerated().map { Page(url: $1, index: $0) })
    }
    
    private struct Page: Identifiable {
        let url: URL?
        let index: Int
        var rect: CGRect = .zero
        var id: Int { index }
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: true) {
                LazyVStack {
                    ForEach(pages.indices, id: \.self) { i in
                        listCell(i)
                    }
                }
                .offset { rect in
                    // MARK: Whenever scrolling does resetting timer
                    if hideIndicatorLabel && rect.minY < 0 {
                        timeOut = 0
                        hideIndicatorLabel = false
                    }
                    // MARK: - Finding scroll indicator height
                    let viewHeight = geo.size.height + startOffset / 2
                    if rect.height != 0 {
                        scrollerHeight = viewHeight / rect.height * viewHeight
                    }

                    // MARK: - Finding scroll indicator position
                    let progress = rect.minY / (geo.size.height - rect.height)
                    indicatorOffset = progress * (geo.size.height - scrollerHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) { indicator }
            .coordinateSpace(name: "SCROLLER")
        }
        .background(Color.theme.background)
        .offset { rect in
            if startOffset != rect.minY {
                startOffset = rect.minY
            }
        }
        .onReceive(Timer.publish(every: 0.01, on: .main, in: .default).autoconnect()) { _ in
            // 0.6 - delay after which indicator will be hidden
            if timeOut < 0.6 {
                timeOut += 0.01
            } else if !hideIndicatorLabel {
                // MARK: Scrolling is finished
                hideIndicatorLabel = true
            }
        }
    }
    
    @MainActor @ViewBuilder private func listCell(_ index: Int) -> some View {
        ZoomableScrollView {
            LazyImage(url: pages[index].url) { state in
                if let image = state.image {
                    image
                        .resizingMode(.aspectFit)
                        .offset { rect in
                            pages[id: pages[index].id]?.rect = rect
                        }
                } else if state.isLoading || state.error != nil {
                    ProgressView(value: state.progress.fraction)
                        .progressViewStyle(GaugeProgressStyle(strokeColor: .theme.accent))
                        .frame(width: 50, height: 50)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .tint(.theme.accent)
                }
            }
        }
        .frame(idealHeight: 550)
        .frame(maxWidth: .infinity)
    }
    
    private var indicator: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 2, height: scrollerHeight)
            .overlay(alignment: .trailing) {
                Image(systemName: "bubble.middle.bottom.fill")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.ultraThinMaterial)
                    .frame(width: 45, height: 45)
                    .rotationEffect(.init(degrees: -90))
                    .overlay {
                        if let last = pages.last(where: { $0.rect.minY < $0.rect.height / 2 }) {
                            Text("\(last.index + 1)")
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .offset(x: -3)
                        } else {
                            Text("\(1)")
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .offset(x: -3)
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    .offset(x: hideIndicatorLabel ? 65 : 0)
                    .animation(
                        .interactiveSpring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.6),
                        value: hideIndicatorLabel
                    )
            }
            .padding(.trailing, 5)
            .offset(y: indicatorOffset)
    }
}
