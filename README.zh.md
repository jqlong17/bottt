# BOTTT

BOTTT 是一只待在 macOS 桌面上的透明像素宠物。壁纸从扁扁的头、两条短手和四条腿旁边露出来。按住身体可以拖到别处，右键可以改颜色和大小。

![BOTTT](docs/pet.png)

点在身体上，它会按当前模式把一段英文提示词放进剪贴板，再说一句确认，例如 “Copied. Paste it into your AI.”，并不会把整段提示词念出来。设置里可以选择出声，也可以只留头顶的字幕。

点击有两种模式。总结模式让另一个对话把当前聊天收成一小段口语，再让 BOTTT 读出来。日记模式则让那边写成一篇桌面上的英文日记，带着标题和日期；日记写完之后，它会开心一下。复制出来的提示词会优先建议走 BOTTT 的 MCP 工具；客户端没有 MCP 时，再退回本机 shell 命令。提示词里的路径是点击那一下填进去的，指向你正在用的 `BOTTT.app/Contents/Resources/bottt`，不会写死某个用户的家目录。

白天它还会自己换一点心情：中午和傍晚表情会变，早上看起来想活动，偶尔摆出忙碌的样子。设置里也可以换形象——方眼、眼镜、微笑、胡子、尖眼、巫师、派对、厨师、爱心、旗，或者头晕螺旋。

真正出声靠的是正在跑的 App 本机通道：Unix socket。捆绑的 `bottt say` 和仓库里的 MCP server 都往这条通道写，不是网上的 API。Cursor、Codex、WorkBuddy、Qoder，以及任何能在你这台 Mac 上执行命令的工具，仍可以用 `bottt say` / `bottt smile` 驱动它；支持 MCP 的客户端则可以接上 `mcp/` 下的 stdio server，调用工具 `speak`、`smile`、`get_status`。MCP 只是远程控制嘴，不会替你打开宠物。App 没开时，两条路都会明确报错。

在 Cursor（及同类产品）里配置时，先装好 Node 18+，在仓库里执行 `cd mcp && npm install`，再把 MCP 配置的 `command` 设为 `node`，`args` 写成你本机克隆路径下的 `mcp/dist/index.js` 绝对路径，例如 `["/absolute/path/to/bottt/mcp/dist/index.js"]`，然后重启客户端。之后 agent 可以调用 `speak`（参数 `text` 为英文短句）、无参的 `smile`，或 `get_status` 查看 App 是否在跑以及上次保存的出声/提示词模式。旧的 CLI 仍然并存且等价：`bottt say "…"` 对应 `speak`，`bottt smile` 对应 `smile`。

从 [v1.0.0](https://github.com/jqlong17/bottt/releases/tag/v1.0.0) 下载 [BOTTT-mac.zip](https://github.com/jqlong17/bottt/releases/download/v1.0.0/BOTTT-mac.zip)，解压后打开 `BOTTT.app` 即可，不用安装 Xcode。第一次如果被系统拦住，到「系统设置 → 隐私与安全性」里允许。要用 MCP 或 `bottt say` 出声（或推进字幕），请先让 App 保持打开。

要从源码编译，把 [jqlong17/bottt](https://github.com/jqlong17/bottt) 克隆下来，打开 `BOTTT.xcodeproj`，Scheme 选 BOTTT 再 Run。也可以在仓库根目录执行：

```bash
xcodebuild -project BOTTT.xcodeproj -scheme BOTTT -configuration Release -destination 'platform=macOS' -derivedDataPath .build build
open .build/Build/Products/Release/BOTTT.app
```

只装 MCP server：

```bash
cd mcp && npm install && npm start
```
