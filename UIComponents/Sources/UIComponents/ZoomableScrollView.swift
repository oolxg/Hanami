//
//  ZoomableScrollView.swift
//  Hanami
//
//  Created by jtbandes
//  https://stackoverflow.com/a/64110231/11090054
//

import Foundation
import SwiftUI

public struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public func makeUIView(context: Context) -> UIScrollView {
        // set up the UIScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator  // for viewForZooming(in:)
        scrollView.maximumZoomScale = 5
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        // add a UITapGestureRecognizer to handle double-tap to zoom
        let doubleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTapGesture)
        )
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        // create a UIHostingController to hold our SwiftUI content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)

        return scrollView
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: content))
    }

    public func updateUIView(_ uiView: UIScrollView, context: Context) {
        // update the hosting controller's SwiftUI content
        context.coordinator.hostingController.rootView = self.content
        assert(context.coordinator.hostingController.view.superview == uiView)
    }

    // MARK: - Coordinator
    public class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }

        @objc func handleDoubleTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let scrollView = gestureRecognizer.view as? UIScrollView else { return }

            let newZoomScale: CGFloat = scrollView.zoomScale == 1 ? 3 : 1

            let pointInView = gestureRecognizer.location(in: hostingController.view)
            let width = scrollView.bounds.size.width / newZoomScale
            let height = scrollView.bounds.size.height / newZoomScale
            let x = pointInView.x - (width / 2.0)
            let y = pointInView.y - (height / 2.0)
            let rectToZoomTo = CGRect(x: x, y: y, width: width, height: height)
            scrollView.zoom(to: rectToZoomTo, animated: true)
        }
    }
}
