# 象棋智囊 · 开源复刻（XiangqiWisdom）

对 App Store 应用「象棋智囊」（`com.su.chessaihelper`）的公开复刻工程。

原版的完整链路已逆向清楚：

```
ReplayKit 录屏 → CoreML 棋盘/棋子检测 → FEN → Pikafish（本地 + 云引擎）→ 画中画/小棋盘显示
```

本仓库只复刻架构与交互，**不包含原作者的二进制、模型权重、开局库或私有云服务**。

## 当前进度

**v0.1.0 — UI 骨架（本版可编译出 IPA）**

- [x] 启动页：标题、副标题、会员状态、启动按钮
- [x] 设置页五项：对局推演 / 配置引擎 / 浮窗样式 / 语音提示 / 更多设置
- [x] `EngineBridge` 抽象：远程 UCI 网关 或 demo 模式
- [x] 语音播报（AVSpeechSynthesizer）
- [ ] ReplayKit 广播扩展（`ScreenShare.appex`）
- [ ] CoreML 棋盘 + 棋子检测（YOLO 640×640，17 类）
- [ ] 画中画着法显示（`AVPictureInPictureController` + 占位视频）
- [ ] 内置 Pikafish 静态库（C++ / NNUE）
- [ ] OBK 开局库导入

## 与原版的差异

| 层 | 原版 | 本仓库 |
|---|---|---|
| 识别 | 4 个 CoreML 模型（作者自训） | 预留接口，可用开源 `xiangqi-recognition` ONNX 替代 |
| 本地引擎 | 静态链接 Pikafish + 21.7MB NNUE | 计划集成官方 Pikafish（GPLv3） |
| 云引擎 | `engine.chessbots.cn` + 阿里云 FC | 不实现，改由自建网关承担 |
| 会员 | StoreKit 1 九档内购 | 无付费，开源版恒为已开通 |
| 显示 | PiP + PiP 着法视图 | 第一版为主界面内展示 |

## 构建

无需 Mac，GitHub Actions 直接产出 unsigned IPA（artifact 名 `XiangqiWisdom-unsigned`）。

本地构建：

```bash
brew install xcodegen
xcodegen generate
open XiangqiWisdom.xcodeproj
```

签名自理：LcSign / ESign / Sideloadly / TrollStore 均可对 unsigned 包重签。

## 目录

```
Sources/            应用源码（UIKit）
.github/workflows/  macOS runner 编译 + 打包
project.yml         XcodeGen 工程描述
```

## 许可证

GPL-3.0。原版内置的 Pikafish 引擎本身是 GPLv3 软件，静态链接后整个应用应遵循同一协议；本仓库从一开始就按这个前提公开。
