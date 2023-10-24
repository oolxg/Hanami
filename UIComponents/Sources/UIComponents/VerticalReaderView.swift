//
//  VerticalReaderView.swift
//  Hanami
//
//  Created by Oleg on 23.12.22.
//

import SwiftUI
import Kingfisher
import typealias IdentifiedCollections.IdentifiedArrayOf
import Utils

public struct VerticalReaderView: View {
    @State private var scrollerHeight: CGFloat = 0
    @State private var indicatorOffset: CGFloat = 0
    @State private var hideIndicatorLabel = true
    // MARK: - View's start offset after navbar
    @State private var startOffset: CGFloat = 0
    // MARK: - END scroll view declaration props
    
    @State private var timeOut: CGFloat = 0.3
    @State private var pages: IdentifiedArrayOf<Page>
    
    private struct Page: Identifiable {
        let url: URL?
        let index: Int
        var height: CGFloat
        var rect: CGRect = .zero
        var id: Int { index }
    }
    
    public init(pagesURLs: [URL?]) {
        pages = IdentifiedArrayOf(
            uniqueElements: pagesURLs
                .enumerated()
                .map { Page(url: $1, index: $0, height: 550) }
        )
    }
    
    public var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(pages) { page in
                        cell(for: page)
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
                    
                    if !progress.isNaN {
                        indicatorOffset = progress * (geo.size.height - scrollerHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) { indicator }
            .coordinateSpace(name: "SCROLLER")
        }
        .background(Color.theme.background)
        .offset { rect in
            startOffset = rect.minY
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
    
    @ViewBuilder private func cell(for page: Page) -> some View {
        ZoomableScrollView {
            KFImage(page.url)
                .placeholder { progress in
                    ProgressView(value: progress.fractionCompleted)
                        .progressViewStyle(GaugeProgressStyle(strokeColor: .theme.accent))
                        .frame(width: 50, height: 50)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .tint(.theme.accent)
                }
                .onSuccess { success in
                    let imageSize = success.image.size
                    print(imageSize)
                    let ratio = DeviceUtil.deviceScreenSize.width / imageSize.width
                    pages[page.index].height = imageSize.height * ratio
                }
                .resizable()
                .scaledToFit()
                .offset { rect in
                    pages[page.index].rect = rect
                }
        }
        .frame(height: page.height)
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
                        if let last = pages.last(where: { $0.rect.minY < 0 }) {
                            Text("\(last.index + 1)")
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .offset(x: -4)
                        } else {
                            Text("1")
                                .fontWeight(.black)
                                .foregroundColor(.white)
                                .offset(x: -4)
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    .offset(x: hideIndicatorLabel ? 65 : 0)
                    .animation(
                        .interactiveSpring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.6),
                        value: hideIndicatorLabel
                    )
            }
            .padding(.trailing, 6)
            .offset(y: indicatorOffset)
            .animation(.linear, value: indicatorOffset)
    }
}

extension View {
    @ViewBuilder func offset(completion: @escaping (CGRect) -> Void) -> some View {
        self
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: OffsetKey.self, value: geo.frame(in: .named("SCROLLER")))
                        .onPreferenceChange(OffsetKey.self) { newValue in
                            completion(newValue)
                        }
                }
            }
    }
}

private struct OffsetKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
