# BOTTT

A transparent desktop pixel pet for macOS. Flat head, two square eyes, short hands, and four short legs. The window background stays clear, so empty pixels fall through to the desktop. Drag the body to move it.

![BOTTT](docs/pet.png)

## Click

Click the body. BOTTT copies an English prompt to the clipboard, blinks, and says `Copied. Paste it into your AI.` It does not read the long prompt aloud. While any line is spoken, including that Copied line, two to four words sit above the head and clear when the audio ends.

The command inside the copied prompt is filled in at click time. It is the absolute path of the `bottt` executable on the machine where the pet is running (the file this build writes to `.build/bottt`). Clone the repo somewhere else, build it, and the next click copies that machine’s path. Nothing in the prompt is a fixed home folder.

Paste that prompt into another Cursor chat. That chat should summarize the conversation and run the command from the prompt so BOTTT reads the summary once.

Right-click the pet, or use the menu **宠物 → 设置…**, to change body color and size. Size is about 48–240 pt, default 80.

## Voices

The settings list has four voices. Click confirmation and `bottt say` both use the one that is selected.

- Supertonic 3 (default): ONNX on CPU, 5 denoising steps, models in `models/supertonic`
- Kokoro-82M: `models/kokoro`
- Piper: Sherpa-ONNX, models in `models/piper`
- Apple system voice: `AVSpeechSynthesizer`

Until you pick one yourself, the voice is Supertonic.

## Open in Xcode

From your home directory, without writing a `/Users/...` path:

```bash
open ~/projects/bottt/BOTTT.xcodeproj
```

If the checkout lives somewhere else, open `BOTTT.xcodeproj` from that folder. Scheme **BOTTT**, then Run.

## Build and run

From the repository root:

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Debug/BOTTT.app
```

The `bottt say` command is the executable at `.build/bottt` (repository-relative). After the app is running:

```bash
.build/bottt say "your English summary here"
```

If the app is not running, the command exits non-zero and stderr is `BOTTT is not running`.

Voice models are not in git. `tts/fetch_models.sh` downloads them into `models/` next to this repo.
