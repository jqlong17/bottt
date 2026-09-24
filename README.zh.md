# BOTTT

BOTTT 是一只待在 macOS 桌面上的像素宠物。窗口是透明的，桌面从它旁边露出来，你看见的是扁扁的头、两条短手和四条腿。按住身体可以拖到别处，右键可以改颜色和大小。

![BOTTT](docs/pet.png)

点在身体上，它会把一段英文提示词放进剪贴板，眨一下眼，再说一句 “Copied. Paste it into your AI.”，并不会把整段提示词念出来。只要在出声，头顶就出现两三个词，这几个词过去之后换成下一组，整句说完字幕也消失。

把复制出去的提示词贴回另一个 Cursor 对话之后，那边会先把当前聊天收成一小段英文口语，再按提示词里写的命令，在你这台 Mac 上让这只宠物把总结读出来。命令里的路径是点击那一下填进去的，指向你正在用的 `BOTTT.app/Contents/Resources/bottt`。别人把压缩包解到自己的目录里再点，得到的就是他们机器上的路径。

从 [v1.0.0](https://github.com/jqlong17/bottt/releases/tag/v1.0.0) 下载 [BOTTT-mac.zip](https://github.com/jqlong17/bottt/releases/download/v1.0.0/BOTTT-mac.zip)，解压后打开 `BOTTT.app` 即可，不用安装 Xcode。第一次如果被系统拦住，到「系统设置 → 隐私与安全性」里允许。

包里带的语音是 Supertonic，不改设置的话它就用这个。设置里另外还有 Kokoro、Piper 和苹果语音，不过这个 zip 没有 Kokoro 和 Piper 的模型，那两项会显示不可用，Supertonic 不受影响。

要从源码编译，把 [jqlong17/bottt](https://github.com/jqlong17/bottt) 克隆下来，打开 `BOTTT.xcodeproj`，Scheme 选 BOTTT 再 Run。也可以在仓库根目录执行：

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```
