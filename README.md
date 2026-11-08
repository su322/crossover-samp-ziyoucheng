# 在 CrossOver 中运行 SA-MP「自由城」

> 仓库 `crossover-samp` · 建立 2026-10-27 · 最后更新 2026-11-05
>
> 本文既是**配置说明**，也是**排查日志**。正文（§1–§9）是当前有效结论；附录（`docs/`，A–K）是过程记录，**部分结论已被推翻**，阅读时注意每节开头标注的状态。

## 快速定位

| 我想……             | 看这里                                                                     |
| ---------------- | ----------------------------------------------------------------------- |
| 直接开始玩            | §5 日常启动步骤                                                               |
| 启动报 `800x600x32` | §3.1 + §9                                                               |
| 中文变方块            | §3.3（聊天区）/ §4（公告牌，**已解决**）                                              |
| 人数显示不对 / 连不上     | §5 提示 + **[附录 J](docs/issue-player-count.md)**                          |
| 游戏卡死或闪退          | §9 + [附录 F](docs/issue-hang.md)（卡死）/ [G](docs/issue-silent-exit.md)（闪退） |
| 改坏了要还原           | §8 回滚                                                                   |
| 核对文件是否被改动        | §7 文件清单（含 SHA-256）                                                      |

## 目录

- [1. 当前状态](#1-当前状态)
- [2. 环境与路径](#2-环境与路径)
- [3. 已生效的配置](#3-已生效的配置)
- [4. 公告牌中文方块：已由 0.3.DL-R1 解决](#4-公告牌中文方块已由-03dl-r1-解决)
- [5. 日常启动步骤](#5-日常启动步骤)
- [6. 排查工具](#6-排查工具)
- [7. 文件与配置清单](#7-文件与配置清单)
- [8. 回滚](#8-回滚)
- [9. 常见问题](#9-常见问题)
- **附录 A–L** → 已拆为 `docs/` 下的独立文件，见文末 [附录索引](#附录索引)

## 1. 当前状态

### 可用

- **SA-MP 0.3.DL-R1** 能正常启动，不再报 `800x600x32` 显示模式错误。
- 游戏以 **1280×832 无边框窗口**运行（等于本机逻辑桌面分辨率）。
- 服务器浏览器、收藏服务器、中文聊天、**登录菜单**、中文对话框、记分板和**服务器公告牌**的中文全部正常。
- 两个 CrossOver 启动入口、存档、服务器地址均保留。
- `samp.dll` / `samp.exe` 为 0.3.DL-R1 原版；`gta_sa.exe` 只打了 `0x0053388E` 路牌空指针的最小补丁（[附录 E](docs/patch-0x0053388E.md)），原版备份保存为 `gta_sa.exe.orig`。
- `scripts\` 只有窗口化插件。

### 未解决

- **传送后卡死**（2026-11-08 定位）：传送到自定义模型密集的地点时，渲染线程阻塞在模型加载/上传上，**进程存活、声音继续播**。已调整 `stream.ini` 模型池（13.2 MB → 195 MB）与 `fpslimit`（90 → 60），效果待验证。见[附录 L](docs/issue-hang-teleport.md)。
- **特效密集场景会周期性卡顿**（多人同时开火、爆炸、大量粒子等）。画质已压到最低仍卡，瓶颈在 Wine CPU 侧指令翻译；换 DXVK 直接崩溃（[附录 H](docs/attempt-dxvk.md)）。**结论：接受现状，不再尝试。**
  - ⚠️ 这是 0.3.7-R3 时期的结论；换成 0.3.DL-R1 后**尚未系统验证**卡顿是否改善。
- **偶发静默闪退**：进程直接消失，无对话框、无崩溃报告、无 `DiagnosticReports`。无已知修复方法，见[附录 G](docs/issue-silent-exit.md)。

### 崩溃补丁状态

- `0x007324B6`（`CVisibilityPlugins::RenderAtomicWithAlpha`）：排查期间出现过，当时用 SilentPatchSA + StreamMemFix + 5 字节补丁验证过不崩；按"恢复到实验前状态"的要求，**这些补丁已全部移除**，记录见[附录 D](docs/patch-0x007324B6.md)。
- `0x0053388E`（`CEntity::CreateEffects` 路牌 2D 效果）：2026-11-01 复现并定位为 `CreateRoadsignAtomic` 返回空指针后未判空。已给 `gta_sa.exe` 打最小补丁，原版备份为同目录的 `gta_sa.exe.orig`，细节见[附录 E](docs/patch-0x0053388E.md)。
- 当前 `gta_sa.exe` 为补丁版（SHA-256 `6f2b7950...`）；原版 SHA-256 为 `a559aa77...`。

## 2. 环境与路径

| 项目         | 值                                                                                                          |
| ---------- | ---------------------------------------------------------------------------------------------------------- |
| macOS      | 15.7                                                                                                       |
| 机器         | MacBook Air（Apple M4，16 GB）                                                                                |
| CrossOver  | 26.3                                                                                                       |
| 容器（bottle） | `samp`，Windows 10（build 19045）                                                                             |
| 游戏来源       | 自由城官网 `http://www.zycdjz1.com/`                                                                            |
| 游戏         | GTA: San Andreas 1.0                                                                                       |
| 联机端        | **SA-MP 0.3.DL-R1**（2026-11-05 从 0.3.7-R3 升级，见 §4）                                                         |
| 服务器        | `★Drift Star★自由城1`，`ds.zycdjz1.com:7777`                                                                   |
| 实际连接       | 域名解析到 **4 台轮询**：`154.12.58.26` / `.56` / `.112`、`45.158.21.28`，每次不一定相同，见[附录 J](docs/issue-player-count.md) |
| 显示         | 2560×1664 Retina；逻辑分辨率 1280×832                                                                            |
| 游戏窗口       | 无边框 1280×832；`fpslimit=60`（2026-11-08 由 90 下调），实际帧率随场景变化                                                       |

游戏目录（macOS）：

```
~/Library/Application Support/CrossOver/Bottles/samp/drive_c/Program Files (x86)/侠盗车手：圣安地列斯/
```

由于原路径含中文，容器内额外建了链接：

```
C:\GTA  ->  C:\Program Files (x86)\侠盗车手：圣安地列斯
```

两个 CrossOver 启动项（在 `~/Applications/CrossOver/`）都指向：

```
目标：C:\GTA\samp.exe
工作目录：C:\GTA
```

快捷方式本身没有带服务器参数；进入游戏后，在服务器浏览器里选择「★Drift Star★自由城1」再连接。

### 2.1 游戏与联机工具来源

游戏本体和 SA-MP 联机端都来自**自由城官网**：

- 官网首页：`http://www.zycdjz1.com/`
- 游戏本体：首页「电脑联机 → ① 下载游戏 → 1 游戏本体 600MB」（`zsadlsd.exe`）
- 联机端：同页「2 联机端」（`samp-install.exe`）

按官网说明先安装游戏本体，再把联机端安装到游戏根目录。服务器地址也以官网为准：`ds.zycdjz1.com:7777`。

## 3. 已生效的配置

### 3.1 启动报 `800x600x32`：自建 d3d9 代理

**现象**：`samp.exe` 启动后报找不到 `800x600x32` 显示模式，游戏退不回主菜单。

**原因**：Wine 自带的 `d3d9` 在枚举显示模式时没有提供游戏启动阶段要求的 `800x600×32` 模式。

**做法**：

1. 在游戏根目录放入一个 32 位 `d3d9.dll` 代理。它转发 `Direct3DCreate9` / `Direct3DCreate9Ex` 到真正的 `C:\windows\system32\d3d9.dll`，并在 `IDirect3D9` 的虚函数表里挂钩两个方法，让模式列表末尾多出一个 `800x600`、32 位（`X8R8G8B8`）的模式。
2. 在容器里设置 DLL 覆盖，让 Wine 优先加载本地代理：
   ```
   [Software\\Wine\\DllOverrides]
   "d3d9"="native,builtin"
   ```
   对应文件：`~/Library/Application Support/CrossOver/Bottles/samp/user.reg`。也可以在 CrossOver 的 winecfg →「函数库」里新增 `d3d9` 并设为「原生优先于内建」。
3. 验证方式：临时把 `d3d9.dll` 改名，再启动游戏，`800x600x32` 错误会重新出现；改回后恢复正常。

> 关键点：只放 `d3d9.dll` 而不加 `native,builtin` 覆盖时，Wine 仍会使用内建 d3d9，代理被绕过，错误依旧。

### 3.2 窗口化 / 无边框：III.VC.SA.WindowedMode.asi

整合包自带 ASI Loader（`vorbisFile.dll`），会加载 `scripts\*.asi`。窗口化插件放在：

```
scripts/III.VC.SA.WindowedMode.asi
scripts/III.VC.SA.WindowedMode.cfg
```

`III.VC.SA.WindowedMode.cfg` 当前关键设置：

```ini
[MAIN]
WindowMode = 2      ; 2 = Borderless（无边框）
ConfineCursor = 1
PauseOnFocusLoss = 1
ResumeOnFocus = 1

[WINDOW]
Width = 640
Height = 480
PositionX = 640
PositionY = 416
```

说明：

- `WindowMode=2` 是 **Borderless**：窗口覆盖整个显示器，按桌面逻辑分辨率 1280×832 显示。
- `Width` / `Height` / `PositionX` / `PositionY` 只在 **Windowed** 模式下参与窗口大小和位置。
- `Alt+Enter` / `Ctrl+Enter` 可在 Windowed 和 Borderless 之间切换；切换到 / 离开 Fullscreen 需要重启游戏。
- 想要真正的窗口模式：把 `WindowMode` 改成 `1`，`Width` / `Height` 设为 `0`（桌面分辨率）或明确写 `1280` / `832`。

### 3.3 中文聊天：修改 sa-mp.cfg 字体

**现象**：聊天区中文显示为方块或问号。

**原因**：SA-MP 聊天区默认使用 `Arial`，Wine 自带的 Arial 没有中文字形；而 `sampaux3.ttf` 不是聊天字体，它是击杀列表的图标字体（只有 21 个字形），不要用它替换成中文字体。

CrossOver 会自动把 macOS 的系统字体注册进容器，本机的 `Arial Unicode MS` 来自 `/System/Library/Fonts/Supplemental/Arial Unicode.ttf`，不需要往 `C:\windows\Fonts` 安装任何字体。

当前 `~/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg` 内容：

```ini
fpslimit=60
multicore=1
audioproxyoff=1
fontface="Arial Unicode MS"
fontweight=1
fontsize=1
```

`fontface` / `fontweight` / `fontsize` 三行负责聊天区中文。修改后重新进入服务器即可看到中文。SA-MP 退出时会重写该文件，但已验证这三行会保留。

> `fpslimit` 和 `audioproxyoff` 是 2026-11-08 为缓解卡死调整的，与字体无关，见 §3.5 和[附录 L](docs/issue-hang-teleport.md)。

> 这一节只解决**聊天区**。公告牌不走 SA-MP 的聊天字体，它的问题已在 §4 通过换版本解决。

### 3.4 中文路径与启动项

原游戏目录名含中文，因此：

- 建立 `C:\GTA` → 中文目录的链接；
- 两个启动项的 `.lnk` 目标改为 `C:\GTA\samp.exe`，工作目录设为 `C:\GTA`；
- CrossOver 里的两个入口都保留，名称未改。

### 3.5 流式加载内存池：`stream.ini`

游戏目录下的 `stream.ini` 控制**模型数据常驻池**的大小。传送卡死就是在这一层，2026-11-08 已从原版默认值调大：

```ini
memory		200000
devkit_memory	200000
```

**单位是 KB**（反汇编 `gta_sa.exe` 的解析代码在 `0x005BCD44`，`shll $0xa` 即 ×1024）：

| 值 | 实际 |
|---|---|
| 13500（原版） | 13.2 MB |
| 200000（当前） | 195.3 MB |

⚠️ **两个参数写入同一个全局变量（`0x8a5a80`），`devkit_memory` 会覆盖 `memory`**——只改一个等于白改，必须两个一起改。

上限受 32 位地址空间约束：`gta_sa.exe` / `samp.exe` 均为 `PE32` 且 `LARGE_ADDRESS_AWARE = NO`，只有 2 GB。195 MB 的池子加上纹理、音频、Wine 自身映射后约 700–850 MB，仍有余量。要再往上必须先开大地址。

> 注意：池子大只解决「去过又离开的地方回来时不用重读」。传送目的地若从未去过，模型仍需现读现解码。真正压住卡死的是**降低绘制距离**。完整分析见[附录 L](docs/issue-hang-teleport.md)。

## 4. 公告牌中文方块：已由 0.3.DL-R1 解决

**结论：换联机端版本就解决了，不需要改任何字体配置。**

2026-11-05 把联机端从 **0.3.7-R3** 换成 **0.3.DL-R1** 后，服务器左上角公告牌的中文从 `□□□□` 变成正常显示。此前为此折腾的三轮字体映射、汉化 DLL 全部作废。

### 4.1 两个版本的实际差异

| 项目 | 0.3.7-R3（旧） | 0.3.DL-R1（现用） |
|---|---|---|
| `samp.dll` 大小 / 日期 | 1,466,368 B / 2018-01-26 | 1,466,368 B / 2018-01-26 |
| `samp.dll` SHA-256 | `9c9b2cc31a4ced69…` | `bccdb297464bd382…` |
| `samp.exe` SHA-256 | `b5e760036bc2cd8c…` | `b21351fbcd10ffa0…` |
| 版本字符串 | `SA-MP 0.3.7-R3` | `SA-MP 0.3.DL-R1` |
| 公告牌实际使用的字体 | 只有 `Arial` | `Arial` + **`SimSun`**（详见 4.2） |
| 公告牌中文 | ❌ 方块 | ✅ 正常 |

两个版本的 `samp.dll` 大小一样但内容不同（哈希不同）。`0.3.DL` 的核心新特性是**服务器可下发自定义模型/皮肤**，但它同时改动了文字渲染路径。

### 4.2 真正的根因：公告牌的字体从 `Arial` 换成了 `SimSun`

用 `--debugmsg +font` 分别抓两个版本的日志，对比同一场景（站在公告牌前）。

**0.3.7-R3：只请求 `Arial`**

```
21464.265: L"Arial", h=38, weight=700, charset=1
         → substituting L"Arial",1 -> L"Arial Unicode MS",1
         → Chosen: L"Arial Bold" (Arial Bold.ttf)      ← 纯拉丁，无汉字
```

**0.3.DL-R1：同时请求 `Arial` 和 `SimSun`**

```
331177.601: L"Arial", h=38, weight=700, charset=1
          → substituting L"Arial",1 -> L"Arial Unicode MS",1
          → Chosen: L"Arial Bold" (Arial Bold.ttf)      ← 仍是纯拉丁

331556.067: L"SimSun", h=38, weight=700, charset=0      ← 新增！宋体
          → Chosen: L"冬青黑体简体中文 W3" (Hiragino Sans GB.ttc)  ← 有汉字
```

两个请求在 `331556.067` 这一秒内**成对交替出现**（Arial/SimSun 各 4 次），说明 0.3.DL 的公告牌渲染会同时创建两套字体，**实际绘制用的是 `SimSun` 那套**。

同一次抓取的统计：

| 指标 | 0.3.7-R3 | 0.3.DL-R1 |
|---|---|---|
| `Arial` 请求次数 | 有 | 有（1828 次） |
| **`SimSun` 请求次数** | **0** | **1480 次** |
| `SimSun` h=38 w=700 | 无 | 14 次 → 冬青黑体 |
| `Chosen: 冬青黑体简体中文 W3` | **0** | 5 |
| 公告牌结果 | ❌ 方块 | ✅ 正常 |

**`SimSun` 是服务器下发的。** `samp.dll` 里搜不到 `SimSun` 字符串（ASCII 和 UTF-16LE 都没有），说明它不是硬编码，而是通过 `SetObjectMaterialText` 的 `fontFace` 参数从服务端传下来的。0.3.7-R3 的实现忽略了这个参数（退化成 `Arial`），0.3.DL-R1 才真正使用它。

> **这也解释了为什么之前所有字体映射都白费**：改 `Arial` 的映射只能影响那套"备用"字体，真正画公告牌的是 `SimSun`，它在 CrossOver 里本来就映射到 `冬青黑体简体中文 W3`（有汉字），根本没坏。
>
> 旧分析里"`weight=700` 缺粗体"那段是对的，但**只对 `Arial` 那套成立**，而 `Arial` 不是公告牌的实际字体。

### 4.3 历史排查（已作废，留档）

以下尝试全部**无效或不可接受**，详细过程见[附录 K](docs/attempt-font-mapping.md)：

| 尝试 | 结果 |
|---|---|
| `directFont` ASI 插件 | ❌ 无效，已删除 |
| 代码页 936 + 自定义字体 | ❌ 无效（容器本就是 `ACP=936`） |
| `HKCU\Software\Wine\Fonts\Replacements` 映射 | ❌ 改错表（该表只在"按名字找不到"时查） |
| `SimHei` 等中文字体映射 | ❌ 无效 |
| 拉丁字体 → `Arial Unicode MS` | ❌ 无效 |
| 改 `samp.dll` 字体名 | ❌ 无效，已恢复 |
| 汉化 DLL（`gtasa_cn.3dm`）via ASI Loader | ❌ 卡死（与 `d3dmetal` + 窗口化插件冲突） |
| `FontSubstitutes` 全局替换 `Arial` → CJK 字体 | ⚠️ 字体层面成功，但游戏卡死闪退，已回滚 |

**唯一有效的做法：换 0.3.DL-R1。**

## 5. 日常启动步骤

1. 打开 CrossOver，或从启动台打开任一启动项（目标 `C:\GTA\samp.exe`）。
2. 在 SA-MP 服务器浏览器中找到「★Drift Star★自由城1」。
3. 选中服务器，点「连接」。
4. 进服后聊天、登录菜单、对话框、记分板、公告牌中文均正常。

服务器地址：`ds.zycdjz1.com:7777`

> 这个域名有 **4 条 A 记录轮询**，每次解析可能落到不同节点，表现为"人数对不上"或"连不上"。想固定就改用 IP 收藏 `154.12.58.112:7777`，详见[附录 J](docs/issue-player-count.md)。

收藏记录保存在 `SAMP/USERDATA.DAT`，未改动。

## 6. 排查工具

仓库根目录的 `带日志启动.command` 支持三种模式，真正的开关是 `--debugmsg`（**不是** `WINEDEBUG`，原因见下）：

| 用法 | `--debugmsg` 通道 | 日志名 | 行为 |
|---|---|---|---|
| 双击 | `+timestamp,+unwind,+module` | `samp-debug-<时间>.log` | **静默崩溃捕获**：没崩几乎没日志，崩了才倒出上下文 |
| `./带日志启动.command seh` | `+timestamp,+seh,+unwind,+module` | `…-seh.log` | 全量详细日志（刷得很快，深度排查用） |
| `./带日志启动.command font` | `+timestamp,+font`（**经过滤器**） | `…-font.log` | 抓字体请求（排查中文方块） |

### 6.1 核心注意点

**不能用 `WINEDEBUG`。** CrossOver 的 `bin/wine` 是个 Perl 启动器，没传 `--cx-log` 时会强制把 `WINEDEBUG` 覆盖成 `-all`（全关）。唯一有效的开关是命令行参数 `--debugmsg`。

**font 模式必须过滤。** `+font` 原始输出大到不可用：光启动 `samp.exe` 就 **145 MB / 194 万行**。过滤器只保留三类有用的字体记录（`font_SelectFont` 请求、`substituting` 替换命中、`select_font Chosen` 最终结果），并加入黑名单和重复上限，把日志压到 **~200 KB** 量级。

**双击模式是"静默"的。** `+unwind,+module` 正常玩一分钟就是 5 MB / 5 万行（99.7% 是噪音）。双击模式用环形缓冲：正常行不写盘，只保留最近 300 行在内存里；一旦出现崩溃特征（`Unhandled exception` / `Unhandled page fault` / `page fault on ` / `Assertion failed` / `Backtrace:`），才把缓冲倒出来。即使**没有**崩溃特征（静默退出），结束时也会把最后 300 行业务日志倒出来。

> 游戏运行期间**不要关终端窗口**。窗口一关，`wine` 进程组收到挂断信号，游戏会被一起杀掉。顺序永远是「先退游戏 → 再关窗口」。

### 6.2 双击版

不想敲命令就双击 `抓字体日志.command`，等价于 `./带日志启动.command font`，另外多做两件事：

- 启动前先 `pgrep` 检查游戏是否还在运行，在跑就拒绝启动并提示先退出
- 结束后停住窗口等回车，方便看日志路径

## 7. 文件与配置清单

### 生效 / 新增的文件

| 路径 | 作用 | 校验值 / 当前值 |
|---|---|---|
| 游戏根目录 `d3d9.dll` | 800×600×32 模式代理，271,360 字节 | SHA-256 `fde5c00e2246f939ae542b5535cd39642dfaeda020a169bf11494b560fb134c2` |
| 游戏根目录 `gta_sa.exe` | [附录 E](docs/patch-0x0053388E.md) 的 `0x0053388E` 空指针补丁 | SHA-256 `6f2b7950c178dff0a1bb9aa513694b92b7bae35dc36586dca089bf618888b71b` |
| 游戏根目录 `gta_sa.exe.orig` | 打补丁前的原版备份，回滚用 | SHA-256 `a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26` |
| `scripts/III.VC.SA.WindowedMode.asi` | 窗口化插件，3,232,600 字节 | SHA-256 `8b2485e89761044f56bbd4e2fa882ec9667939edf542fde682e016bd7e9373a9` |
| `scripts/III.VC.SA.WindowedMode.cfg` | 窗口化设置 | `WindowMode=2`（Borderless） |
| `~/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg` | 聊天字体 / 帧率 / 音频代理 | 见 3.3 |
| 游戏根目录 `stream.ini` | 模型数据常驻池，`memory` / `devkit_memory` = `200000`（KB ≈ 195 MB） | 见 3.5；原版备份 `stream.ini.bak-20261108-185753` |
| `~/Library/.../Bottles/samp/user.reg` | `d3d9=native,builtin` 覆盖 | 见 3.1 |
| `C:\GTA` | 指向中文游戏目录的链接 | — |

### 联机端文件（0.3.DL-R1 原版）

| 文件 | 大小 | SHA-256 |
|---|---|---|
| `samp.dll` | 1,466,368 B | `bccdb297464bd382625635be25585df07a8fa6668bc0015650708e3eb4ffcd4b` |
| `samp.exe` | 413,696 B | `b21351fbcd10ffa0f47a453bc2d193cc820919dba7240cdda7a32c21bb21fb14` |

> 0.3.7-R3 时期的哈希（`samp.dll` `9c9b2cc3…` / `samp.exe` `b5e76003…`）已作废，不要再用来核对。

### 其他原文件

| 文件 | SHA-256 |
|---|---|
| `sampaux3.ttf` | `3adfe84498e8951e61ece57ad08de21b95d162697517291564ae6ef3a8790c1b` |
| `gtaweap3.ttf` | `086dc4351bf1056d80a73168440ffe4261831bde992e5134902b9bae017dcbe9` |
| `vorbisFile.dll`（整合包自带 ASI Loader） | `c33e1bafafd441b42eaa6d322393b9dd700f8a9c13fb2e7780daf49707a46353` |
| `models/fonts.txd`（GTA 原版位图字体，524,584 B） | `5ca77cddb15f96de29b3786cb5620492dbc310d29af2d1374e644d74f1a61cbf` |

`scripts\` 现在只有：

```
III.VC.SA.WindowedMode.asi
III.VC.SA.WindowedMode.cfg
```

### 已移除的排查文件

- `scripts/directFont.asi`、`scripts/directFont.ini`
- `scripts/SilentPatchSA.asi`、`scripts/SilentPatchSA.ini`、`scripts/StreamMemFix.asi`
- `scripts/gtasa_cn.asi`（汉化 DLL 试验副本）
- `C:\windows\Fonts\ArialBoldCJK.ttf` 及其注册项
- 游戏目录里的 `samp.dll.bak-*`、`gta_sa.exe.bak-*`
- `sa-mp.cfg.bak-*`、`system.reg.bak-*`、`user.reg.bak-*`

## 8. 回滚

先退出游戏和 CrossOver，再按需操作：

1. **撤销 800×600 修复**：删除游戏根目录的 `d3d9.dll`，并在 winecfg 的「函数库」中删除 `d3d9` 覆盖（或把 `user.reg` 里的 `"d3d9"="native,builtin"` 删除）。
2. **撤销窗口化**：删除 `scripts/III.VC.SA.WindowedMode.asi` 和 `.cfg`。
3. **撤销聊天字体**：删除 `sa-mp.cfg` 中的 `fontface` / `fontweight` / `fontsize` 三行，或改回 `fontface="Arial"`。
4. **撤销快捷方式**：把两个启动项的目标改回中文游戏目录下的 `samp.exe`（或直接删除 `C:\GTA` 链接后重新指定）。
5. **撤销 `0x0053388E` 补丁**：用同目录的 `gta_sa.exe.orig` 覆盖 `gta_sa.exe`。

```
cd "~/Library/Application Support/CrossOver/Bottles/samp/drive_c/Program Files (x86)/侠盗车手：圣安地列斯"
cp -p gta_sa.exe.orig gta_sa.exe
shasum -a 256 gta_sa.exe
```

6. **回退联机端版本**（仅在 0.3.DL-R1 出问题时）：重装 0.3.7-R3 的 `samp.dll` / `samp.exe`，但**公告牌方块会回来**。
7. **撤销卡死调优**（2026-11-08 的三项）：把 `stream.ini` 的 `memory` / `devkit_memory` 改回 `13500`，或直接用原版备份覆盖：

   ```
   cd "~/Library/Application Support/CrossOver/Bottles/samp/drive_c/Program Files (x86)/侠盗车手：圣安地列斯"
   cp -p stream.ini.bak-20261108-185753 stream.ini
   ```

   同时把 `sa-mp.cfg` 的 `fpslimit` 改回 `90`、`audioproxyoff` 改回 `0`（或直接恢复 `sa-mp.cfg.bak-20261108-185520`）。

> 直接编辑 `system.reg` 只在**没有 wine 进程**时有效；有进程在跑时 wineserver 会用内存整份回写覆盖。要热改请走 `reg add` / `reg import`。

游戏本体、存档、服务器收藏均不受上述操作影响。

## 9. 常见问题

**启动又报 `800x600x32`**

- 检查游戏根目录 `d3d9.dll` 是否存在、哈希是否正确。
- 检查 `d3d9` 覆盖是否还在；CrossOver 更新或修复容器后可能被重置。
- 确认启动的是 `samp` 这个容器。

**中文变成方块或问号**

- **聊天区**：检查 `sa-mp.cfg` 的三行字体设置是否被客户端重写；确认 `system.reg` 中 `Arial Unicode MS` 仍指向 macOS 的 `Arial Unicode.ttf`。
- **公告牌**：确认联机端是 **0.3.DL-R1**（`samp.dll` SHA-256 `bccdb297…`）。如果被换回 0.3.7-R3，方块会重现。不要再装 `directFont` 或改字体映射，那些都验证无效。

**聊天字体被重置**

- 退出游戏后检查 `~/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg`，确认这三行仍在：
  `fontface="Arial Unicode MS"`、`fontweight=1`、`fontsize=1`。

**画面全屏、无法切窗口**

- 当前配置是 `WindowMode=2`（Borderless）。按 `Alt+Enter` / `Ctrl+Enter` 可在 Windowed 和 Borderless 之间切换；切换到 / 离开 Fullscreen 需要重启游戏。
- 如果 cfg 被改坏，删除它后重启游戏会重新生成默认设置。

**启动项打不开**

- 确认 `C:\GTA` 链接仍存在，且指向中文游戏目录。
- 启动项目标应为 `C:\GTA\samp.exe`，工作目录 `C:\GTA`。

**出现 `0x007324B6` 崩溃**

- `0x007324B6` 的补丁**当前没有安装**；但 `gta_sa.exe` **不是原版**——它带着[附录 E](docs/patch-0x0053388E.md) 的 `0x0053388E` 补丁。两者是不同地址、互不影响。
- 崩溃特征：`CVisibilityPlugins::RenderAtomicWithAlpha`，`EAX=0xC1000000`，`ESI=7`。
- 如果再次出现，先保留崩溃日志，再按[附录 D](docs/patch-0x007324B6.md) 的 5 字节补丁处理。

**游戏卡住不动 / 进程还在但画面冻住**

- 这是 hang，不是崩溃：日志停止增长，进程存活。按 `Ctrl+C` 结束，或 `killall -9 gta_sa.exe samp.exe wineserver`。
- **如果声音还在播**，说明是渲染线程被模型加载阻塞，典型触发是**传送**。见[附录 L](docs/issue-hang-teleport.md)，已把 `stream.ini` 模型池调到 195 MB、`fpslimit` 降到 60。
- 其他情况见[附录 F](docs/issue-hang.md)。

**一传送就卡死**

- 先确认是不是**自定义地图密集**的地点（这台服务器有 559 个自定义模型）。
- 能立刻见效的是**降低绘制距离**（`Options → Display Setup → Draw Distance`），它直接减少一次要加载的模型数量。
- 把 SA-MP 收藏从域名 `ds.zycdjz1.com:7777` 改成固定 IP **`154.12.58.112:7777`**：0.3.DL 的模型缓存按 IP 分目录，域名轮询到不同节点会**重新下载 167 MB**。
- 完整分析见[附录 L](docs/issue-hang-teleport.md)。

## 附录索引

详细的过程记录已拆到 `docs/`，每个文件独立可读，文首都有返回正文的链接。

| 附录 | 主题 | 状态 | 文件 |
|---|---|---|---|
| A–C | d3d9 代理：原理 / 源码 / 编译 | ✅ 生效中 | [`d3d9-proxy.md`](docs/d3d9-proxy.md) |
| D | `0x007324B6` 崩溃与 5 字节补丁 | ⏸ 补丁**未安装** | [`patch-0x007324B6.md`](docs/patch-0x007324B6.md) |
| E | `0x0053388E` 路牌空指针补丁 | ✅ **已安装** | [`patch-0x0053388E.md`](docs/patch-0x0053388E.md) |
| F | 进服后卡死（早期记录） | ⚠️ 未复现，已被 L 补充 | [`issue-hang.md`](docs/issue-hang.md) |
| G | 静默闪退 | ⚠️ 未复现 | [`issue-silent-exit.md`](docs/issue-silent-exit.md) |
| H | 试过 DXVK，不适用 | ❌ 已回滚 | [`attempt-dxvk.md`](docs/attempt-dxvk.md) |
| I | msync 试验 | ❌ 结论作废 | [`attempt-msync.md`](docs/attempt-msync.md) |
| J | 人数显示不对 / 骤减 | ✅ 已结案（服务器更新） | [`issue-player-count.md`](docs/issue-player-count.md) |
| K | 字体映射试验（三批）+ 换 0.3.DL 的结论 | ❌ 已作废 | [`attempt-font-mapping.md`](docs/attempt-font-mapping.md) |
| L | 传送后卡死 + `stream.ini` 单位与上限 | ⚠️ 调整待验证 | [`issue-hang-teleport.md`](docs/issue-hang-teleport.md) |

> ⚠️ 附录里**部分结论已被推翻**：[附录 I](docs/attempt-msync.md) 整篇作废，[附录 J](docs/issue-player-count.md) 的 J.1–J.5 含被推翻的推理，[附录 K](docs/attempt-font-mapping.md) 是完整踩坑记录。正文（§1–§9）才是当前有效结论。
