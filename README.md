# 在 CrossOver 中运行 SA-MP「自由城」

> 仓库 `crossover-samp` · 记录日期 2026-10-27 · 最后更新 2026-11-02
>
> 本文既是**配置说明**，也是**排查日志**。正文（§1–§8）是当前有效结论；附录（`docs/`，A–K）是过程记录，**部分结论已被推翻**，阅读时注意每节开头标注的状态。

## 快速定位

| 我想……             | 看这里                                                                     |
| ---------------- | ----------------------------------------------------------------------- |
| 直接开始玩            | §5 日常启动步骤                                                               |
| 启动报 `800x600x32` | §3.1 + §8                                                               |
| 中文变方块            | §3.3（聊天区）/ §4（公告牌，未解决）                                                  |
| 人数显示不对 / 连不上     | §5 提示 + **[附录 J](docs/issue-player-count.md)**                          |
| 游戏卡死或闪退          | §8 + [附录 F](docs/issue-hang.md)（卡死）/ [G](docs/issue-silent-exit.md)（闪退） |
| 改坏了要还原           | §7 回滚                                                                   |
| 核对文件是否被改动        | §6 文件清单（含 SHA-256）                                                      |

## 目录

- [1. 当前状态](#1-当前状态)
- [2. 环境与路径](#2-环境与路径)
- [3. 已生效的配置](#3-已生效的配置)
- [4. 未解决：服务器公告牌中文方块](#4-未解决服务器公告牌中文方块)
- [5. 日常启动步骤](#5-日常启动步骤)
- [6. 文件与配置清单](#6-文件与配置清单)
- [7. 回滚](#7-回滚)
- [8. 常见问题](#8-常见问题)
- **附录 A–K** → 已拆为 `docs/` 下的独立文件，见文末 [附录索引](#附录索引)

## 1. 当前状态

### 可用

- SA-MP 0.3.7-R3 能正常启动，不再报 `800x600x32` 显示模式错误。
- 游戏以 **1280×832 无边框窗口**运行（等于本机逻辑桌面分辨率）。
- 服务器浏览器、收藏服务器、中文聊天、**登录菜单**、中文对话框和记分板均正常。
- 两个 CrossOver 启动入口、存档、服务器地址均保留。
- `samp.dll` 为原版文件；`gta_sa.exe` 只打了 `0x0053388E` 路牌空指针的最小补丁（[附录 E](docs/patch-0x0053388E.md)），原版备份保存为 `gta_sa.exe.orig`。
- `scripts\` 只有窗口化插件。

### 未解决

- **服务器左上角公告牌中文方块**——已定位根因是公告牌走 `Arial` **粗体**（`weight=700`），而 macOS 上的 `Arial Unicode MS` 没有粗体，Wine 回退到 `Arial Bold.ttf`（纯拉丁）→ 方块。 chat 区是 `weight=400`，所以正常。尝试过字体映射和汉化 DLL 两种修复路线，均因稳定性问题回滚。**当前接受现状**，详见 [§4](#4-未解决服务器公告牌中文方块)。
- **特效密集场景会周期性卡顿**（多人同时开火、爆炸、大量粒子等）。画质已压到最低仍卡，瓶颈在 Wine CPU 侧指令翻译；换 DXVK 直接崩溃（[附录 H](docs/attempt-dxvk.md)）。**结论：接受现状，不再尝试。**

### 崩溃补丁状态

- `0x007324B6`（`CVisibilityPlugins::RenderAtomicWithAlpha`）：排查期间出现过，当时用 SilentPatchSA + StreamMemFix + 5 字节补丁验证过不崩；按"恢复到实验前状态"的要求，**这些补丁已全部移除**，记录见[附录 D](docs/patch-0x007324B6.md)。
- `0x0053388E`（`CEntity::CreateEffects` 路牌 2D 效果）：2026-11-01 复现并定位为 `CreateRoadsignAtomic` 返回空指针后未判空。已给 `gta_sa.exe` 打最小补丁，原版备份为同目录的 `gta_sa.exe.orig`，细节见[附录 E](docs/patch-0x0053388E.md)。
- 当前 `gta_sa.exe` 为补丁版（SHA-256 `6f2b7950...`）；原版 SHA-256 为 `a559aa77...`。
- 补丁只保证本机不因这个空指针闪退，不会修复服务器上创建失败的那个路牌本身。
- 如果 `0x007324B6` 再次出现，处理步骤记录在[附录 D](docs/patch-0x007324B6.md)。
- **新现象（2026-11-01 21:47）**：打完补丁后进服成功、未再崩溃，但在服务器下发音频流消息后画面卡死（进程不退出、无崩溃报告）。已确认这是 **hang 而不是崩溃**，且补丁本身不会造成阻塞，详见[附录 F](docs/issue-hang.md)；处理步骤在 F.4。

## 2. 环境与路径

| 项目         | 值                                                                                                          |
| ---------- | ---------------------------------------------------------------------------------------------------------- |
| macOS      | 15.7                                                                                                       |
| 机器         | MacBook Air（Apple M4，16 GB）                                                                                |
| CrossOver  | 26.3                                                                                                       |
| 容器（bottle） | `samp`，Windows 10（build 19045）                                                                             |
| 游戏来源       | 自由城官网 `http://www.zycdjz1.com/`                                                                            |
| 游戏         | GTA: San Andreas 1.0 + SA-MP 0.3.7-R3 整合包                                                                  |
| 服务器        | `★Drift Star★自由城1`，`ds.zycdjz1.com:7777`                                                                   |
| 实际连接       | 域名解析到 **4 台轮询**：`154.12.58.26` / `.56` / `.112`、`45.158.21.28`，每次不一定相同，见[附录 J](docs/issue-player-count.md) |
| 显示         | 2560×1664 Retina；逻辑分辨率 1280×832                                                                            |
| 游戏窗口       | 无边框 1280×832；`fpslimit=90`，实际帧率随场景变化                                                                       |

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

本机为 **MacBook Air（Apple M4，16 GB）**，上述 Windows 程序全部运行在 CrossOver 的 `samp` 容器中。

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
   对应文件：
   ```
   ~/Library/Application Support/CrossOver/Bottles/samp/user.reg
   ```
   也可以在 CrossOver 的 Wine 配置（winecfg）→「函数库」里，新增 `d3d9` 并设为「原生优先于内建」（native, builtin）。
3. 验证方式：临时把 `d3d9.dll` 改名，再启动游戏，`800x600x32` 错误会重新出现；改回后恢复正常，说明代理和覆盖都在起作用。

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
- `Width` / `Height` / `PositionX` / `PositionY` 只在 **Windowed** 模式下参与窗口大小和位置；当前保存的 640×480 和居中点不会改变 Borderless 的实际显示。
- `Alt+Enter` / `Ctrl+Enter` 可在 Windowed 和 Borderless 之间切换；切换到 / 离开 Fullscreen 需要重启游戏。
- 如果想要真正的窗口模式：把 `WindowMode` 改成 `1`，`Width` / `Height` 设为 `0`（桌面分辨率）或明确写 `1280` / `832`。
- 如果不需要窗口化，删掉这两个文件即可恢复游戏自己的全屏模式。

### 3.3 中文聊天：修改 sa-mp.cfg 字体

**现象**：聊天区中文显示为方块或问号。

**原因**：SA-MP 聊天区默认使用 `Arial`，Wine 自带的 Arial 没有中文字形；而 `sampaux3.ttf` 不是聊天字体，它是击杀列表的图标字体（只有 21 个字形），不要用它替换成中文字体。

CrossOver 会自动把 macOS 的系统字体注册进容器。本机已有的 `Arial Unicode MS` 来自：

```
/System/Library/Fonts/Supplemental/Arial Unicode.ttf
```

容器注册表 `system.reg` 中可看到它被映射为 `Arial Unicode MS (TrueType)`，因此不需要往 `C:\windows\Fonts` 安装任何字体。

当前 `~/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg` 内容：

```ini
fpslimit=90
multicore=1
audioproxyoff=0
fontface="Arial Unicode MS"
fontweight=1
fontsize=1
```

`fontface` / `fontweight` / `fontsize` 三行负责聊天区中文。修改后重新进入服务器即可看到中文。SA-MP 退出时会重写该文件，但已验证这三行会保留。

> 这一节只解决**聊天区**。服务器公告牌不走 SA-MP 的聊天字体，改 `sa-mp.cfg` 对它不生效，那块牌子仍然显示方块，见第 4 节。（登录菜单、对话框、记分板都正常，不需要处理。）

### 3.4 中文路径与启动项

原游戏目录名含中文，因此：

- 建立 `C:\GTA` → 中文目录的链接；
- 两个启动项的 `.lnk` 目标改为 `C:\GTA\samp.exe`，工作目录设为 `C:\GTA`；
- CrossOver 里的两个入口都保留，名称未改。

## 4. 未解决：服务器公告牌中文方块

**现象**：聊天区、登录菜单、对话框、记分板的中文**都正常**；**只有服务器左上角那块公告牌（规则 / 公告）里的中文是一排方块**（`□□□□`）。

**关键推论**：既然登录菜单等其它文字都正常，就说明"中文渲染全局失效"并不成立。所以下面这条旧判断**站不住脚**：

> ~~公告牌是 SA-MP 的 TextDraw，走 GTA 的 `CFont` / `models/fonts.txd` 位图字体，所以没有汉字。~~

如果所有 TextDraw 都走位图字体，登录菜单也该是方块——但它是正常的。而且**公告牌的文字是贴在牌子上的（世界空间），不随屏幕移动**，这就直接排除了 TextDraw。因此它只能是 `3DTextLabel`（客户端渲染）或**对象材质文字**（`SetObjectMaterialText`，服务端指定字体）——后者的修复难度完全不同。

**影响范围**：目前**只发现公告牌这一处**。

### 4.1 已尝试且无效的方案

| 尝试 | 结果 | 备注 |
|---|---|---|
| `directFont` ASI 插件 | ❌ 无效 | 已删除 |
| 代码页 936 + 自定义字体 | ❌ 无效 | 字体和注册项已删除。实测容器本就是 `ACP=936` |
| `HKCU\Software\Wine\Fonts\Replacements` 映射 | ❌ 无效 | **改错表了**：这张表只在"按名字找不到字体"时才查，而 `Arial` 能"找到" |
| `SimHei` 等中文字体映射 | ❌ 无效 | 已写入且生效（ wineserver 内存确认），但服务器请求的不是这些字体 |
| 拉丁字体 → `Arial Unicode MS` | ❌ 无效 | 同上，已确认写入生效 |
| 改 `samp.dll` 字体名 | ❌ 无效 | 已恢复原版 |
| 汉化 DLL（`gtasa_cn.3dm`） via ASI Loader | ❌ 卡死 | 与 `d3dmetal` + 窗口化插件冲突，已删除 |
| **`FontSubstitutes` 全局替换 `Arial` → CJK 字体** | ⚠️ 字体层面成功，但游戏卡死闪退 | 已回滚，详见下文 |

### 4.2 根因与结论

聊天区走 SA-MP 自己的 D3DX 字体（`sa-mp.cfg`），所以聊天正常；登录菜单、对话框、记分板正常，说明 SA-MP 侧的 TextDraw 字体路径本身没问题。

**公告牌的文字贴在牌子上（世界空间），不随屏幕移动 → 排除 TextDraw。** 而且服务器里**其他人看得到中文**，说明服务端发的是真文字、不是贴图。所以这是纯粹的**客户端拿不到汉字字形**问题。

用 `--debugmsg +font` 抓到的关键证据：

```
L"Arial", h=120, it=0, weight=700, PandF=00, charset=1     ← 公告牌
→ substituting L"Arial",1 -> L"Arial Unicode MS",1
→ select_font Chosen: L"Arial Bold"  (…/Arial Bold.ttf)     ← 纯拉丁，无汉字
```

**根因**：`Arial Unicode MS` 在 macOS 上**只有常规体（weight 400）**，没有粗体。请求 `weight=700` 时，Wine 找不到对应字重，就**退回原家族 `Arial` 的粗体面** `Arial Bold.ttf`（纯拉丁）→ 方块。聊天区是 `weight=400`，走常规体有汉字，所以正常。**只有粗体这条路径是坏的。**

这也解释了为什么所有"全局替换 `Arial`"的尝试都走进了死胡同：把 `Arial` 指向 CJK 字体（如 `宋体-简`）确实能让 `weight=700` 拿到有汉字的粗体面（日志里验证成功），但 `Arial` 是游戏 UI 里最常用的字体，每一处文字都去加载大体积中文 TTC，**游戏直接卡死并闪退**。这不是参数问题，是方案本身不可接受。

**完整排查记录（三批字体映射试验、两张替换表的区别、踩过的所有坑）** 见 [附录 K](docs/attempt-font-mapping.md)。

### 4.3 文件层面的证据

查了游戏目录，确认：

- `models/fonts.txd` 是原版（524,584 B，2005-01-21），**没有被汉化替换**，不含汉字字形。
- 整合包的中文靠 `gtasa_cn.exe` 把 `gtasa_cn.3dm`（带汉字字库 + 渲染钩子）**注入进 `gta_sa.exe`**，而不是替换字体文件。
- 但启动链路是 `samp.exe → gta_sa.exe`**，绕过了汉化启动器**，所以汉化 DLL 没有被加载。

> 不要替换 `models/fonts.txd`——它会影响全局，而且 GTA 的位图字体是单字节索引，不换 exe 光换 txd 也处理不了双字节汉字。

### 4.4 汉化 DLL 的可试方案（已回滚）

`gtasa_cn.3dm` 是个 D3D9 字体钩子（文件头是 `MZ` = PE32 DLL），用 GDI 的 `CreateFontIndirectA` + `CreateCompatibleBitmap` 离屏绘制，字体指定为 `SimHei`。理论上把它复制成 `scripts/gtasa_cn.asi` 就能通过 ASI Loader 加载。

**结果：游戏卡死。** `samp.exe` 退出，`gta_sa.exe` 僵住。三个冲突源：

1. `d3dmetal` 后端 + 自建 `d3d9.dll` 代理（见 §3.1）——钩子面对的不是原生 D3D9
2. 窗口化插件 `III.VC.SA.WindowedMode.asi` **也钩 D3D9**，两个钩子叠加
3. 2006 年的 32 位 PE，当年的 D3D9 行为和现在差异很大

**已回滚**，`scripts/` 只剩窗口化插件。

> ⚠️ 之前写过"不要把 `gtasa_cn.3dm` 改名成 `.asi`"，那是基于"它不是 ASI 插件"的猜测。现在已确认它是标准 PE32 DLL，**这个警告撤回**——可以试，但要复制而非改名，并准备好随时删除。

## 5. 日常启动步骤

1. 打开 CrossOver，或从启动台打开：
   - 「圣安地列斯 联机工具 SA-MP 0.3.7-R3语音插件版」
   - 或「圣安地列斯游戏本体+SAMP-R3带语音插件汉化版」
2. 在 SA-MP 服务器浏览器中找到「★Drift Star★自由城1」。
3. 选中服务器，点「连接」。
4. 进入服务器后聊天、登录菜单、对话框、记分板都正常；**只有左上角那块服务器公告牌**的中文是方块，这是当前已知状态。

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

**font 模式必须过滤。** `+font` 原始输出大到不可用：光启动 `samp.exe`（还没进游戏）就 **145 MB / 194 万行**。过滤器只保留三类有用的字体记录（`font_SelectFont` 请求、`substituting` 替换命中、`select_font Chosen` 最终结果），并加入黑名单和重复上限，把日志压到 **~200 KB** 量级。脚本退出时会自动打印出现过的字体请求统计。

**双击模式是"静默"的。** `+unwind,+module` 正常玩一分钟就是 5 MB / 5 万行（99.7% 是噪音）。双击模式用环形缓冲：正常行不写盘，只保留最近 300 行在内存里；一旦出现崩溃特征（`Unhandled exception` / `Unhandled page fault` / `page fault on ` / `Assertion failed` / `Backtrace:`），才把缓冲倒出来。即使**没有**崩溃特征（静默退出），结束时也会把最后 300 行业务日志倒出来，方便定位死前在做什么。

> 游戏运行期间**不要关终端窗口**。窗口一关，`wine` 进程组收到挂断信号，游戏会被一起杀掉。顺序永远是「先退游戏 → 再关窗口」。

### 6.2 双击版

不想敲命令就双击 `抓字体日志.command`，等价于 `./带日志启动.command font`，另外多做两件事：

- 启动前先 `pgrep` 检查游戏是否还在运行，在跑就拒绝启动并提示先退出
- 结束后停住窗口等回车，方便看日志路径

## 7. 文件与配置清单

### 生效 / 新增的文件

| 路径                                                      | 作用                                                    | 校验值 / 当前值                                                                           |
| ------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 游戏根目录 `d3d9.dll`                                        | 800×600×32 模式代理，271,360 字节                            | SHA-256 `fde5c00e2246f939ae542b5535cd39642dfaeda020a169bf11494b560fb134c2`          |
| 游戏根目录 `gta_sa.exe`                                      | [附录 E](docs/patch-0x0053388E.md) 的 `0x0053388E` 空指针补丁 | SHA-256 `6f2b7950c178dff0a1bb9aa513694b92b7bae35dc36586dca089bf618888b71b`          |
| 游戏根目录 `gta_sa.exe.orig`                                 | 打补丁前的原版备份，回滚用                                         | SHA-256 `a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26`          |
| `scripts/III.VC.SA.WindowedMode.asi`                    | 窗口化插件，3,232,600 字节                                    | SHA-256 `8b2485e89761044f56bbd4e2fa882ec9667939edf542fde682e016bd7e9373a9`          |
| `scripts/III.VC.SA.WindowedMode.cfg`                    | 窗口化设置                                                 | `WindowMode=2`（Borderless）、`Width=640`、`Height=480`、`PositionX=640`、`PositionY=416` |
| `~/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg` | 聊天字体 / 帧率设置                                           | 见 3.3                                                                               |
| `~/Library/.../Bottles/samp/user.reg`                   | `d3d9=native,builtin` 覆盖                              | 见 3.1                                                                               |
| `C:\GTA`                                                | 指向中文游戏目录的链接                                           | —                                                                                   |
| 两个 CrossOver `.app` / `.lnk`                            | 启动入口，目标 `C:\GTA\samp.exe`                             | 工作目录 `C:\GTA`，无额外参数                                                                 |


### 未改动的原文件

| 文件                                 | SHA-256                                                            |
| ---------------------------------- | ------------------------------------------------------------------ |
| `samp.dll`                         | `9c9b2cc31a4ced6967420b1880c096b5c4e7630e227aa379be4019c21b6fddc1` |
| `samp.exe`                         | `b5e760036bc2cd8c3b6ce6c3fd0d2a3f5ea896a33ffcbc3914d6895d1e46dfa5` |
| `sampaux3.ttf`                     | `3adfe84498e8951e61ece57ad08de21b95d162697517291564ae6ef3a8790c1b` |
| `gtaweap3.ttf`                     | `086dc4351bf1056d80a73168440ffe4261831bde992e5134902b9bae017dcbe9` |
| `vorbisFile.dll`（整合包自带 ASI Loader） | `c33e1bafafd441b42eaa6d322393b9dd700f8a9c13fb2e7780daf49707a46353` |
| `models/fonts.txd`（GTA 原版位图字体，524,584 B，**无汉字字形**）     | `5ca77cddb15f96de29b3786cb5620492dbc310d29af2d1374e644d74f1a61cbf` |


`scripts\` 现在只有：

```
III.VC.SA.WindowedMode.asi
III.VC.SA.WindowedMode.cfg
```

### 已移除的排查文件

- `scripts/directFont.asi`、`scripts/directFont.ini`
- `scripts/SilentPatchSA.asi`、`scripts/SilentPatchSA.ini`、`scripts/StreamMemFix.asi`
- `scripts/gtasa_cn.asi`（汉化 DLL 试验副本，已删除）
- `C:\windows\Fonts\ArialBoldCJK.ttf` 及其注册项
- 游戏目录里的 `samp.dll.bak-*`、`gta_sa.exe.bak-*`
- `sa-mp.cfg.bak-*`、`system.reg.bak-*`、`user.reg.bak-*`
- 旧的 12 MB 备份包和本次的本地崩溃修复包

> 容器里 `chcp` 仍显示 936，`HKCU\Software\Wine\Fonts\Codepages` 仍是 `936,936`。这是 CrossOver 跟随 macOS `AppleLocale=zh_CN` 的既有行为；注册表 `ACP` / `OEMCP` 已恢复为 1252 / 437，不要为了公告牌再去改代码页。

## 8. 回滚

先退出游戏和 CrossOver，再按需操作：

1. **撤销 800×600 修复**：删除游戏根目录的 `d3d9.dll`，并在 winecfg 的「函数库」中删除 `d3d9` 覆盖（或把 `user.reg` 里的 `"d3d9"="native,builtin"` 删除）。
2. **撤销窗口化**：删除 `scripts/III.VC.SA.WindowedMode.asi` 和 `.cfg`。
3. **撤销聊天字体**：删除 `sa-mp.cfg` 中的 `fontface` / `fontweight` / `fontsize` 三行，或改回 `fontface="Arial"`。
4. **撤销快捷方式**：把两个启动项的目标改回中文游戏目录下的 `samp.exe`（或直接删除 `C:\GTA` 链接后重新指定）。
5. **撤销 `0x0053388E` 补丁**：用同目录的 `gta_sa.exe.orig` 覆盖 `gta_sa.exe`，确认 SHA-256 回到 `a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26`。

```
cd "~/Library/Application Support/CrossOver/Bottles/samp/drive_c/Program Files (x86)/侠盗车手：圣安地列斯"
cp -p gta_sa.exe.orig gta_sa.exe
shasum -a 256 gta_sa.exe
```

6. **撤销 `Arial` 字体别名**（公告牌试验）：把 `system.reg` 换回备份，或把该值改回 `Arial Unicode MS`。

```
cd "~/Library/Application Support/CrossOver/Bottles/samp"
cp -p system.reg.bak-20261102-000312 system.reg     # 先确保游戏已退出
```

> 直接编辑 `system.reg` 只在**没有 wine 进程**时有效；有进程在跑时 wineserver 会用内存整份回写覆盖。要热改请走 `reg add` / `reg import`。

游戏本体、存档、服务器收藏均不受上述操作影响。

## 9. 常见问题

**启动又报 `800x600x32`**

- 检查游戏根目录 `d3d9.dll` 是否存在、哈希是否正确。
- 检查 `d3d9` 覆盖是否还在；CrossOver 更新或修复容器后可能被重置。
- 确认启动的是 `samp` 这个容器。

**中文变成方块或问号**

- 先分清位置：
  - **聊天区**：检查 `sa-mp.cfg` 的三行字体设置是否被客户端重写；确认 `system.reg` 中 `Arial Unicode MS` 仍指向 macOS 的 `Arial Unicode.ttf`。
  - **服务器公告牌**：这是当前未解决的问题，且**只影响这一块牌子**（登录菜单、对话框、记分板都正常）。不要再装 `directFont` 期待修复；此前的 directFont、代码页、字体替换和 `samp.dll` 补丁都已验证无效并回滚。详见 [§4](#4-未解决服务器公告牌中文方块) 和 [附录 K](docs/attempt-font-mapping.md)。

**想改 Wine 的字体映射，该改哪张表**

两张表，别改错：

| 目的 | 改这里 |
|---|---|
| 无条件把某个字体名换掉（例如让 `Arial` 永远走中文字体） | `HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes` |
| 只在**系统里没有这个字体**时兜底 | `HKCU\Software\Wine\Fonts\Replacements` |

改中文值不要走命令行（会被压成 `?`），用 UTF-16LE 的 `.reg` 文件 `reg import`；核对用 `reg export` 而不是 `reg query`（后者控制台编码不可靠）。细节见 [附录 K](docs/attempt-font-mapping.md)。
- 不要把 `sampaux3.ttf` 换成中文字体，它不是聊天字体。

**聊天字体被重置**

- 退出游戏后检查 `~/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg`，确认这三行仍在：  
  `fontface="Arial Unicode MS"`、`fontweight=1`、`fontsize=1`。
- 如果被改回 `Arial`，改回上面的值再进服务器。

**画面全屏、无法切窗口**

- 当前配置是 `WindowMode=2`（Borderless）。按 `Alt+Enter` / `Ctrl+Enter` 可在 Windowed 和 Borderless 之间切换；切换到 / 离开 Fullscreen 需要重启游戏。
- 如果 cfg 被改坏，删除它后重启游戏会重新生成默认设置。

**窗口太大或太小**

- 在 Borderless 模式下由桌面分辨率决定，`Width` / `Height` 不生效。
- 想要指定窗口大小：把 `WindowMode` 改成 `1`，再设 `Width` / `Height`；`0` 表示使用桌面逻辑分辨率。

**启动项打不开**

- 确认 `C:\GTA` 链接仍存在，且指向中文游戏目录。
- 启动项目标应为 `C:\GTA\samp.exe`，工作目录 `C:\GTA`。

**出现 `0x007324B6` 崩溃**

- `0x007324B6` 的补丁**当前没有安装**；但 `gta_sa.exe` **不是原版**——它带着[附录 E](docs/patch-0x0053388E.md) 的 `0x0053388E` 补丁（SHA-256 `6f2b7950...`）。两者是不同地址、互不影响。
- 崩溃特征：`CVisibilityPlugins::RenderAtomicWithAlpha`，`EAX=0xC1000000`，`ESI=7`。
- 如果再次出现，先保留崩溃日志，再按[附录 D](docs/patch-0x007324B6.md) 的 5 字节补丁处理；不要直接改 `samp.dll` 或字体。

**为什么游戏目录里没有 SilentPatch / StreamMemFix / directFont**

- 这些是排查期间临时加的，已按"恢复到实验前状态"的要求全部移除。
- `scripts\` 现在只保留窗口化插件；`samp.dll` 是原版，`gta_sa.exe` 只带[附录 E](docs/patch-0x0053388E.md) 的一个 5 字节补丁。

## 附录索引

详细的过程记录已拆到 `docs/`，每个文件独立可读，文首都有返回正文的链接。

| 附录 | 主题 | 状态 | 文件 |
|---|---|---|---|
| A–C | d3d9 代理：原理 / 源码 / 编译 | ✅ 生效中 | [`d3d9-proxy.md`](docs/d3d9-proxy.md) |
| D | `0x007324B6` 崩溃与 5 字节补丁 | ⏸ 补丁**未安装** | [`patch-0x007324B6.md`](docs/patch-0x007324B6.md) |
| E | `0x0053388E` 路牌空指针补丁 | ✅ **已安装** | [`patch-0x0053388E.md`](docs/patch-0x0053388E.md) |
| F | 进服后卡死（21:47） | ⚠️ 未复现 | [`issue-hang.md`](docs/issue-hang.md) |
| G | 静默闪退（22:21） | ⚠️ 未复现 | [`issue-silent-exit.md`](docs/issue-silent-exit.md) |
| H | 试过 DXVK，不适用 | ❌ 已回滚 | [`attempt-dxvk.md`](docs/attempt-dxvk.md) |
| I | msync 试验 | ❌ 结论作废 | [`attempt-msync.md`](docs/attempt-msync.md) |
| J | 人数显示不对 / 骤减 | ✅ 已结案（服务器更新） | [`issue-player-count.md`](docs/issue-player-count.md) |
| K | 字体映射试验（三批） | ❌ 已回滚 | [`attempt-font-mapping.md`](docs/attempt-font-mapping.md) |

> ⚠️ 附录里**部分结论已被推翻**：[附录 I](docs/attempt-msync.md) 整篇作废，[附录 J](docs/issue-player-count.md) 的 J.1–J.5 含被推翻的推理，[附录 K](docs/attempt-font-mapping.md) 是完整踩坑记录。正文（§1–§9）才是当前有效结论。
