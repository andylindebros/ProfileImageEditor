import Foundation
import PhotosUI
import SwiftUI

public struct ProfileImageEditor: View {
    public init(
        viewModel: ProfileImageEditorViewModel,
        systemIcon: String? = "person.fill",
        personIconColor: Color = Color.gray,
        backgroundGradientColors: [Color] = [Color(uiColor: UIColor.darkGray), .black],
        borderColor: Color? = .gray
    ) {
        self.viewModel = viewModel
        self.systemIcon = systemIcon
        self.personIconColor = personIconColor
        self.backgroundGradientColors = backgroundGradientColors
        self.borderColor = borderColor
    }

    @ObservedObject var viewModel: ProfileImageEditorViewModel

    let systemIcon: String?
    let personIconColor: Color
    let backgroundGradientColors: [Color]
    let borderColor: Color?

    public var body: some View {
        GeometryReader { geo in
            photoPicker {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: backgroundGradientColors, startPoint: .top, endPoint: .bottom)
                    )
                    if let systemIcon, viewModel.sourceImage == nil {
                        Image(systemName: systemIcon)
                            .resizable()
                            .scaledToFill()
                            .foregroundStyle(personIconColor)
                            .padding([.top, .horizontal], geoSize(geoetry: geo).width / 4)
                    }
                    IC.Views.Editor(viewModel: viewModel.imageEditorViewModel, customViewProvider: { _ in nil })
                        .onChange(of: viewModel.sourceImage) { _ in
                            if let uiImage = viewModel.sourceImage?.image.render() {
                                viewModel.imageEditorViewModel.dispatch(.load(with: [.init(uiImage: uiImage)]))
                            }
                        }
                        .frame(width: geoSize(geoetry: geo).width, height: geoSize(geoetry: geo).width)
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
                .guard(borderColor) { value, view in
                    view.overlay(
                        Circle()
                            .stroke(value, lineWidth: 2)
                    )
                }

                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder func photoPicker<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        if #available(iOS 17.0, *) {
            content()
                .sheet(isPresented: Binding<Bool>(
                    get: { viewModel.shouldPresent },
                    set: { viewModel.setShouldPresent(to: $0) }
                )) {
                    PhotosPicker(
                        selection: $viewModel.imageSelection,
                        matching: .images
                    ) { VStack {} }
                        .edgesIgnoringSafeArea(.bottom)
                        .photosPickerStyle(.inline)
                        .presentationDetents([.medium, .large])
                        .photosPickerDisabledCapabilities(.selectionActions)
                }

        } else {
            content()
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
