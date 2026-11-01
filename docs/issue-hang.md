# 附录 F：打补丁后的新现象——进服后卡死（2026-11-01 21:47，待验证）

> 原 README 附录 F · 拆分于 2026-11-01 · [← 返回正文](../README.md)

## F.1 现象

- `21:46:38` 启动 → `21:46:43` 连上 `154.12.58.112:7777` → `21:47:18` 收到服务器欢迎、登录菜单和音频流消息，随后画面卡住。
- 进程 `gta_sa.exe`（PID 43126）一直存活，20 多分钟没有退出，也没有弹出崩溃报告框。
- `~/Library/Logs/DiagnosticReports/` 里没有 `gta_sa.exe` 的崩溃条目；Wine 日志 `samp-run.log` 只有两行 `msync` 启动信息。
- 卡死时窗口已经不可见，`CGWindowList` 里主窗口 `GTA: San Andreas` 的尺寸是 `247×161`、坐标 `x=-263`（明显异常）。

## F.2 为什么可以排除这次补丁

| 证据 | 说明 |
| --- | --- |
| 没有 SEH 异常 | 开着 `+seh` 的 `samp-run.log` 里没有任何异常记录。补丁的失效方式是"空指针解引用"，那会产生 `0xC0000005` 并被记录；这次一条都没有，说明进程根本没有出错，是**被阻塞**了。 |
| 栈平衡已复核正确 | 沿正常路径走到 `0x53395A` 时 `ESP = P+4`（`P` 为 `0x53388C` 处 ESP）；`0x53391F` 的 `add esp,0x48` 一次清掉全部参数。补丁的 `add esp,4` 正好落在同一状态，不会让 ESP 偏移。 |
| 帧内槽位自洽 | `0x53395A` 的 `mov edi,[esp+0x3C]` 取的正是 `0x533BA3` 回写的循环下标槽，`add esp,0x20` 后 `[esp+0x24]` 读到的循环次数也不受影响。 |
| 语义与源码一致 | `gta-reversed` 的 `CEntity::CreateEffects` 在 roadsign 分支开头置 `m_bHasRoadsignText = true`，末尾 `effect->roadsign.m_pAtomic = signAtomic`。补丁的空分支做的是 `m_bHasRoadsignText = false` + `m_pAtomic = NULL`，正好等于"源码本来该有的判空行为"。 |
| 作用范围 | 补丁只在 `CreateRoadsignAtomic` 返回 `NULL` 时改变行为，正常分支逐字节等价于原版。它没有任何阻塞、循环或等待逻辑。 |

结论：这次卡死不是补丁造成的。补丁的目标（不再 `0x0053388E` 闪退）在这次会话里已经达成。

## F.3 卡死时间线与音频流

```
[21:47:18] Audio stream: http://www.zycdjz1.com/b/new.mp3
[21:47:18] ... /HELP ...
[21:47:18] This server is using Headless Driver by Loki
（此后 chatlog 再无输出）
```

服务器在玩家进服时下发了一个音频流地址，客户端随后用 `bass.dll` 去拉这个流，卡死点正好落在这一行之后。

已确认 URL 本身可达（从 macOS 直接请求：`HTTP 200`，`1.1s`，24 KB），所以不是"地址失效"，但**不能排除** BASS 在 Wine 下建流/缓冲时阻塞。

## F.4 排查顺序（从最便宜的开始）

1. **复现**：重启 `samp.exe` 直连 `154.12.58.112:7777`，进服后停一会儿。若每次都卡在同一处，说明是确定性问题。
2. **关掉音频代理**：`sa-mp.cfg` 里把 `audioproxyoff=0` 改成 `1`，再进服。改回 `0` 即可还原。
3. **关 msync**：CrossOver 里打开 `samp` 容器的设置 → 高级，取消 `msync`，再进服。msync 是 Wine 的快速同步机制，偶发卡死时是常见嫌疑。
4. **对照原版**：用 `gta_sa.exe.orig` 覆盖 `gta_sa.exe`，再进服。
   - 原版也卡 → 与补丁无关，回到第 2、3 步继续找。
   - 原版不卡、补丁版卡 → 才需要怀疑补丁，此时把卡死时的 `chatlog.txt` 和窗口状态记下来。
5. 每一步只改一个变量，改完记下 `gta_sa.exe` 的 SHA-256，避免把多个变量混在一起。

## F.5 下次卡死时要留的证据

- `~/Documents/GTA San Andreas User Files/SAMP/chatlog.txt`（时间线，最后一行就是卡死点）。
- `~/Library/Logs/DiagnosticReports/` 里有没有新的 `gta_sa.exe` 条目（有 = 崩溃，没有 = hang）。
- 卡死时窗口是否还在、尺寸是否正常（可用 `screencapture` 截屏）。
- `gta_sa.exe` 当前 SHA-256，确认到底跑的是哪个版本。

## F.6 用命令行启动的坑（本次踩到，别再踩）

排查时在终端里直接拉 `samp.exe`，连续弹出乱码报错框，一度以为是游戏或补丁坏了。实际原因是启动方式：

| 现象 | 原因 | 正确做法 |
| --- | --- | --- |
| 弹「未找到侠盗猎车手:圣安地列斯的主程序 / 请重新选择目录」，且文字是乱码 | 没指定工作目录时，Wine 的 cwd 继承自 shell（例如 `Y:\WorkBuddy AI\...`），`samp.exe` 在当前目录找不到 `gta_sa.exe` | 加 `--workdir 'C:\GTA'` |
| 报错框里的中文全是乱码 | shell 的 `LC_ALL` / `LANG=C` 让 Wine 用了非中文代码页，中文路径和提示都编解码错位 | 不要从 shell 传中文路径参数 |
| 直接跑 `gta_sa.exe -c ...` 秒退 | 缺少 `samp.exe` 的 `samp.dll` 注入 | 必须由 `samp.exe` 拉起 |

验证方法（工作目录对了就能找到主程序）：

```sh
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle samp --workdir 'C:\GTA' \
  --cx-app 'C:\windows\system32\cmd.exe' /c "cd & if exist gta_sa.exe (echo FOUND) else (echo MISSING)"
# 期望输出：C:\GTA / FOUND
```

**结论：日常就用启动台里的 CrossOver 入口，不要用命令行拉。** 那条路径的环境是 CrossOver 配好的，中文路径和代码页都正常。
