# BOTTT

A transparent desktop pixel pet for macOS. Flat head, two square eyes, short hands, and four short legs. The window background stays clear, so empty pixels fall through to the desktop. Drag the body to move it.

![BOTTT](docs/pet.png)

## Download

You do not need Xcode.

1. Download the latest Release zip from [GitHub Releases](https://github.com/jqlong17/bottt/releases).
2. Unzip it and open `BOTTT.app`.

The app is signed ad-hoc. If macOS blocks the first open, go to **System Settings → Privacy & Security** and allow BOTTT.

Supertonic 3 ships inside the app, so the first launch can speak without another download. Kokoro and Piper are optional. If their models are not in the app, Settings marks them unavailable and Supertonic stays the voice.

## Click

Click the body. BOTTT copies an English prompt to the clipboard, blinks, and says `Copied. Paste it into your AI.` It does not read the long prompt aloud. While any line is spoken, including that Copied line, two to four words sit above the head and clear when the audio ends.

The command inside the copied prompt is filled in at click time. It is the absolute path of `bottt` inside the app you opened (`BOTTT.app/Contents/Resources/bottt` on that Mac). Move or unzip the app somewhere else, click again, and the path follows the app. Nothing in the prompt is a fixed home folder.

Paste that prompt into another Cursor chat. That chat should summarize the conversation and run the command from the prompt so BOTTT reads the summary once.

Right-click the pet, or use the menu **宠物 → 设置…**, to change body color and size. Size is about 48–240 pt, default 80.

## Voices

The settings list has four voices. Click confirmation and `bottt say` both use the one that is selected.

- Supertonic 3 (default): ONNX on CPU, 5 denoising steps, included with the app
- Kokoro-82M: optional; Settings says it is unavailable when the model is not included
- Piper: optional; same
- Apple system voice: `AVSpeechSynthesizer`

Until you pick one yourself, the voice is Supertonic.

## Build from source

This section is only for building the app yourself. Opening the app from a Release does not need it.

Open `BOTTT.xcodeproj` from the checkout. Scheme **BOTTT**, then Run.

From the repository root:

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```

The `bottt` command copied into that app is `BOTTT.app/Contents/Resources/bottt`. After the app is running:

```bash
.build/Build/Products/Release/BOTTT.app/Contents/Resources/bottt say "your English summary here"
```

If the app is not running, the command exits non-zero and stderr is `BOTTT is not running`.

Voice weights are not in git. A Release zip already contains Supertonic. From a checkout, `tts/fetch_models.sh` downloads models into `models/` next to the repo. Kokoro and Piper stay optional.
