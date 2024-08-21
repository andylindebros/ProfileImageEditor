import Foundation
import UIKit

extension IC.Views.UIViews {
    @MainActor class ImageView: UIImageView, Sendable {
        var model: IC.Models.ImageModel

        private let activityIndicator = UIActivityIndicatorView()
        private var errorImageView: UIImageView?

        init(model: IC.Models.ImageModel) {
            self.model = model
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func loadImage() {
            if let image = model.uiImage {
                self.image = image
                resize(in: superview, to: image.size)
            }
        }

        static func resizedImage(from size: CGSize, constrainedTo constrainSize: CGSize) -> CGSize {
            let maxHeight = constrainSize.height
            let maxWidth = constrainSize.width
            let imageHeight = size.height
            let imageWidth = size.width
            let widthRatio = maxWidth / imageWidth
            let heightRatio = maxHeight / imageHeight
            let ratio = widthRatio < heightRatio ? widthRatio : heightRatio
            let newSize = CGSize(width: imageWidth * ratio, height: imageHeight * ratio)
            return newSize
        }

        func resize(in view: UIView?, to size: CGSize) {
            guard let view = view else { return }
            frame.size = Self.resizedImage(from: size, constrainedTo: view.frame.size)
            centerContent(in: view)
        }

        func centerContent(in containerView: UIView?) {
            guard let containerView = containerView else { return }
            let boundsSize = containerView.bounds
            var contentsFrame = frame
            if contentsFrame.size.width < boundsSize.width {
                contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0
            } else {
                contentsFrame.origin.x = 0.0
            }
            if contentsFrame.size.height < boundsSize.height {
                contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0
            } else {
                contentsFrame.origin.y = 0.0
            }
            frame = contentsFrame
            model.frame = contentsFrame
        }
    }
}

