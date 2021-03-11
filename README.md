# SwiftUICam

SwiftUICam is an AVFoundation based API that allows users to access the camera and its functions in a custom format on their iOS devices in SwiftUI with ease. 

# Feautures

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
* Click here to see Awalz/SwiftyCam: https://github.com/Awalz/SwiftyCam 
* Click here to see KavSoft: https://kavsoft.dev/SwiftUI_2.0/Custom_Camera/

# Installation

This package is downloaded through Swift's Package Manager. 
* Using XCode 11+ go to: File -> Swift Packages -> Add Package Dependency: https://github.com/vGebs/SwiftUICam

# Usage

## Using the Module
In the file in which you are using the SwiftUICamModel:

``` Swift
import SwiftUICam
```
## Object Instantiation
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

## Setting the view
* To set the view, first create a structure that inhertits UIViewRepresentable. 
* This protocol states that you must implement two functions - MakeUIView & UpdateUIView.
* MakeUIView - Sets the view (basically ViewDidLoad)
* UpdateUIView - Updates after user input (viewDidChange)
* To make these functions work with this framework, we will need to declare the @EnvironmentObject stated above in the app.swift file.
* We also want to declare the a UIView variable that will be used to specify the frame in which this view will sit.
* Upon declaring these protocol functions and variables we can use the SwiftUICamModel to call the public preview setup functions as shown below.

``` Swift
import SwiftUICam

struct SwiftUICamPreview: UIViewRepresentable{
    @EnvironmentObject var camera: SwiftUICamModel
    var view: UIView
    
    func makeUIView(context: Context) ->  UIView {
        return camera.makeUIView(view)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        camera.updateUIView()
    }
}
```

## Using the SwiftUICamPreview
* To use the view preview we created above, we simply define it inside of a view.
* Again, declare the SwiftUICamModel @EnvironmentObject and instantiate the view frame using a UIView.
* Pass this defined view into the preview to call the function and define the view.

* Once the view in initialized we can use it just like any other view in SwiftUI.
* As seen below we can now place tap gestures to use other function within the framework.

* A tap gesture with count 2 can be used to toggle which camera you wish to use (front or rear)

``` Swift
struct CameraView: View{
    @EnvironmentObject var camera: SwiftUICamModel
    let view = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight * 0.91))

    var body: some View{
        ZStack{
            ...
            SwiftUICamPreview(view: view)
                .ignoresSafeArea(.all, edges: .all)
                .onTapGesture(count: 2){
                    camera.toggleCamera()
                }
            ...
        }
    }
}
```

## Taking a picture
* Now that we've defined our UIViewRepresentable view and used it within our SwiftUI application, we can now make other views that use the SwiftUICamModel. 

* We can define a cameraButtonView that when pressed takes a picture.
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

