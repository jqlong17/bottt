# BOTTT

A pixel pet on the desktop. The window is clear, so you just see the pet.

![BOTTT](docs/pet.png)

Click it and it copies a prompt, then says a line. While it talks, two or three words pop up over its head and disappear when it stops. Drag the body to move it. Right-click to change the color or the size.

The prompt tells another chat to summarize, then run `bottt` on your Mac. That path is filled in when you click. It is `BOTTT.app/Contents/Resources/bottt` wherever you put the app.

## Install

No Xcode.

Grab [BOTTT-mac.zip](https://github.com/jqlong17/bottt/releases/download/v1.0.0/BOTTT-mac.zip) from the [v1.0.0 release](https://github.com/jqlong17/bottt/releases/tag/v1.0.0). Unzip it and open `BOTTT.app`.

If the Mac blocks the first open, go to System Settings → Privacy & Security and allow it.

The default voice is the Supertonic that comes in the zip. Settings also lists Kokoro, Piper, and the Apple voice, and this zip has no models for Kokoro or Piper.

## Build from source

Open `BOTTT.xcodeproj`, pick the BOTTT scheme, and run it. Or from the repo:

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```
