# SwiftUICam

SwiftUICam is an AVFoundation based API that allows users to access the camera and its functions on their iOS devices in SwiftUI with ease. 
It allows users to:

1. Take pictures
2. Save pictures to camera roll
3. Toggle Between Camers
4. Toggle Flash

Features coming soon:

1. Swipe to zoom
2. Video recording
3. Low light boost
4. Filters

# Disclaimer

Sections of this API were derived from Awalz/SwiftyCam and KavSoft's tutorial. 
Click here to see Awalz/SwiftyCam: https://github.com/Awalz/SwiftyCam 
Click here to see KavSoft: https://kavsoft.dev/SwiftUI_2.0/Custom_Camera/

# Installation

This package is downloaded through Swift's Package Manager. 
Using XCode 11+ go to: File -> Swift Packages -> Add Package Dependency: https://github.com/vGebs/SwiftUICam

# Usage

In the file in which you are defining the camera:

``` Swift
import SwiftUICam
```

Because we wish to only instantiate one instance of the camera:

``` Swift
import SwiftUICam

@main
struct SwiftUICamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SwiftUICamModel(volumeCameraButton: true))
        }
    }
}
```

Initializing the View and toggling camera:

``` Swift
struct CameraView: View{
    @EnvironmentObject var camera: SwiftUICamModel
    let view = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight * 0.91))

    var body: some View{
        ZStack{
            ...
            CameraPreview(view: view)
                .ignoresSafeArea(.all, edges: .all)
                .onTapGesture(count: 2){
                    camera.toggleCamera()
                }
            ...
        }
    }
}
```

Taking a picture:
``` Swift
struct CameraView: View{
    @EnvironmentObject var camera: SwiftUICamModel

    var body: some View{
        ZStack{
            ...
            CameraButtonView()
                .onTapGesture {
                    camera.takePic()
                }
            ...
        }
    }
}
```

For more implementation details, an example project is coming soon.

# Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

# License

This package is under the MIT license

