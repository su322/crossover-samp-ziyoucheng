# crossover-samp
# 在 CrossOver 中运行 SA-MP「自由城」——配置说明

记录日期：2026-10-27
最后更新：2026-10-29

## 1. 当前状态

### 可用

- SA-MP 0.3.7-R3 能正常启动，不再报 `800x600x32` 显示模式错误。
- 游戏以 **1280×832 无边框窗口**运行（等于本机逻辑桌面分辨率）。
- 服务器浏览器、收藏服务器、中文聊天、中文对话框和记分板正常。
- 两个 CrossOver 启动入口、存档、服务器地址均保留。
- `gta_sa.exe`、`samp.dll` 为原版文件，未打补丁；`scripts\` 只有窗口化插件。

### 未解决

- 服务器里的中文公告牌 / 部分 TextDraw（左上规则、登录菜单等）仍然显示方块。
- 聊天区和 SA-MP 自己的 UI 正常；方块只出现在使用 GTA 位图字体的 TextDraw 上。
- 已停止继续尝试。`directFont`、自定义 CJK 字体、改代码页、改 `samp.dll` 字体名等方案均无效，且已全部回滚。

### 崩溃补丁状态

- 排查期间出现过 `0x007324B6` 崩溃（`CVisibilityPlugins::RenderAtomicWithAlpha`）。
- 当时用 SilentPatchSA + StreamMemFix + `gta_sa.exe` 5 字节补丁验证过不崩；按“恢复到实验前状态”的要求，**这些补丁已全部移除**。
- 当前 `gta_sa.exe` 是原版（SHA-256 `a559aa77...`），没有安装任何崩溃补丁。
- 如果 `0x007324B6` 再次出现，处理步骤和 5 字节补丁记录在附录 D。

## 2. 环境与路径

| 项目           | 值                                                         |
| -------------- | ---------------------------------------------------------- |
| macOS          | 15.7                                                       |
| 机器           | MacBook Air（Apple M4，16 GB）                             |
| CrossOver      | 26.3                                                       |
| 容器（bottle） | `samp`，Windows 10（build 19045）                          |
| 游戏来源       | 自由城官网 `http://www.zycdjz1.com/`                       |
| 游戏           | GTA: San Andreas 1.0 + SA-MP 0.3.7-R3 整合包               |
| 服务器         | `★Drift Star★自由城1`，`ds.zycdjz1.com:7777`               |
| 实际连接       | 2026-10-29 为 `154.12.58.112:7777`（以当时 DNS 解析为准）  |
| 显示           | 2560×1664 Retina；逻辑分辨率 1280×832                      |
| 游戏窗口       | 无边框 1280×832；`fpslimit=90`，实际帧率随场景变化         |

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

> 这一节只解决**聊天区**。服务器公告牌、规则、登录菜单等 TextDraw 走 GTA 的 `CFont`，改 `sa-mp.cfg` 对它们不生效；这部分仍然显示方块，见第 4 节。

### 3.4 中文路径与启动项

原游戏目录名含中文，因此：

- 建立 `C:\GTA` → 中文目录的链接；
- 两个启动项的 `.lnk` 目标改为 `C:\GTA\samp.exe`，工作目录设为 `C:\GTA`；
- CrossOver 里的两个入口都保留，名称未改。

## 4. 未解决：中文公告牌 / TextDraw 方块

**现象**：聊天区以及其他地方的中文已经正常，但公告牌仍然是一排方块（`□□□□`）。

**原因**：这些文字是 SA-MP 的 **TextDraw**，最终走 GTA 的 `CFont` / `models/fonts.txd` 位图字体。该字体只有拉丁字符，没有汉字，所以 `sa-mp.cfg` 的 `fontface` 管不到它。

### 4.1 已尝试且无效的方案

| 尝试 | 具体做法 | 结果 | 现状 |
| ---- | -------- | ---- | ---- |
| directFont v2.2 | `scripts/directFont.asi` + `directFont.ini`，四个字体槽均为 `Arial Unicode MS`，`CharSet=134`（GB2312） | 公告牌仍方块 | 已删除 |
| 代码页 936 + 自定义字体 | 容器 `ACP` / `OEMCP` 改为 936，把 23 MB 的 `ArialBoldCJK.ttf` 放进 `C:\windows\Fonts` 并注册为 `Arial Bold CJK` | 无效 | 字体和注册项已删除；`ACP=1252`、`OEMCP=437`、`MACCP=10000`、语言 `0409` 已恢复 |
| Wine 字体替换 | `HKCU\Software\Wine\Fonts\Replacements\Arial = Arial Unicode MS` | 无效 | 已恢复 `Arial = Bitstream Vera Sans` |
| 改 `samp.dll` 的字体名 | 文件偏移 `0xEA400`、`0x117494` 两处明文 `Arial` 改成 GBK `宋体` | 无效 | 已恢复原版 `samp.dll` |
| 反汇编定位字体创建 | `D3DXCreateFontA` 调用点 `0x1006B318`：face 字符串 `0x100EA400`（`Arial`），`Height=38`、`Width=10`、`Weight=700`、`CharSet=1` | 改字体名未生效 | 未再修改 |

### 4.2 结论

- 聊天区走 SA-MP 自己的 D3DX 字体（`sa-mp.cfg`），所以聊天正常。
- 公告牌 / TextDraw 走 GTA 的位图字体；`directFont` 理论上应接管 `CFont`，但对这个服务器的公告牌没有效果。可能是服务器用了 TextDraw 贴图 / 自定义渲染，或 Wine 下的 D3DX 字体路径没有按预期生效。
- 没有继续验证。现有的聊天、对话框、记分板都正常，公告牌方块只是显示问题，不影响游戏。
- 不要再把 `sampaux3.ttf` 换成中文字体；它是图标字体。
- 如果以后要再试，先确认公告牌到底是 `TextDraw` 还是 `3DTextLabel`，再分别定位；不要在 `gta_sa.exe` / `samp.dll` 上反复打补丁。

## 5. 日常启动步骤

1. 打开 CrossOver，或从启动台打开：
   - 「圣安地列斯 联机工具 SA-MP 0.3.7-R3语音插件版」
   - 或「圣安地列斯游戏本体+SAMP-R3带语音插件汉化版」
2. 在 SA-MP 服务器浏览器中找到「★Drift Star★自由城1」。
3. 选中服务器，点「连接」。
4. 进入服务器后聊天、对话框、记分板正常；公告牌 / 部分 TextDraw 仍会是方块，这是当前已知状态。

服务器地址：`ds.zycdjz1.com:7777`
收藏记录保存在 `SAMP/USERDATA.DAT`，未改动。

## 6. 文件与配置清单

### 生效 / 新增的文件

| 路径                                                    | 作用                              | 校验值 / 当前值                                              |
| ------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------ |
| 游戏根目录 `d3d9.dll`                                   | 800×600×32 模式代理，271,360 字节 | SHA-256 `fde5c00e2246f939ae542b5535cd39642dfaeda020a169bf11494b560fb134c2` |
| `scripts/III.VC.SA.WindowedMode.asi`                    | 窗口化插件，3,232,600 字节        | SHA-256 `8b2485e89761044f56bbd4e2fa882ec9667939edf542fde682e016bd7e9373a9` |
| `scripts/III.VC.SA.WindowedMode.cfg`                    | 窗口化设置                        | `WindowMode=2`（Borderless）、`Width=640`、`Height=480`、`PositionX=640`、`PositionY=416` |
| `~/Documents/GTA San Andreas User Files/SAMP/sa-mp.cfg` | 聊天字体 / 帧率设置               | 见 3.3                                                       |
| `~/Library/.../Bottles/samp/user.reg`                   | `d3d9=native,builtin` 覆盖        | 见 3.1                                                       |
| `C:\GTA`                                                | 指向中文游戏目录的链接            | —                                                            |
| 两个 CrossOver `.app` / `.lnk`                          | 启动入口，目标 `C:\GTA\samp.exe`  | 工作目录 `C:\GTA`，无额外参数                                |

### 未改动的原文件

| 文件                                      | SHA-256                                                      |
| ----------------------------------------- | ------------------------------------------------------------ |
| `gta_sa.exe`                              | `a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26` |
| `samp.dll`                                | `9c9b2cc31a4ced6967420b1880c096b5c4e7630e227aa379be4019c21b6fddc1` |
| `samp.exe`                                | `b5e760036bc2cd8c3b6ce6c3fd0d2a3f5ea896a33ffcbc3914d6895d1e46dfa5` |
| `sampaux3.ttf`                            | `3adfe84498e8951e61ece57ad08de21b95d162697517291564ae6ef3a8790c1b` |
| `gtaweap3.ttf`                            | `086dc4351bf1056d80a73168440ffe4261831bde992e5134902b9bae017dcbe9` |
| `vorbisFile.dll`（整合包自带 ASI Loader） | `c33e1bafafd441b42eaa6d322393b9dd700f8a9c13fb2e7780daf49707a46353` |
| `models/fonts.txd`（GTA 原版位图字体）   | `5ca77cddb15f96de29b3786cb5620492dbc310d29af2d1374e644d74f1a61cbf` |

`gta_sa.exe` 和 `samp.dll` 没有改名、没有打补丁；`fonts.txd` 也没有替换。游戏目录 `scripts\` 现在只有：

```
III.VC.SA.WindowedMode.asi
III.VC.SA.WindowedMode.cfg
```

### 已移除的排查文件

- `scripts/directFont.asi`、`scripts/directFont.ini`
- `scripts/SilentPatchSA.asi`、`scripts/SilentPatchSA.ini`、`scripts/StreamMemFix.asi`
- `C:\windows\Fonts\ArialBoldCJK.ttf` 及其注册项
- 游戏目录里的 `samp.dll.bak-*`、`gta_sa.exe.bak-*`
- `sa-mp.cfg.bak-*`、`system.reg.bak-*`、`user.reg.bak-*`
- 旧的 12 MB 备份包和本次的本地崩溃修复包

> 容器里 `chcp` 仍显示 936，`HKCU\Software\Wine\Fonts\Codepages` 仍是 `936,936`。这是 CrossOver 跟随 macOS `AppleLocale=zh_CN` 的既有行为；注册表 `ACP` / `OEMCP` 已恢复为 1252 / 437，不要为了公告牌再去改代码页。

## 7. 回滚

先退出游戏和 CrossOver，再按需操作：

1. **撤销 800×600 修复**：删除游戏根目录的 `d3d9.dll`，并在 winecfg 的「函数库」中删除 `d3d9` 覆盖（或把 `user.reg` 里的 `"d3d9"="native,builtin"` 删除）。
2. **撤销窗口化**：删除 `scripts/III.VC.SA.WindowedMode.asi` 和 `.cfg`。
3. **撤销聊天字体**：删除 `sa-mp.cfg` 中的 `fontface` / `fontweight` / `fontsize` 三行，或改回 `fontface="Arial"`。
4. **撤销快捷方式**：把两个启动项的目标改回中文游戏目录下的 `samp.exe`（或直接删除 `C:\GTA` 链接后重新指定）。

游戏本体、存档、服务器收藏均不受上述操作影响。

## 8. 常见问题

**启动又报 `800x600x32`**

- 检查游戏根目录 `d3d9.dll` 是否存在、哈希是否正确。
- 检查 `d3d9` 覆盖是否还在；CrossOver 更新或修复容器后可能被重置。
- 确认启动的是 `samp` 这个容器。

**中文变成方块或问号**

- 先分清位置：
  - **聊天区**：检查 `sa-mp.cfg` 的三行字体设置是否被客户端重写；确认 `system.reg` 中 `Arial Unicode MS` 仍指向 macOS 的 `Arial Unicode.ttf`。
  - **公告牌 / TextDraw / 对话框**：这是当前未解决的问题。不要再装 `directFont` 期待修复；此前的 directFont、代码页、字体替换和 `samp.dll` 补丁都已验证无效并回滚。
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

- 当前没有安装任何崩溃补丁，`gta_sa.exe` 是原版。
- 崩溃特征：`CVisibilityPlugins::RenderAtomicWithAlpha`，`EAX=0xC1000000`，`ESI=7`。
- 如果再次出现，先保留崩溃日志，再按附录 D 的 5 字节补丁处理；不要直接改 `samp.dll` 或字体。

**为什么游戏目录里没有 SilentPatch / StreamMemFix / directFont**

- 这些是排查期间临时加的，已按“恢复到实验前状态”的要求全部移除。
- 当前只保留窗口化插件；游戏本体和 `samp.dll` 都是原版。

## 附录 A：d3d9 代理原理

1. 游戏加载同目录的 `d3d9.dll`（需要 `d3d9=native,builtin` 覆盖）。
2. 代理在 `DllMain` 中不做任何渲染工作，只把 `Direct3DCreate9` / `Direct3DCreate9Ex` 转发给 `C:\windows\system32\d3d9.dll`。
3. 拿到真正的 `IDirect3D9` 对象后，复制一份虚函数表，替换其中两个函数：
   - `GetAdapterModeCount`：返回值 +1；
   - `EnumAdapterModes`：多出来的那一项返回 `800×600`、`RefreshRate=0`、格式为请求的 32 位格式。
4. 游戏因此能在模式列表里找到 `800x600x32`，正常进入。
5. 除这两个方法外，其余 D3D9 调用全部走原实现，不影响渲染。

## 附录 B：`d3d9proxy.c`（最终无日志版）

```c
#include <windows.h>
#include <d3d9.h>

static HMODULE g_real_d3d9;
static IDirect3D9 * (WINAPI *g_real_create9)(UINT);
static HRESULT (WINAPI *g_real_create9ex)(UINT, IDirect3D9Ex **);
static IDirect3D9Vtbl *g_orig_vtbl;
static IDirect3D9Vtbl *g_new_vtbl;
static int g_patched;

static UINT __stdcall hook_GetAdapterModeCount(IDirect3D9 *self, UINT Adapter, D3DFORMAT Format)
{
    UINT n = g_orig_vtbl->GetAdapterModeCount(self, Adapter, Format);
    return n + 1;
}

static HRESULT __stdcall hook_EnumAdapterModes(IDirect3D9 *self, UINT Adapter, D3DFORMAT Format,
                                               UINT Mode, D3DDISPLAYMODE *pMode)
{
    UINT n = g_orig_vtbl->GetAdapterModeCount(self, Adapter, Format);
    if (Mode < n)
        return g_orig_vtbl->EnumAdapterModes(self, Adapter, Format, Mode, pMode);
    if (Mode == n) {
        if (!pMode) return D3DERR_INVALIDCALL;
        pMode->Width = 800;
        pMode->Height = 600;
        pMode->RefreshRate = 0;
        pMode->Format = (Format == D3DFMT_UNKNOWN) ? D3DFMT_X8R8G8B8 : Format;
        return S_OK;
    }
    return D3DERR_INVALIDCALL;
}

static void patch_vtable(IDirect3D9 *obj)
{
    if (!obj) return;
    if (!g_patched) {
        g_orig_vtbl = obj->lpVtbl;
        g_new_vtbl = (IDirect3D9Vtbl *)VirtualAlloc(NULL, sizeof(IDirect3D9Vtbl),
                                                    MEM_COMMIT | MEM_RESERVE,
                                                    PAGE_READWRITE);
        if (!g_new_vtbl) return;
        memcpy(g_new_vtbl, g_orig_vtbl, sizeof(IDirect3D9Vtbl));
        g_new_vtbl->GetAdapterModeCount = hook_GetAdapterModeCount;
        g_new_vtbl->EnumAdapterModes = hook_EnumAdapterModes;
        g_patched = 1;
    }
    obj->lpVtbl = g_new_vtbl;
}

static void load_real(void)
{
    if (g_real_d3d9) return;
    g_real_d3d9 = LoadLibraryA("C:\\windows\\system32\\d3d9.dll");
    if (!g_real_d3d9) return;
    g_real_create9 = (void *)GetProcAddress(g_real_d3d9, "Direct3DCreate9");
    g_real_create9ex = (void *)GetProcAddress(g_real_d3d9, "Direct3DCreate9Ex");
}

IDirect3D9 * WINAPI Direct3DCreate9(UINT SDKVersion)
{
    IDirect3D9 *obj;
    load_real();
    if (!g_real_create9) return NULL;
    obj = g_real_create9(SDKVersion);
    patch_vtable(obj);
    return obj;
}

HRESULT WINAPI Direct3DCreate9Ex(UINT SDKVersion, IDirect3D9Ex **ppD3D)
{
    HRESULT hr;
    load_real();
    if (!g_real_create9ex) return E_FAIL;
    hr = g_real_create9ex(SDKVersion, ppD3D);
    if (SUCCEEDED(hr) && ppD3D && *ppD3D)
        patch_vtable((IDirect3D9 *)*ppD3D);
    return hr;
}

BOOL WINAPI DllMain(HINSTANCE hinst, DWORD reason, LPVOID reserved)
{
    if (reason == DLL_PROCESS_ATTACH)
        DisableThreadLibraryCalls(hinst);
    return TRUE;
}
```

## 附录 C：编译方法

代理导出两个函数，需要 `d3d9.def`：

```def
LIBRARY d3d9
EXPORTS
    Direct3DCreate9
    Direct3DCreate9Ex
```

使用 Homebrew 的 zig（本机为 0.17.0）交叉编译为 32 位 Windows DLL：

```bash
brew install zig   # 如果还没有
zig cc -target x86-windows-gnu -shared -g -O2 \
    -o d3d9.dll d3d9proxy.c d3d9.def
```

验证导出表：

```bash
llvm-objdump -p d3d9.dll | sed -n '/Export Table/,/^$/p'
```

应看到：

```
Direct3DCreate9
Direct3DCreate9Ex
```

把生成的 `d3d9.dll` 放到游戏根目录，并确保 `d3d9=native,builtin` 覆盖存在即可。`-g` 只是保留调试信息，不影响运行；如不需要可去掉。

## 附录 D：`0x007324B6` 崩溃与 5 字节补丁（当前未安装）

### D.1 崩溃特征

- 地址：`0x007324B6`
- 函数：`CVisibilityPlugins::RenderAtomicWithAlpha`
- 寄存器：`EAX=0xC1000000`，`ESI=7`
- 触发场景：排查字体 / 渲染补丁期间出现过；用户表示在开始排查前没有崩溃。

### D.2 5 字节补丁

只适用于 GTA San Andreas 1.0 的 `gta_sa.exe`：

| 项目         | 值                                                           |
| ------------ | ------------------------------------------------------------ |
| 文件偏移     | `0x3318B0`                                                   |
| 原始字节     | `8B 4F 20 8B 04`                                             |
| 补丁字节     | `E9 1D 00 00 00`（`jmp 0x7324D2`）                           |
| 原始 SHA-256 | `a559aa772fd136379155efa71f00c47aad34bbfeae6196b0fe1047d0645cbd26` |
| 补丁后 SHA-256 | `a29d77a07effc5a2afc1dd991b9e5c95d84f5c9edd7cda235e47a1c549ce84cb` |

补丁跳过 `RenderAtomicWithAlpha` 里按材质遍历 alpha 的循环。它只规避这个特定崩溃，不修字体，也不保证所有场景都不崩。

当时还配合使用过：

| 文件                | SHA-256                                                      |
| ------------------- | ------------------------------------------------------------ |
| `SilentPatchSA.asi` | `908e1d12e36ba809a8ce584be0bd29239349968259a5de593f9b0cc71dbb352b` |
| `StreamMemFix.asi`  | `f91694b032b19c449323c04e8832d607016861ded19e40a1d69bf07ab72e74b4` |

这三样在验证后已全部移除，游戏目录里没有它们。本地崩溃修复包也已删除；下面是可复现的补丁脚本。

### D.3 重新打补丁（仅在崩溃复发时）

先备份 `gta_sa.exe`，然后在游戏目录运行：

```python
#!/usr/bin/env python3
"""GTA SA 1.0: 5-byte workaround for the 0x007324B6 alpha-material crash."""
import hashlib
import pathlib
import sys

OFFSET = 0x3318B0
ORIGINAL = bytes.fromhex("8B 4F 20 8B 04")
PATCH = bytes.fromhex("E9 1D 00 00 00")

path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "gta_sa.exe")
data = bytearray(path.read_bytes())
current = bytes(data[OFFSET:OFFSET + len(PATCH)])

if current == PATCH:
    print("already patched:", path)
elif current == ORIGINAL:
    data[OFFSET:OFFSET + len(PATCH)] = PATCH
    path.write_bytes(data)
    print("patched:", path)
else:
    sys.exit(f"unexpected bytes at {OFFSET:#x}: {current.hex()}")

print("sha256:", hashlib.sha256(data).hexdigest())
```

打完后的 SHA-256 应为 `a29d77a07effc5a2afc1dd991b9e5c95d84f5c9edd7cda235e47a1c549ce84cb`。

还原：把备份的原始 `gta_sa.exe` 换回来，或确认 SHA-256 回到 `a559aa77...`。如果同时装了 SilentPatch / StreamMemFix，也要从 `scripts\` 删除。
