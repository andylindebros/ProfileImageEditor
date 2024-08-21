import Foundation
import SwiftUI
import UIKit

extension Array {
    func get(index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}

extension UIView {
    func removeAllSubViews() {
        for subview in subviews {
            subview.removeFromSuperview()
        }
    }
}

extension UIImage {
    func resize(to newSize: CGSize) -> UIImage {
        let image = UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }

        return image.withRenderingMode(renderingMode)
    }
}
