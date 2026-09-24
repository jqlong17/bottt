# BOTTT

BOTTT is a pixel pet that lives on the Mac desktop. The window is transparent, so the wallpaper stays visible and you only see the flat head, the short arms, and the four legs. Drag the body when you want it somewhere else, and right-click when you want a different color or size.

![BOTTT](docs/pet.png)

Click the body and it copies an English prompt onto the clipboard, blinks, and says “Copied. Paste it into your AI.” It does not read the long prompt aloud. Whenever it is speaking, including that short line, two or three words show above its head and drop away as it moves on, until the line is finished and the caption is gone.

That prompt is meant to be pasted into another Cursor chat. The other chat summarizes the conversation into a short spoken paragraph, then runs the `bottt` command written in the prompt so this pet reads the summary once. The path in the command is filled in at the moment you click, and it is `BOTTT.app/Contents/Resources/bottt` inside the app you actually opened, so a copy unzipped somewhere else gets that machine’s own path.

Download [BOTTT-mac.zip](https://github.com/jqlong17/bottt/releases/download/v1.0.0/BOTTT-mac.zip) from the [v1.0.0 release](https://github.com/jqlong17/bottt/releases/tag/v1.0.0), unzip it, and open `BOTTT.app`. You do not need Xcode. If macOS blocks the first launch, allow it in System Settings → Privacy & Security.

The voice in the zip is Supertonic, which is what the pet uses unless you change it. Settings also lists Kokoro, Piper, and the Apple system voice, but this zip has no models for Kokoro or Piper, so those two are marked unavailable and Supertonic still speaks.

To build it yourself, clone [jqlong17/bottt](https://github.com/jqlong17/bottt), open `BOTTT.xcodeproj`, choose the BOTTT scheme, and run. From the repository root:

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```
