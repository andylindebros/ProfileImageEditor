import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: Carousel

extension IC.Views {
    struct Editor: UIViewControllerRepresentable {
        init(viewModel: IC.ViewModel, customViewProvider: ((any CustomModelProvider) -> UIView?)?) {
            self.viewModel = viewModel

            self.customViewProvider = customViewProvider
        }

        let viewModel: IC.ViewModel

        let customViewProvider: ((any CustomModelProvider) -> UIView?)?

        func makeUIViewController(context _: Context) -> IC.Views.EditorViewController {
            IC.Views.EditorViewController(viewModel: viewModel, customViewProvider: customViewProvider)
        }

        func updateUIViewController(_: IC.Views.EditorViewController, context _: Context) {}
    }
}

// MARK: Initializers

extension IC.Views {
    @MainActor class EditorViewController: UIViewController {
        init(viewModel: IC.ViewModel, customViewProvider: ((any CustomModelProvider) -> UIView?)?) {
            self.customViewProvider = customViewProvider
            self.viewModel = viewModel
            isScrolling = false
            isZooming = false
            super.init(nibName: nil, bundle: nil)
            scrollView.delegate = self
            observeViewModel()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        let viewModel: IC.ViewModel
        let customViewProvider: ((any CustomModelProvider) -> UIView?)?

        private var itemsSubscriber: Cancellable?
        private var resizeSubScriber: Cancellable?
        private var selectedIndexSubscriber: Cancellable?
        private var containers = [any IdentifiableView]()
        private var isRotating: Bool = false
        private var isScrolling: Bool
        private var isZooming: Bool
        private var orientation: UIDeviceOrientation = UIDevice.current.orientation

        private var selectedIndex = 0 {
            didSet {
                if selectedIndex != viewModel.selectedIndex {
                    viewModel.dispatch(.setSelectedIndex(selectedIndex))
                }
                // handleImageCache()
            }
        }

        lazy var scrollView: UIScrollView = {
            let scrollView = UIScrollView()
            scrollView.isPagingEnabled = true
            scrollView.alwaysBounceHorizontal = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.contentInsetAdjustmentBehavior = .never
            return scrollView
        }()
    }
}

// MARK: Life cycle

extension IC.Views.EditorViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.frame = CGRect(origin: .zero, size: view.frame.size)
        view.addSubview(scrollView)
        addDoubleTapToZoom(to: view)
    }
}

// MARK: List calculations

private extension IC.Views.EditorViewController {
    /// Gets the number of underlying images
    var numberOfItems: Int {
        viewModel.items.count
    }

    func findIndex(withValue selectedIndex: Int, in newItems: [IC.Models.ImageModel]) -> Int {
        guard
            let currentSelectedID = containers.get(index: viewModel.selectedIndex)?.id,
            let newIndex = newItems.firstIndex(where: { $0.id == currentSelectedID })
        else {
            return selectedIndex > newItems.count ? 0 : selectedIndex
        }
        return newIndex
    }

    var selectedPlaceholder: UIView? {
        imageView(for: selectedIndex)
    }

    var pageAtContentOffset: Int? {
        let page = Int(roundf((Float(containers.count) / Float(scrollView.contentSize.width)) * Float(scrollView.contentOffset.x)))
        // Bail if scrolling outside of page range.
        if page < 0 || page >= containers.count && page >= scrollView.subviews.count {
            return nil
        }

        return page
    }

    var selectedScrollView: UIScrollView? {
        containers.get(index: selectedIndex) as? UIScrollView
    }

    func imageView(for index: Int) -> IC.Views.UIViews.ImageView? {
        guard
            let zoomView = containers.get(index: index) as? IC.Views.UIViews.ZoomView,
            let imageView = zoomView.subviews.first as? IC.Views.UIViews.ImageView
        else { return nil }
        return imageView
    }
}

// MARK: Resizers and repositions

private extension IC.Views.EditorViewController {
    func updatePositionAndFrame() {
        resizeContainerViews()
        centerScrollViewContents()
        scroll(toPage: selectedIndex)
        repositionViews()
    }

    func resizeContainerViews() {
        scrollView.frame.size = view.frame.size
        scrollView.contentSize = contentSize
    }

    func repositionViews() {
        scrollView.contentSize = CGSize(width: scrollView.frame.width * CGFloat(numberOfItems), height: scrollView.frame.height)
        containers.enumerated().forEach { index, zoomView in
            zoomView.frame = CGRect(
                origin: CGPoint(x: CGFloat(index) * self.scrollView.bounds.width, y: 0),
                size: self.scrollView.frame.size
            )
        }
    }

    func centerScrollViewContents() {
        containers.indices.forEach { imageView(for: $0)?.centerContent(in: scrollView) }
    }
}

// MARK: UIView helpers

private extension IC.Views.EditorViewController {
    func render() {
        scrollView.removeAllSubViews()
        let currentContainers = containers
        containers = []

        for model in viewModel.items {
            let zoomView = currentContainers.first(where: { $0.id == model.id }) as? IC.Views.UIViews.ZoomView ?? zoomableScrollView(withID: model.id, placeholder: makePlaceholderView(for: model))

            containers.append(zoomView)
            scrollView.addSubview(zoomView)
        }
        scrollView.contentSize = contentSize
        updatePositionAndFrame()
        loadImages()
    }

    func loadImages() {
        let imagesToLoad = containers
            .compactMap { ($0 as? IC.Views.UIViews.ZoomView)?.subviews.first as? IC.Views.UIViews.ImageView }

        for imageView in imagesToLoad {
            imageView.loadImage()
            if let zoomView = imageView.superview as? IC.Views.UIViews.ZoomView {
                let minScaleResult = minScale(for: imageView, in: zoomView)

                if minScaleResult > zoomView.zoomScale {
                    zoomView.setZoomScale(minScaleResult, animated: true)
                    viewModel.dispatch(.registerZoom(for: imageView.model, withLevel: minScaleResult))
                }
            }
        }
    }

    func zoomableScrollView(withID id: UUID, placeholder: UIView) -> IC.Views.UIViews.ZoomView {
        let zoomView = IC.Views.UIViews.ZoomView(id: id)
        zoomView.frame = CGRect(origin: .zero, size: scrollView.frame.size)
        zoomView.zoomScale = 1
        zoomView.delegate = self
        zoomView.minimumZoomScale = 1.0
        zoomView.maximumZoomScale = 8.0
        zoomView.showsHorizontalScrollIndicator = false
        zoomView.showsVerticalScrollIndicator = false
        zoomView.contentInsetAdjustmentBehavior = .never
        zoomView.addSubview(placeholder)
        return zoomView
    }

    func makePlaceholderView(for model: IC.Models.ImageModel) -> IC.Views.UIViews.ImageView {
        let ImageUIView = IC.Views.UIViews.ImageView(model: model)
        ImageUIView.frame = CGRect(origin: .zero, size: scrollView.frame.size)
        return ImageUIView
    }
}

// MARK: - Scroll View Helpers

private extension IC.Views.EditorViewController {
    var contentSize: CGSize {
        CGSize(width: CGFloat(numberOfItems) * scrollView.frame.width, height: scrollView.frame.height)
    }

    func scroll(toPage page: Int, animated: Bool = false) {
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * scrollView.frame.width, y: 0), animated: animated)
    }
}

// MARK: Zooming

private extension IC.Views.EditorViewController {
    func addDoubleTapToZoom(to view: UIView) {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
    }

    @objc func toggleZoom(_ gesture: UIGestureRecognizer) {
        guard
            let zoomView = selectedScrollView as? IC.Views.UIViews.ZoomView,
            let imageView = zoomView.subviews.first as? IC.Views.UIViews.ImageView
        else {
            return
        }

        let minScale = minScale(for: imageView, in: zoomView)
        if zoomView.zoomScale > minScale {
            zoomView.setZoomScale(zoomView.minimumZoomScale, animated: true)
            viewModel.dispatch(.registerZoom(for: imageView.model, withLevel: zoomView.minimumZoomScale))
        } else {
            let location = gesture.location(ofTouch: 0, in: zoomView)
            let zoomRect = zoomedRect(forScale: zoomView.maximumZoomScale - (zoomView.maximumZoomScale * 0.60), withCenter: location)
            zoomView.zoom(to: zoomRect, animated: true)
        }
    }

    func zoomedRect(forScale scale: CGFloat, withCenter center: CGPoint) -> CGRect {
        guard
            let zoomView = selectedPlaceholder as? IC.Views.UIViews.ImageView
        else {
            return CGRect.zero
        }
        var zoomRect = CGRect.zero
        zoomRect.size.height = zoomView.frame.size.height / scale
        zoomRect.size.width = zoomView.frame.size.width / scale

        let convertedCenter = zoomView.convert(center, from: view)
        zoomRect.origin.x = convertedCenter.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = convertedCenter.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }
}

// MARK: UIScrollViewDelegate

extension IC.Views.EditorViewController: UIScrollViewDelegate {
    /// Sets the selected zoomScrollView
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateSelectedIndexIfNeeded(with: scrollView)

        guard
            let zoomView = scrollView as? IC.Views.UIViews.ZoomView,
            let imageView = zoomView.subviews.first as? IC.Views.UIViews.ImageView
        else { return }

        viewModel.dispatch(.registerPosition(for: imageView.model, withValue: scrollView.contentOffset, andFrame: imageView.frame))
    }

    private func updateSelectedIndexIfNeeded(with scrollView: UIScrollView) {
        guard
            !viewModel.isScrolling,
            !isRotating,
            scrollView == self.scrollView,
            containers.count > 0,
            scrollView.contentSize.width > 0,
            let page = pageAtContentOffset,
            page != selectedIndex
        else { return }

        selectedScrollView?.setZoomScale(1.0, animated: true)
        selectedIndex = page
    }

    func scrollViewWillBeginDragging(_: UIScrollView) {
        viewModel.isScrolling = true
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate _: Bool) {
        viewModel.isScrolling = false
    }

    func scrollViewDidZoom(_: UIScrollView) {
        guard
            let zoomView = containers.get(index: selectedIndex) as? IC.Views.UIViews.ZoomView,
            let imageView = zoomView.subviews.first as? IC.Views.UIViews.ImageView
        else { return }
        imageView.centerContent(in: view)
    }

    func scrollViewWillBeginZooming(_: UIScrollView, with _: UIView?) {
        guard !viewModel.isZoomed else { return }
        viewModel.setIsZoomed(withValue: true)
        isZooming = true
    }

    func scrollViewDidEndZooming(_: UIScrollView, with _: UIView?, atScale scale: CGFloat) {
        viewModel.setIsZoomed(withValue: scale != 1.0)
        isZooming = false

        guard
            let zoomView = containers.get(index: selectedIndex) as? IC.Views.UIViews.ZoomView,
            let imageView = zoomView.subviews.first as? IC.Views.UIViews.ImageView
        else { return }

        let scaleResult = minScale(for: imageView, in: zoomView)

        if scaleResult > zoomView.zoomScale {
            zoomView.setZoomScale(scaleResult, animated: true)
            imageView.centerContent(in: zoomView)
        }

        viewModel.dispatch(.registerZoom(for: imageView.model, withLevel: scaleResult))
    }

    func minScale(for imageView: IC.Views.UIViews.ImageView, in _: IC.Views.UIViews.ZoomView) -> CGFloat {
        let widthRatio = imageView.frame.width / imageView.frame.height
        let height = scrollView.bounds.width / widthRatio
        let zoomScaleH = scrollView.bounds.height / height

        let heightRatio = imageView.frame.height / imageView.frame.width
        let width = scrollView.bounds.height / heightRatio
        let zoomScaleW = scrollView.bounds.width / width

        return max(zoomScaleH, zoomScaleW)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if scrollView.subviews.first(where: { $0 is IC.Views.UIViews.ZoomView }) != nil {
            return nil
        }

        if selectedScrollView == scrollView {
            return selectedPlaceholder
        } else {
            return nil
        }
    }
}

// MARK: ViewModel Observations

private extension IC.Views.EditorViewController {
    func observeViewModel() {
        itemsSubscriber = viewModel.$items.sink { [weak self] items in
            // Needs to be queued sinces the published value has not yet been updated in the viewModel
            DispatchQueue.main.async { [weak self] in
                let currentModels = self?.containers
                    .compactMap { ($0 as? IC.Views.UIViews.ZoomView)?.subviews.first as? IC.Views.UIViews.ImageView }
                    .compactMap { $0.model }.map { $0.id } ?? []

                // Don't re render if the list hasn't changed
                guard let self = self, items.map({ $0.id }) != currentModels else { return }

                self.render()

                self.handleSelectedIndexChanged(withValue: self.viewModel.selectedIndex, animated: false)
            }
        }

        selectedIndexSubscriber = viewModel.$selectedIndex.sink { [weak self] index in
            guard let self = self else { return }
            if index < self.containers.count, index != self.selectedIndex {
                self.handleSelectedIndexChanged(withValue: index)
            }
        }
    }

    func handleSelectedIndexChanged(withValue index: Int, animated: Bool = true) {
        if index < containers.count, index != selectedIndex {
            let distance = abs(selectedIndex - index)
            scroll(toPage: index, animated: animated ? distance < 3 : false)
        }
    }
}
