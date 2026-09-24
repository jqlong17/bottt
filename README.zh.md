# BOTTT

透明桌面上的像素宠物，给 macOS 用。扁头、两只方眼、短手、四条短腿。窗口背景是透明的，点在空白处会穿过。拖身体可以搬走。

![BOTTT](docs/pet.png)

## 点一下

点在身体上，会把一段英文提示词复制到剪贴板，眨一下眼，并用当前语音说 `Copied. Paste it into your AI.` 不读那段长提示词。只要在发音，包括这句 Copied，头顶就显示 2–4 个词，说完就清掉。

提示词里的命令路径是点击时按本机生成的。它是正在运行的这只宠物所在机器上，`bottt` 可执行文件的绝对路径（这次编译写到 `.build/bottt` 的那个文件）。别人把仓库克隆到自己的目录、编译之后再点，复制出来的就是他们自己的路径，不是写死的家目录。

把这段提示词贴进另一个 Cursor 对话。那个对话会先总结，再按提示词里的命令让 BOTTT 把总结读出来。

右键宠物，或菜单「宠物 → 设置…」，可以改身体颜色和大小。大小大约 48–240 pt，默认 80。

## 语音

设置里可以切换四种语音。点击后的短确认和 `bottt say` 都走当前选中的那个。

- Supertonic 3（默认）：ONNX，CPU，5 步去噪，模型在 `models/supertonic`
- Kokoro-82M：`models/kokoro`
- Piper：Sherpa-ONNX，模型在 `models/piper`
- 苹果系统语音：`AVSpeechSynthesizer`

还没在设置里手动选过时，用的是 Supertonic。

## 用 Xcode 打开

用家目录缩写 `~/`，不要写成 `/Users/...`：

```bash
open ~/projects/bottt/BOTTT.xcodeproj
```

仓库如果放在别的目录，就在那个目录里打开 `BOTTT.xcodeproj`。Scheme 选 **BOTTT**，然后 Run。

## 编译和运行

在仓库根目录：

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Debug/BOTTT.app
```

`bottt say` 的可执行文件在仓库里的相对位置是 `.build/bottt`。App 开着的时候：

```bash
.build/bottt say "your English summary here"
```

没开时退出码不是 0，stderr 是 `BOTTT is not running`。

语音模型不进 git。`tts/fetch_models.sh` 会把它们下到仓库旁的 `models/`。
