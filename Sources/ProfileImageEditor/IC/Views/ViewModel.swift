import Combine
import SwiftUI

extension IC {
    class ViewModel: ObservableObject {
        init() {
            items = []
            selectedIndex = 0
            isZoomed = false
        }

        let exportImagePublisher = PassthroughSubject<ExportedImagesModel, Never>()

        @Published private(set) var items: [IC.Models.ImageModel]
        @Published private(set) var selectedIndex: Int
        @Published private(set) var isZoomed: Bool

        var isScrolling = false

        @MainActor func dispatch(_ action: Action) {
            switch action {
            case let .registerPosition(for: imageModel, withValue: point, _):
                if let index = items.firstIndex(where: { $0.id == imageModel.id }) {
                    items[index].position = point
                    items[index].frame = imageModel.frame
                }
            case let .registerZoom(for: imageModel, withLevel: level):
                if let index = items.firstIndex(where: { $0.id == imageModel.id }) {
                    items[index].currentZoom = level
                    items[index].frame = imageModel.frame
                }
            case let .load(with: items):
                setItems(with: items)

            case let .setSelectedIndex(index):
                guard index < items.count else { return }
                selectedIndex = index

            case let .exportImage(size, requestedSize):
                guard
                    let imageModel = items.get(index: selectedIndex)
                else { return }
                Task { [weak self] in
                    await self?.exportImage(by: imageModel, withSize: size, requestedSize: requestedSize)
                }
            }
        }

        @MainActor private func exportImage(by imageModel: IC.Models.ImageModel, withSize destinationSize: CGSize, requestedSize: CGSize? = nil) async {
            let cropped = await cropImage(by: imageModel, withSize: destinationSize)

            exportImagePublisher.send(ExportedImagesModel(
                original: cropped,
                requested: requestedSize != nil ? cropped?.resize(to: requestedSize ?? .zero) : nil
            ))
        }

        private func cropImage(by imageModel: IC.Models.ImageModel, withSize destinationSize: CGSize) async -> UIImage? {
            guard
                let croppedImage = imageWithImage(model: imageModel, newSize: destinationSize)
            else { return nil }

            guard
                let cgImage = croppedImage.cgImage
            else { return nil }

            return UIImage(
                cgImage: cgImage,
                scale: imageModel.currentZoom,
                orientation: .up
            )
        }

        private func imageWithImage(model: IC.Models.ImageModel, newSize: CGSize) -> UIImage? {
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
            model.uiImage?.draw(in: CGRectMake(-model.position.x, -model.position.y, model.frame.size.width, model.frame.size.height))

            let newImage = UIGraphicsGetImageFromCurrentImageContext()

            UIGraphicsEndImageContext()
            return newImage
        }

        private func setItems(with newItems: [IC.Models.ImageModel]) {
            if items != newItems {
                let newIndex = findIndex(
                    withValue: selectedIndex,
                    in: newItems,
                    withLastIndex: items.get(index: selectedIndex)?.id
                )
                items = newItems
                selectedIndex = newIndex
            }
        }

        func setIsZoomed(withValue value: Bool) {
            isZoomed = value
        }

        private func findIndex(withValue selectedIndex: Int, in newItems: [IC.Models.ImageModel], withLastIndex lastIndexID: UUID?) -> Int {
            guard
                let lastIndexID = lastIndexID,
                let newIndex = newItems.firstIndex(where: { $0.id == lastIndexID })
            else {
                return selectedIndex > newItems.count ? 0 : selectedIndex
            }
            return newIndex
        }

        var selectedItemIsImage: Bool {
            true
        }

        var currentSelectImageIndex: Int? {
            guard
                selectedItemIsImage
            else {
                return nil
            }

            return selectedIndex - items.prefix(selectedIndex).count
        }
    }
}

extension IC.ViewModel {
    enum Action {
        case load(with: [IC.Models.ImageModel])
        case setSelectedIndex(Int)
        case exportImage(withSize: CGSize, requestedSize: CGSize?)
        case registerZoom(for: IC.Models.ImageModel, withLevel: CGFloat)
        case registerPosition(for: IC.Models.ImageModel, withValue: CGPoint, andFrame: CGRect)
    }
}
