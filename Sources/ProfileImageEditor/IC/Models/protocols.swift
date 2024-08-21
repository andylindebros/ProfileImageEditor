import Foundation
import UIKit

protocol CustomModelProvider: Identifiable {
    var id: UUID { get }
}

protocol IdentifiableView: Identifiable, UIView {
    var id: UUID { get }
}
