import Foundation
import UIKit

extension IC.Models {
    struct ImageModel: Identifiable, Equatable {
        public let id: UUID

        public let uiImage: UIImage?

        public var frame: CGRect = .zero
        public var position: CGPoint = .zero
        public var currentZoom: CGFloat = 1
        public init(id: UUID = UUID(), uiImage: UIImage? = nil) {
            self.id = id
            self.uiImage = uiImage
        }
    }
}
