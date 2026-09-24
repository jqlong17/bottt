# BOTTT

桌面上放着一只像素宠物。窗口是透明的，旁边的桌面还在。

![BOTTT](docs/pet.png)

点一下，提示词就进剪贴板，然后它说一句。说话时头顶冒两三个词，说完就收掉。拖身体可以挪地方。想换颜色、改大小，右键。

那段提示词是给另一个对话用的：先把当前聊天收成一句英文，再在你这台 Mac 上跑 `bottt`。路径是点的时候填进去的，就是你解开的那个 `BOTTT.app/Contents/Resources/bottt`。

## 怎么装

不用 Xcode。

从 [v1.0.0](https://github.com/jqlong17/bottt/releases/tag/v1.0.0) 下 [BOTTT-mac.zip](https://github.com/jqlong17/bottt/releases/download/v1.0.0/BOTTT-mac.zip)，解压，打开 `BOTTT.app`。

第一次要是被拦住了，去「系统设置 → 隐私与安全性」里允许。

默认是包里的 Supertonic。设置里还能看到 Kokoro、Piper 和苹果语音，后两个这个 zip 没带模型。

## 自己编译

打开 `BOTTT.xcodeproj`，Scheme 选 BOTTT，Run。或者在仓库里：

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```
