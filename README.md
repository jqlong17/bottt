# BOTTT

BOTTT is a transparent pixel pet that sits on the Mac desktop. The wallpaper stays visible around its flat head, short arms, and four legs. Drag the body to move it; right-click to change color and size.

![BOTTT](docs/pet.png)

Click the body and it copies a mode-specific English prompt to the clipboard, then says a short confirmation such as “Copied. Paste it into your AI.” It does not read the full prompt aloud. In Settings you can leave the voice on, or keep only the captions above its head.

There are two click modes. Summary mode asks another chat to turn the conversation into a short spoken paragraph and then have BOTTT read it. Diary mode asks that chat to write a short English desktop diary entry with a title and a date, and after the entry is done the pet looks happy for a moment.

Through the day it picks up small moods of its own: around noon and in the evening its expression shifts, in the morning it looks ready for something to do, and once in a while it puts on a busy face. Settings also lets you pick a look—square eyes, glasses, smile, mustache, sharp eyes, wizard, party, chef, heart, flag, or a dizzy spiral.

What actually speaks is a local `bottt say` command inside the app, not a network API. Cursor, Codex, WorkBuddy, Qoder, or any other tool that can run a shell command on your Mac can drive it. If BOTTT.app is not open, nothing comes out. The path written into the copied prompt is filled in when you click, pointing at `BOTTT.app/Contents/Resources/bottt` for the copy you actually launched, so it is never a hard-coded home directory.

Download [BOTTT-mac.zip](https://github.com/jqlong17/bottt/releases/download/v1.0.0/BOTTT-mac.zip) from the [v1.0.0 release](https://github.com/jqlong17/bottt/releases/tag/v1.0.0), unzip it, and open `BOTTT.app`. You do not need Xcode. If macOS blocks the first launch, allow it in System Settings → Privacy & Security.

To build from source, clone [jqlong17/bottt](https://github.com/jqlong17/bottt), open `BOTTT.xcodeproj`, choose the BOTTT scheme, and run. From the repository root:

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```
