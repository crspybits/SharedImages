# Framework

This is a dynamic version of the iOS [GoogleSignIn](https://developers.google.com/identity/sign-in/ios/sdk/) static framework. The `Framework` directory contains the result of building this framework and is built for iOS >= 9.3 for arm64 and armv7 based devices and for the intel-based simulator.

### 3/9/19

I just checked again and the current version of Google's framework (v4.4.0) still appears unsuited for use as a dependency within a .podspec file. I am getting an error message from Cocoapods: "target has transitive dependencies that include static binaries".

# Usage

This is in the form of a Cocoapod. See "Podspec Note" below for rationale. See the .podspec file for the current version.

In your Podfile, at the very top of the file, put:

```source 'https://github.com/crspybits/Specs.git'```

# Rationale

Since [SyncServer](https://github.com/crspybits/SyncServer-iOSClient) is a framework, I wanted a means to provide Google Sign In for iOS clients so that they didn't have to explicitly import GoogleSignIn. That is, I wanted to do this just like the way I'm doing this with Facebook and Dropbox: Just select the subspec in your Cocoapods Podfile and you are off to the races. However, Google Sign In doesn't make this easy-- at this time (early June 2018), Google provides static libraries. Well, you say, Cocoapods can now support [static vendored_libraries](https://guides.cocoapods.org/syntax/podspec.html#static_framework). Yea! Hmmm. I tried doing this. I get a gnarly error: "unsealed contents present in the bundle root" from Xcode. I wasn't able to make progress with that issue.

Instead, I took the route of converting the Google Sign In framework to a dynamic framework using [these instructions](https://pewpewthespells.com/blog/convert_static_to_dynamic.html)

This repo is the result of that process.

# Build process: Build from `GoogleSignIn.xcodeproj`

GoogleSignIn.xcodeproj is not part of the Cocoapod, but rather enables you to build the dynamic GoogleSignIn.framework

See https://stackoverflow.com/questions/5010062/xcodebuild-simulator-or-device and https://stackoverflow.com/questions/29634466/how-to-export-fat-cocoa-touch-framework-for-simulator-and-device

### To update the version of the Google SDK and update the project

1) Download the most recent version of the Google SDK from https://developers.google.com/identity/sign-in/ios/sdk/
2) In the downloaded folder, you should see three main file/folders: GoogleSignIn.bundle, GoogleSignIn.framework, GoogleSignInDependencies.framework
3) Rename the downloaded folder to "google_signin_sdk" (it should have been named something like "google_signin_sdk_4_4_0").
4) Replace that named folder in the repo with the new "google_signin_sdk".
5) I had to rename the file within the GoogleSignIn.framework/Headers/GoogleSignIn.h  obtained from Google to GoogleSignIn.framework/Headers/GoogleSignInAll.h to work around a naming conflict.
6) Note that the names of the header files in google_signin_sdk/GoogleSignIn.framework/Headers might have changed, and you might have to adjust these in GoogleSignIn.xcodeproj
7) Make sure the headers for the library are all public:
![Public Headers](./docs/publicHeaders.png)
8) Read through the section `Link dependent frameworks to your Xcode project` in https://developers.google.com/identity/sign-in/ios/sdk/ to see if you need to add other (more) libraries. (I ran into some odd looking link issues when I didn't remember this).

For some reason, the following does not generate a binary file output to run with the simulator. I'm having to dig into the DerivedData output of Xcode after building for an example simulator device to actually get the simulator-built framework.

```
xcodebuild -target GoogleSignIn -configuration Release -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO BUILD_DIR="build" BUILD_ROOT="build" clean build
```

The following builds for arm64 and armv7

I had to add -fembed-bitcode to OTHER_CFLAGS in the project build settings because I got "ld: bitcode bundle could not be generated" when I tried to build SharedImages. I also added this to the linker flags.

And I'm now making release builds because that seems to be the way to generate bitcode. See https://stackoverflow.com/questions/31233395/ios-library-to-bitcode

```
xcodebuild -target GoogleSignIn -configuration Release -sdk iphoneos ONLY_ACTIVE_ARCH=NO BUILD_DIR="build" BUILD_ROOT="build" clean build
```

Copy the framework structure (from iphoneos build) to the universal folder-- the lipo step only builds the executable, not the framework structure. Note that `trash` is just a command to move to the directory to the Trash folder.

```
trash Framework/GoogleSignIn.framework

cp -R "build/Release-iphoneos/GoogleSignIn.framework" "Framework/GoogleSignIn.framework"
```

Note we're replacing the non-fat binary in the step above with the fat binary.

```
lipo -create -output "Framework/GoogleSignIn.framework/GoogleSignIn" "build/Release-iphonesimulator/GoogleSignIn.framework/GoogleSignIn" "build/Release-iphoneos/GoogleSignIn.framework/GoogleSignIn"
```

Note that the name of the resulting framework must be `GoogleSignIn`-- i.e., it must match the name of the .bundle file-- or the graphics and text will not load into the Google Sign In button.

# Podspec Note

One of my struggles in developing this dynamic version of Google's framework was getting the GoogleSignIn.bundle to be properly accessed by the framework. The problem was that I was getting the GIDGoogleSignIn button appearing on the UI, but the graphics and text didn't appear-- and these come from the .bundle file. To deal with this, I have derived the form of the podspec I'm using here from Google's-- https://github.com/CocoaPods/Specs/blob/master/Specs/d/4/0/GoogleSignIn/4.1.2/GoogleSignIn.podspec.json (see also "See Podspec" link in https://cocoapods.org/pods/GoogleSignIn). See also https://stackoverflow.com/questions/50750862/using-google-sign-in-frameworks-in-a-cocoapod-subspec
