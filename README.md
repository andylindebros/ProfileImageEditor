# ProfileImageEditor
ProfileImageEditor is a Swift package designed for creating custom profile images based on a specified view and its dimensions. Users can select a photo from their photo library and easily adjust its composition by dragging the image within the view to achieve the desired layout. Once the layout is finalized, the package will generate a new image with your desired dimensions, which can then be exported for use in your project.

![ProfileImageEditor](./demo.gif)
## Installation
1. In Xcode, with your app project open, navigate to `File > Add Packages`.
1. When prompted, add the Firebase Apple platforms SDK repository:
``` 
https://github.com/andylindebros/profile-image-editor
```
3. Select the SDK version that you want to use.

When finished, Xcode will automatically begin resolving and downloading your dependencies in the background.

## Implementation
Add the ProfileImageEditor to desired SwiftUI view.

``` Swift
import Combine
import ProfileImageEditor

class ContentViewModel: ObservableObject {
    init() {
        profileImageEditorViewModel = ProfileImageEditorViewModel()
        subscriber = profileImageEditorViewModel.imageExportAction.sink { [weak self] model in
            // Save or integrate the exported images with your project here.
        }
    }

    private var subscriber: Cancellable?
    let profileImageEditorViewModel: ProfileImageEditorViewModel
}

struct ContentView: View {
    @ObservedObject var viewModel = ContentViewModel()

    // The aspect ratio should be 1:1 so we specify width and height with this value
    let exportSize: CGFloat = 100

    var body: some View {
        ZStack {
            ProfileImageEditor(viewModel: viewModel.profileImageEditorViewModel)
                .padding()
            VStack {
                Spacer()
                Button(action: {
                    viewModel.profileImageEditorViewModel.dispatch(.exportImage(withSize: exportSize))
                }) {
                    Text("Export")
                }
            }
        }
    }
}
```

## Export Images
The Export delivery model generates two images: the original image and a resized version with the specified dimensions. Both images maintain a 1:1 aspect ratio.

## Example project
Explore the example project included in this package to learn more about how the ProfileImageEditor works.

Let me know what you think and drop me a line: andylindebros@gmail.com