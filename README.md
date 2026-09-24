# BOTTT

BOTTT is a transparent pixel pet that sits on the Mac desktop. The wallpaper stays visible around its flat head, short arms, and four legs. Drag the body to move it; right-click to change color and size.

![BOTTT](docs/pet.png)

Click the body and it copies a mode-specific English prompt to the clipboard, then says a short confirmation such as “Copied. Paste it into your AI.” It does not read the full prompt aloud. In Settings you can leave the voice on, or keep only the captions above its head.

There are two click modes. Summary mode asks another chat to turn the conversation into a short spoken paragraph and then have BOTTT read it. Diary mode asks that chat to write a short English desktop diary entry with a title and a date, and after the entry is done the pet looks happy for a moment. The copied prompt prefers the BOTTT MCP tools when the client has them, and falls back to the local shell command otherwise. The path written into that fallback is filled in when you click, pointing at `BOTTT.app/Contents/Resources/bottt` for the copy you actually launched, so it is never a hard-coded home directory.

Through the day it picks up small moods of its own: around noon and in the evening its expression shifts, in the morning it looks ready for something to do, and once in a while it puts on a busy face. Settings also lets you pick a look—square eyes, glasses, smile, mustache, sharp eyes, wizard, party, chef, heart, flag, or a dizzy spiral.

What actually speaks is the running app’s local mouth: a Unix socket that both the bundled `bottt say` CLI and the MCP server talk to. There is no network API. Cursor, Codex, WorkBuddy, Qoder, or any other tool that can run a shell command on your Mac can still drive it with `bottt say` and `bottt smile`. Clients that support MCP can instead connect the stdio server under `mcp/` and call the tools `speak`, `smile`, and `get_status`. MCP only remotes the mouth; it does not launch the pet. If BOTTT.app is not open, both paths return a clear “not running” error.

To wire the MCP server into Cursor (or a similar product), install Node 18+, then from a clone of this repo run `cd mcp && npm install`. Point the client’s MCP config at the built entry with your own absolute path to the clone, for example `"command": "node"` and `"args": ["/absolute/path/to/bottt/mcp/dist/index.js"]`. Restart the client so it picks up the server. After that, agents can call `speak` with a short English `text`, `smile` with no arguments, or `get_status` to see whether the app is running and which speech/prompt modes were last saved. The old CLI remains available and equivalent: `bottt say "…"` matches `speak`, and `bottt smile` matches `smile`.

Download [BOTTT-mac.zip](https://github.com/jqlong17/bottt/releases/download/v1.0.0/BOTTT-mac.zip) from the [v1.0.0 release](https://github.com/jqlong17/bottt/releases/tag/v1.0.0), unzip it, and open `BOTTT.app`. You do not need Xcode. If macOS blocks the first launch, allow it in System Settings → Privacy & Security. Keep the app open whenever you want MCP or `bottt say` to make sound or advance captions.

To build from source, clone [jqlong17/bottt](https://github.com/jqlong17/bottt), open `BOTTT.xcodeproj`, choose the BOTTT scheme, and run. From the repository root:

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```

For the MCP server only:

```bash
cd mcp && npm install && npm start
```
