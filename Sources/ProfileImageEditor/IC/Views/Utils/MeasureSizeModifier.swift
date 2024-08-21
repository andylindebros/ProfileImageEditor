import Foundation
import SwiftUI

struct MeasureSizeModifier: ViewModifier {
    let onChange: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geo -> Color in
                    DispatchQueue.main.async {
                        self.onChange(geo.size)
                    }
                    return .clear
                }
            }
    }
}

extension View {
    func measureSize(onChange: @escaping (CGSize) -> Void) -> some View {
        modifier(MeasureSizeModifier(onChange: onChange))
    }
}
