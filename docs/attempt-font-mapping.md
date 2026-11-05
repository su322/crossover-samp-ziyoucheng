# 字体映射试验（三批）

> 返回 [README](../README.md)

这是服务器公告牌中文方块问题的完整排查记录。

---

## 最终结论（2026-11-05）

**三批字体映射全部作废。真正解决问题的是换联机端版本：`0.3.7-R3` → `0.3.DL-R1`，换完公告牌中文直接正常，不需要改任何字体配置。**

**真因（2026-11-05 实测确认）**：两个版本画公告牌用的**字体不是同一个**。

| | 0.3.7-R3 | 0.3.DL-R1 |
|---|---|---|
| 请求 `Arial` h=38 w=700 | ✅ | ✅（备用） |
| 请求 `SimSun` h=38 w=700 | ❌ **0 次** | ✅ **14 次** |
| `Chosen: 冬青黑体简体中文 W3` | **0** | 5 |
| 公告牌 | 方块 | 正常 |

0.3.DL 的公告牌渲染会同时创建 `Arial` 和 `SimSun` 两套字体，实际绘制用 `SimSun`。Wine/CrossOver 把 `SimSun` 映射到 `冬青黑体简体中文 W3`（`Hiragino Sans GB.ttc`），**有完整汉字字形**，所以中文正常。

`SimSun` 不在 `samp.dll` 里（ASCII 和 UTF-16LE 都搜不到），说明它是**服务器通过 `SetObjectMaterialText` 的 `fontFace` 参数下发**的。0.3.7-R3 忽略了该参数，退化成 `Arial`。

**所以本文下面推导的"粗体字重缺失导致方块"只对 `Arial` 那套字体成立，而 `Arial` 根本不是公告牌的实际字体。** 改 `Arial` 的映射当然无效——真正画字的是 `SimSun`，它本来就是好的。

保留本文是为了记录踩过的坑，**不要照着这里的方法再去改字体**。

---

下文按时间顺序记录三批试验的过程。

## 关键发现：CrossOver 的替换表漏了 `SimHei`

`user.reg` 的 `[Software\Wine\Fonts\Replacements]` 共 34 条映射，其中中文相关的是：

| Windows 字体名 | 映射到 | 有汉字字形 |
|---|---|---|
| `SimSun` / `NSimSun` / `@SimSun` / `@宋体` | `STSong` | ✅ |
| **`SimHei`（黑体）** | **未映射** | — |
| `Arial` | `Bitstream Vera Sans` | ❌ 纯拉丁 |

**当时的假设是**：中文服务器在 `SetObjectMaterialText` 里最常用的字体恰恰是 `SimHei` / `黑体`——Windows 上它存在，一切正常；Wine 里没有，于是回退到拉丁字体 → 方块。**这个假设已被实测证伪**（见下一节）。

同时排除了另一个干扰项：早先把 `Arial` 换成 `Arial Unicode MS` 却"无效"，很可能不是方向错，而是**直接编辑 `user.reg` 被运行中的 wineserver 用内存覆盖了**。这是个方法论陷阱：改 `user.reg` 必须在没有 wine 进程时做，或者改用 `wine reg add` 走 wineserver。

---

## 第一批：`SimHei` 家族 → `STHeiti`（已试，❌ 无效）

用 `wine reg add` 写入，共 8 条：

```
SimHei              -> STHeiti
黑体                 -> STHeiti
Microsoft YaHei     -> STHeiti
Microsoft YaHei UI  -> STHeiti
微软雅黑              -> STHeiti
KaiTi               -> STKaiti
FangSong            -> STSong
宋体                 -> STSong
```

**结果：重启游戏后公告牌仍是方块。**

但这次要排除"改了没生效"这个干扰项——先证明映射确实写进去了：

```
=== user.reg 文件里（wineserver 退出后回写的最终状态）===
"SimHei"="STHeiti"
"Microsoft YaHei"="STHeiti"
=== wineserver 内存中 ===
SimHei    REG_SZ    STHeiti
```

8 条全部在位。所以**这次失败是真的失败，不是没写进去**。

---

## 第二批：常见拉丁字体 → `Arial Unicode MS`（已试，❌ 无效）

既然不是 `SimHei`，最可能就是**拉丁字体名**。`SetObjectMaterialText` 在服务端不指定字体时默认用 `Arial`；而 Wine 把 `Arial` 映射成 `Bitstream Vera Sans`——纯拉丁、无汉字。

又写了 7 条，全部指向 `Arial Unicode MS`：

```
Arial                -> Arial Unicode MS
Tahoma               -> Arial Unicode MS
Verdana              -> Arial Unicode MS
Microsoft Sans Serif -> Arial Unicode MS
MS Sans Serif        -> Arial Unicode MS
Trebuchet MS         -> Arial Unicode MS
Segoe UI             -> Arial Unicode MS
```

**结果：重启游戏后公告牌仍是方块。**

> 注意：早先也试过一次 `Arial = Arial Unicode MS` 但无效（见 README §4.1）。那次很可能是**直接改 `user.reg`、被运行中的 wineserver 用内存覆盖掉了**——这次改走 `wine reg add`，且已在 wineserver 内存里逐条确认。

---

## 抓到的证据：替换机制本身是通的

用 `--debugmsg +font` 抓到 `samp.exe` 的字体请求，直接看到替换链：

```
font_SelectFont L"Arial", h=-11, it=0, weight=400, PandF=00, charset=134
find_matching_face substituting L"Arial",134 -> L"Arial Unicode MS",134
select_font Chosen: L"Arial Unicode MS" (.../System/Library/Fonts/Supplemental/Arial Unicode.ttf)
```

`charset=134` 就是 GB2312。也就是说「中文请求 + `Arial`」确实被换成了有汉字的 `Arial Unicode MS`，**替换表是生效的**。

反过来，公告牌仍方块这件事，就更指向「它根本不走这条路径」。

同时抓到一条反例，说明替换表不是万能的：

```
font_SelectFont L"MS Sans Serif", h=-11, weight=400, charset=134
select_font Chosen: L"MS Sans Serif Regular" (.../CrossOver/share/wine/fonts/sserife.fon)
```

`sserife.fon` 是**位图点阵字体**，没有任何汉字字形，而这里**没有** `substituting` 记录——`MS Sans Serif -> Arial Unicode MS` 这条映射压根没被触发。Wine 只在「按名字找不到字体」时才查替换表，而 `MS Sans Serif` 是能"找到"的（从 `.fon` 里），于是原样使用。

**这是重要教训：`Replacements` 不是兜底回退，只对"名字不存在"的请求生效。**

> 后来发现这里还有一层：上面那条 `Arial -> Arial Unicode MS` 的 `substituting` 其实**不是 `Replacements` 干的**，而是另一张无条件生效的表 `FontSubstitutes`（见下文「真正的元凶」）。两张表容易混为一谈，正是前面几轮反复扑空的根本原因。

---

## 两批都失败后，能排除掉什么

| 已排除 | 依据 |
|---|---|
| `SimHei` / `黑体` / `微软雅黑` 是服务端请求的字体 | 第一批映射已确认写入且生效，仍方块 |
| `Arial` / `Tahoma` / `Verdana` 等常见拉丁字体 | 第二批映射已确认写入且生效，仍方块 |
| 代码页导致的字体名乱码 | 容器 `ACP` = `OEMCP` = **936**（GBK），GBK 字体名会被正确解码 |
| 字体映射被 Wine 缓存挡住 | 瓶内没有 `~/.cache/wine` 字体缓存 |
| `samp.dll` 根本不用 GDI 渲染文字 | 它的导入表里有 `GDI32.dll`，并通过 `d3dx9_25.dll` 调用 `D3DXCreateFontA` / `D3DXCreateFontIndirectA`——Wine 的 d3dx9 字体实现底层就是 GDI |

**剩下两种可能**：

- **A.** 服务端请求的字体名很偏，我们没覆盖到；
- **B.** 这条文字根本不走系统字体，而是走 GTA 自己的位图字体 `models/fonts.txd`——那样任何字体映射都不会有效。

这两种只能靠抓实际请求来区分。

---

## 已抓到根因：粗体字重没有中文（2026-11-01 23:50）

用 `--debugmsg +font` 抓到 `gta_sa.exe` 发出的全部字体请求，答案直接摆在眼前：

```
L"Arial", h=120, it=0, weight=700, PandF=00, charset=1     ← 大号粗体，就是公告牌
L"Arial", h=80,  it=0, weight=700, PandF=00, charset=1
L"Arial", h=38,  it=0, weight=700, PandF=00, charset=1
→ substituting L"Arial",1 -> L"Arial Unicode MS",1
→ select_font Chosen: L"Arial Bold"  (…/Arial Bold.ttf)     ← 纯拉丁，无汉字
```

**替换表生效了，但结果还是错的。** 原因是：

- `Arial Unicode MS` 在 macOS 上**只有常规体（weight 400），没有粗体**
- 请求的是 `weight=700`
- Wine 换成 `Arial Unicode MS` 后找不到 700 的字重，于是**退回原家族 `Arial` 的粗体面** `Arial Bold.ttf`
- `Arial Bold.ttf` 是纯拉丁字体 → 方块

这也解释了为什么聊天正常：聊天走的是 `Arial Unicode MS`、`weight=400`（`h=16~22`），常规体有汉字，所以没事。**只有粗体这条路径是坏的。**

| 请求 | 结果 | 有汉字 |
|---|---|---|
| `Arial Unicode MS`, weight=400 | `Arial Unicode MS` | ✅ 聊天正常 |
| `Arial`, weight=700 | `Arial Bold` | ❌ 公告牌方块 |

---

## 第一次修复尝试：改 `Replacements` 指向苹方-简（已试，❌ 空操作）

按上一节的结论，把 `Arial` 从 `Arial Unicode MS` 改指向**苹方-简**：

```sh
wine --bottle samp reg add 'HKCU\Software\Wine\Fonts\Replacements' \
     /v "Arial" /d "苹方-简" /f
```

备份：`user.reg.bak-20261101-235111`

> 为什么选它：容器里 `STHeiti` 只注册了一个面（`STHEITI.ttf`），没有粗体，会重蹈 `Arial Unicode MS` 的覆辙。`苹方-简` 有 `常规体 / 中粗体 / 中黑体 / 细体 / 极细体 / 纤细体` 六个面，`weight=700` 能落到 `中粗体`。

**结果：完全没生效。** 重抓日志，`苹方` 出现 **0 次**，替换记录依然是：

```
substituting L"Arial",1 -> L"Arial Unicode MS",1
```

而注册表两边都是对的：

```
=== user.reg 文件里 ===        "Arial"="\x82f9\x65b9-\x7b80"
=== wineserver 内存里 ===      Arial    REG_SZ    苹方-简
```

写进去了、读得到、就是不生效——说明**这条路径根本没被查询**。

---

## 真正的元凶：`FontSubstitutes` 是另一张表，且优先级更高（2026-11-02 00:04）

翻 `system.reg` 找到了：

```
[Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
"Arial"="Arial Unicode MS"
```

Wine 有**两张互不相干**的字体替换表，之前一直把它们当成一张：

| 表 | 注册表位置 | 触发条件 | 优先级 |
|---|---|---|---|
| `FontSubstitutes` | `HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes` | **无条件**，请求一到就改写 | 先 |
| `Replacements` | `HKCU\Software\Wine\Fonts\Replacements` | **只在按名字找不到字体时**才查 | 后 |

这一条把之前所有反常现象一次解释干净：

- `Arial` 明明有 `Arial.ttf`，却仍然产生 `substituting` 记录 → 因为它走的是**无条件**的 `FontSubstitutes`
- `Arial` = `苹方-简` 写在 `Replacements` 里永远是死数据 → 因为 `Arial` 能"找到"，`Replacements` 不查
- `MS Sans Serif` / `Tahoma` 完全没有 `substituting` 记录 → 它们不在 `FontSubstitutes` 里，而 `Replacements` 又因为能"找到"而不触发

补充两个容易踩的点：

- `HKLM\Software\Wow6432Node\...\FontSubstitutes` **不是副本**，而是一条符号链接。32 位进程读它等于读原生键，只需改一处。
- 直接改 `system.reg` 文件没用：运行中的 wineserver 会在退出时用内存整份回写（实测改完 1 分钟内文件就被覆盖成内存版本）。

---

## 正确做法：改 `FontSubstitutes`，并绕开中文命令行编码

```sh
wine --bottle samp reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' \
     /v Arial /d 苹方-简 /f
```

**这条命令会把汉字写坏。** 实测结果是 `Arial REG_SZ ??-?`——CrossOver 的启动器在转命令行时用了非中文代码页，每个汉字都被压成 `?`。

改用 `.reg` 文件导入，且文件本身存成 **UTF-16LE**：

```
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
"Arial"="苹方-简"
```

```sh
printf '\xff\xfe' > fix.reg                     # BOM
printf '...' | iconv -f UTF-8 -t UTF-16LE >> fix.reg
wine --bottle samp reg import 'Z:\tmp\fix.reg'
```

> **`hex(1)` 不能用。** 直觉上 `"Arial"=hex(1):f9,82,b9,65,...`（UTF-16LE 的 `苹方-简`）应该最稳，但 Wine 的 regedit 把 `hex(1)` 的字节按 **ANSI 单字节**解释，`f9 82 b9 65` 变成了 `ù‚¹e`。必须走 UTF-16LE 文本文件这条路。

验证要用 `reg export` 而不是 `reg query`（导出文件是 UTF-16，转码后无歧义）：

```sh
wine --bottle samp reg export 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' \
     'Z:\tmp\out.reg' /y
iconv -f UTF-16LE -t UTF-8 /tmp/out.reg | grep '^"Arial"'
# → "Arial"="苹方-简"
```

备份：`system.reg.bak-20261102-000312`

---

## 事前验证：`苹方-简` 确实是「一个家族、多个字重」

改之前先确认了这点——如果 6 个面各自是独立家族，请求 `苹方-简` 会整个落空，又退回 `Arial Bold`。直接解析 `PingFang.ttc` 的 `name` 表（共 24 个面）：

```
[3]  family='苹方-简'  style='常规体'  usWeightClass=400
[7]  family='苹方-简'  style='中黑体'  usWeightClass=500
[11] family='苹方-简'  style='中粗体'  usWeightClass=600
[15] family='苹方-简'  style='细体'    usWeightClass=300
[19] family='苹方-简'  style='纤细体'  usWeightClass=200
[23] family='苹方-简'  style='极细体'  usWeightClass=100
```

同一个 `family`、六个 `style`、字重 100–600。`weight=700` 的请求会匹配到最近的 **600「中粗体」**，它有完整汉字。

---

## 第二次修复：换成有真 700 粗体的 `宋体-简`（2026-11-02 00:13）

改完 `FontSubstitutes` 后替换**确实生效了**——日志里第一次出现 `苹方`：

```
substituting L"Arial",1 -> L"\82f9\65b9-\7b80",1        ← 苹方-简，命中了
Chosen: L"苹方-简 常规体"    (weight=400，正确)
Chosen: L"苹方-简 极细体"    (weight=700，❌ 掉到字重 100)
```

但公告牌仍是方块。原因是 **`苹方-简` 根本没有 700 这个字重**（最高 600），Wine 找不到精确匹配，走进容错分支，挑到了最细的「极细体」。

于是把瓶子里所有中文字体的 `OS/2.usWeightClass` 全解析了一遍：

| 家族 | 可用字重 | 能精确命中 700？ |
|---|---|---|
| **`宋体-简`** | **300 / 400 / 700 / 900** | ✅ |
| `简宋` | 400 / 700 | ✅ |
| `苹方-简` | 100 / 200 / 300 / 400 / 500 / 600 | ❌ |
| `楷体-简` | 400 / 400 / 400（三个面全是 400） | ❌ |
| `黑体-简` / `圆体-简` / `兰亭黑-简` | 全 400 | ❌ |

改成 `Arial → 宋体-简` 后，实测日志：

```
8  Chosen: L"宋体-简 黑体"      ← weight=700 的请求，拿到了有汉字的粗体面
7  Chosen: L"宋体-简 常规体"    ← weight=400，正常
```

这是**第一条真正可用的粗体中文路径**（之前 `Arial Bold` 只剩 4 次，都是 `charset=0` 的边缘请求）。

> 顺带纠正一条旧结论：`STKaiti` **不在瓶子里**，所以第一批加的 `KaiTi → STKaiti` 一直是死映射。

---

## 又一个发现：公告牌还会请求 `simkai`（楷体）

同一份日志里，第一次出现：

```
font_SelectFont L"simkai", h=120, weight=700, charset=1
font_SelectFont L"simkai", h=100, weight=700, charset=1
```

`simkai` 是 Windows 楷体，瓶子里没有注册，请求后没有任何 `Chosen`。所以除了 `Arial`，这条也得映射：

```
simkai -> 宋体-简     # 先保证能显示
```

> 为什么不直接给 `楷体-简`：它三个面字重全是 400，`weight=700` 时仍会掉进容错分支，有再次落空的风险。**先让它显示出来，风格之后一行就能换。**
> 瓶内可用的中文家族：苹方/宋体/楷体/圆体/黑体/兰亭黑/冬青黑体/简宋/翩翩体/手札体/隶变/魏碑/娃娃体/雅痞/凌慧体/报隶/行楷。

最终 `FontSubstitutes` 内容（备份 `system.reg.bak-20261102-001138`）：

```
Arial   -> 宋体-简
simkai  -> 宋体-简
KaiTi   -> 楷体-简
楷体     -> 楷体-简
```

---

## 结论：字体层面成功，但游戏被拖垮 —— 已全部回滚（2026-11-02 00:18）

`宋体-简` 这条路径**在字体层面是通的**：日志里第一次出现 `Chosen: L"宋体-简 黑体"`（`weight=700` 的请求拿到了有汉字的粗体面），这是此前所有尝试都没做到过的。

但实际启动后，游戏**卡死并闪退**。而在这之前的几小时里游戏一直稳定，唯一的变量就是这组字体映射。

> 中途还有一次误判：先把卡死归因于"日志管道被撑爆"（`+font` 去掉去重后 70 秒写 3.5 MB）。过滤器修好、**完全不开日志正常启动依然卡死并闪退**，才排除了日志因素，确认问题在字体映射本身。

**判断**：把全局 `Arial` 换成 CJK 字体代价太大——`Arial` 是游戏 UI 里最常用的字体，每一处文字都会去加载一个体积大得多的中文 TTC。这不是参数没调对，而是**方案本身不可接受**。

**已回滚**（两层注册表都恢复了）：

```
# HKLM\...\FontSubstitutes
"Arial"="Arial Unicode MS"     # 恢复原值
"simkai"=-                      # 删除
"KaiTi"=-                       # 删除
"楷体"=-                        # 删除

# HKCU\Software\Wine\Fonts\Replacements
"Arial"="Arial Unicode MS"     # 恢复第二批的原值
```

回滚后 `system.reg` 与 `user.reg` 均与实验前一致，**公告牌仍是方块，但游戏恢复稳定**。

---

## 如果以后还想继续这条路

只有两个方向（都不建议再轻易动）：

1. **只改粗体路径**，不碰全局 `Arial`——但 `FontSubstitutes` 不支持按字重分别映射，需要从字体文件层面伪造一个"名字叫 Arial Bold、内容是中文"的字体；
2. **换回汉化 DLL 路线**（已试，卡死，见文末附录）。

---

## 附：汉化 DLL 路线（已试，❌ 卡死）

`gtasa_cn.3dm`（2,686,173 B）是个 D3D9 字体钩子（文件头 `MZ` = PE32 DLL），用 GDI 的 `CreateFontIndirectA` + `CreateCompatibleBitmap` 离屏绘制，字体指定为 `SimHei`。理论上复制成 `scripts/gtasa_cn.asi` 就能被 ASI Loader（`vorbisFile.dll`）加载。

**结果：游戏卡死。** `samp.exe` 退出，`gta_sa.exe` 僵住。三个冲突源：

1. `d3dmetal` 后端 + 自建 `d3d9.dll` 代理——钩子面对的不是原生 D3D9
2. 窗口化插件 `III.VC.SA.WindowedMode.asi` **也钩 D3D9**，两个钩子叠加
3. 2006 年的 32 位 PE，当年的 D3D9 行为和现在差异很大

**已回滚**，`scripts/` 只剩窗口化插件。

> 补充：整合包的中文其实靠 `gtasa_cn.exe` 把 `gtasa_cn.3dm` 注入 `gta_sa.exe`。但启动链路是 `samp.exe → gta_sa.exe`，**绕过了汉化启动器**，所以汉化 DLL 从未被加载。
> `models/fonts.txd` 是原版（524,584 B，2005-01-21），**没有汉字字形**，且 GTA 位图字体是单字节索引，换 txd 也处理不了双字节汉字——**不要动它**。

---

## 附：各 TTC 字重数据（实测）

| 家族 | 可用字重（OS/2 usWeightClass） |
|---|---|
| `宋体-简` | 300 / 400 / 700 / 900 |
| `简宋` | 400 / 700 |
| `苹方-简` | 100 / 200 / 300 / 400 / 500 / 600 |
| `楷体-简` | 400 / 400 / 400 |
| `黑体-简` | 400 |
| `圆体-简` | 400 |
| `兰亭黑-简` | 400 |

---

## 回滚备份清单

| 备份文件 | 对应阶段 |
|---|---|
| `user.reg.bak-20261101-232340` | "什么都没有"（第一批之前） |
| `user.reg.bak-20261101-232756` | 第一批已加、第二批未加 |
| `user.reg.bak-20261101-235111` | 改 `Replacements\Arial` → 苹方-简 前 |
| `system.reg.bak-20261102-000312` | 改 `FontSubstitutes\Arial` → 苹方-简 前 |
| `system.reg.bak-20261102-001138` | 改 `FontSubstitutes\Arial` → 宋体-简 前 |
| `system.reg.bak-20261102-002032` | 最终回滚前 |
