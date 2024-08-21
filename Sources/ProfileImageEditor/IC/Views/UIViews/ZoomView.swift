import Foundation
import UIKit

extension IC.Views.UIViews {
    class ZoomView: UIScrollView, IdentifiableView {
        let id: UUID

        init(id: UUID) {
            self.id = id
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension IC.Views.UIViews {
    class NonZoomView: UIView, IdentifiableView {
        let id: UUID

        init(id: UUID) {
            self.id = id
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
