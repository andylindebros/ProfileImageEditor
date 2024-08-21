
import Combine
import Foundation
import PhotosUI
import SwiftUI

enum IC {}
extension IC {
    enum Models {}
    enum Views {}
}

extension IC.Views {
    enum UIViews {}
}

public protocol ProfileImageEditorViewModelProvider {
    func dispatch(_ action: ProfileImageEditorViewModel.Actions)
    var imageExportAction: PassthroughSubject<ExportedImagesModel, Never> { get }
    var canBeExported: Bool { get }
}

public class ProfileImageEditorViewModel: ObservableObject, ProfileImageEditorViewModelProvider {
    public init() {
        imageEditorViewModel = .init()
        subscriber = imageEditorViewModel.exportImagePublisher.sink { [weak self] model in
            self?.imageExportAction.send(model)
        }
    }

    public let imageExportAction = PassthroughSubject<ExportedImagesModel, Never>()

    let imageEditorViewModel: IC.ViewModel
    private(set) var cropSize: CGSize = .zero
    private var subscriber: Cancellable?
    @Published private(set) var shouldPresent = true
    @Published private(set) var imageState: ImageState = .empty
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            if let imageSelection {
                let progress = loadTransferable(from: imageSelection)
                imageState = .loading(progress)
            } else {
                imageState = .empty
            }
        }
    }
}

public extension ProfileImageEditorViewModel {
    var canBeExported: Bool {
        imageState.isSuccess
    }

    func dispatch(_ action: Actions) {
        Task {
            await dispatch(action)
        }
    }

    enum Actions {
        case exportImage(withSize: CGFloat? = nil)
        case restart
    }
}

extension ProfileImageEditorViewModel {
    func setShouldPresent(to newValue: Bool) {
        shouldPresent = newValue
    }

    @MainActor func dispatch(_ action: Actions) async {
        switch action {
        case .restart:
            imageState = .empty
            imageSelection = nil
            shouldPresent = true

        case let .exportImage(requestedSize):
            imageEditorViewModel.dispatch(.exportImage(withSize: cropSize, requestedSize: CGSize(width: requestedSize ?? 100, height: requestedSize ?? 100)))
        }
    }

    func setCropSize(to size: CGSize) {
        cropSize = size
    }

    enum ImageState {
        case empty
        case loading(Progress)
        case success(Image)
        case failure(Error)

        var isSuccess: Bool {
            if case Self.success = self {
                true
            } else {
                false
            }
        }
    }

    enum ProfileImageError: Error {
        case importFailed
        case imageInvalid
    }

    struct ProfileImageModel: Transferable {
        let image: Image

        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(importedContentType: .image) { data in
                guard let uiImage = UIImage(data: data) else {
                    throw ProfileImageError.importFailed
                }
                let image = Image(uiImage: uiImage)
                return Self(image: image)
            }
        }
    }
}

private extension ProfileImageEditorViewModel {
    func loadTransferable(from imageSelection: PhotosPickerItem) -> Progress {
        imageSelection.loadTransferable(type: ProfileImageEditorViewModel.ProfileImageModel.self) { result in
            DispatchQueue.main.async { [weak self] in
                guard let self, imageSelection == self.imageSelection else {
                    return
                }
                switch result {
                case let .success(profileImage?):
                    self.imageState = .success(profileImage.image)

                case .success(nil):
                    self.imageState = .empty
                case let .failure(error):
                    self.imageState = .failure(error)
                }
            }
        }
    }
}
