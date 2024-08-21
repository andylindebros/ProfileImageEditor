import Foundation
import PhotosUI
import SwiftUI

public struct ProfileImageEditor: View {
    public init(viewModel: ProfileImageEditorViewModel) {
        self.viewModel = viewModel
    }

    @ObservedObject var viewModel: ProfileImageEditorViewModel

    public var body: some View {
        switch viewModel.imageState {
        case let .success(image):
            if let uiImage = image.render() {
                GeometryReader { geo in
                    IC.Views.Editor(viewModel: viewModel.imageEditorViewModel, customViewProvider: { _ in nil })
                        .onAppear {
                            viewModel.imageEditorViewModel.dispatch(.load(with: [.init(uiImage: uiImage)]))
                        }
                        .frame(width: geoSize(geoetry: geo).width, height: geoSize(geoetry: geo).width)
                        .mask {
                            Circle()
                                .fill(.black)
                                .frame(width: geoSize(geoetry: geo).width, height: geoSize(geoetry: geo).height)
                                .measureSize(onChange: { newSize in
                                    if newSize != viewModel.cropSize {
                                        viewModel.setCropSize(to: newSize)
                                    }
                                })
                                .frame(width: geoSize(geoetry: geo).width, height: geoSize(geoetry: geo).height)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

        default:
            Button(action: {
                viewModel.setShouldPresent(to: true)
            }) {
                Text("Open Photos")
            }
            .photosPicker(
                isPresented: Binding<Bool>(
                    get: { viewModel.shouldPresent },
                    set: { viewModel.setShouldPresent(to: $0) }
                ),
                selection: $viewModel.imageSelection,
                matching: .images
            )
        }
    }

    func geoSize(geoetry geo: GeometryProxy) -> CGSize {
        return CGSize(width: geo.size.width < geo.size.height ? geo.size.width : geo.size.height, height: geo.size.width < geo.size.height ? geo.size.width : geo.size.height)
    }
}
