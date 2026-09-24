# BOTTT

透明桌面上的像素宠物，给 macOS 用。扁头、两只方眼、短手、四条短腿。窗口背景是透明的，点在空白处会穿过。拖身体可以搬走。

![BOTTT](docs/pet.png)

## 下载

不需要安装 Xcode。

1. 从 [GitHub Releases](https://github.com/jqlong17/bottt/releases) 下载最新的 Release zip。
2. 解压，打开 `BOTTT.app`。

这个 App 用的是 ad-hoc 签名。首次打开若被拦截，到「系统设置 → 隐私与安全性」里允许 BOTTT。

Supertonic 3 已经打进 App，第一次打开不用再下载就能说。Kokoro 和 Piper 是可选的。没有附带它们的模型时，设置里会标明不可用，不会挡住 Supertonic。

## 点一下

点在身体上，会把一段英文提示词复制到剪贴板，眨一下眼，并用当前语音说 `Copied. Paste it into your AI.` 不读那段长提示词。只要在发音，包括这句 Copied，头顶就显示 2–4 个词，说完就清掉。

提示词里的命令路径是点击时按本机生成的。它是你打开的这个 App 里面的 `bottt`（这台 Mac 上的 `BOTTT.app/Contents/MacOS/bottt`）。把 App 解压或挪到别的目录后再点，路径会跟着 App 走，不是写死的家目录。

把这段提示词贴进另一个 Cursor 对话。那个对话会先总结，再按提示词里的命令让 BOTTT 把总结读出来。

右键宠物，或菜单「宠物 → 设置…」，可以改身体颜色和大小。大小大约 48–240 pt，默认 80。

## 语音

设置里可以切换四种语音。点击后的短确认和 `bottt say` 都走当前选中的那个。

- Supertonic 3（默认）：ONNX，CPU，5 步去噪，随 App 附带
- Kokoro-82M：可选；没附带模型时，设置里标明不可用
- Piper：可选，同样处理
- 苹果系统语音：`AVSpeechSynthesizer`

还没在设置里手动选过时，用的是 Supertonic。

## 从源码编译

只有自己编译时才需要这一节。从 Release 打开 App 不用做这些，也不用打开 xcodeproj。

在检出目录里打开 `BOTTT.xcodeproj`。Scheme 选 **BOTTT**，然后 Run。

在仓库根目录：

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```

打进这个 App 的 `bottt` 命令在 `BOTTT.app/Contents/MacOS/bottt`。App 开着的时候：

```bash
.build/Build/Products/Release/BOTTT.app/Contents/MacOS/bottt say "your English summary here"
```

没开时退出码不是 0，stderr 是 `BOTTT is not running`。

语音权重不进 git。Release 的 zip 里已经有 Supertonic。从源码跑时，`tts/fetch_models.sh` 会把模型下到仓库旁的 `models/`。Kokoro 和 Piper 仍然可选。
