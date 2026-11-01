# 附录 G：第二次复现——静默闪退（2026-11-01 22:21）

> 原 README 附录 G · 拆分于 2026-11-01 · [← 返回正文](../README.md)

## G.1 时间线

```
[22:21:15] *** 0.3.7-R3 [46]SASYH 进服!
[22:21:23] [38]凤凰于飞: @7 把港岛妹妹提一下
[22:21:34] Audio stream: http://www.zycdjz1.com/b/new.mp3
[22:21:34] This server is using Headless Driver by Loki
[22:21:34] [新]祥云小镇 184地盘信息: ...
[22:21:35] Audio stream: https://link.hhtjim.com/163/1478438260.mp3   ← 最后一行
（进程直接消失，无对话框）
```

## G.2 和第一次的区别

| 项目 | 21:47 那次 | 22:21 这次 |
| --- | --- | --- |
| 表现 | 画面卡死，进程一直活着 | **进程直接退出（闪退）** |
| 崩溃对话框 | 无 | 无 |
| `DiagnosticReports` | 无条目 | 无条目 |
| 触发点 | `Audio stream:` 之后 | `Audio stream:` 之后（且是**第二条**，HTTPS 链接） |

## G.3 这条信息排除了什么

- 静默退出说明**没有走到 Wine 的未处理异常处理**——真走到那一步会弹出 `Unhandled exception at 0x...`（`0xC0000005`）的对话框。
- 因此**基本可以排除**附录 E 那个路牌空指针：补丁即使失效，失效形态也一定是弹框，而不是无声退出。
- 两次事故都停在 `Audio stream:` 之后，触发点高度集中，优先怀疑 `bass.dll` 拉流这一层（尤其是 HTTPS 流 + 本机代理）。

## G.4 下次抓回溯

崩溃时磁盘上什么都没留下，所以要用仓库根目录的 `带日志启动.command`：

```sh
# 双击即可。它做三件事：
# 1. 设 LC_ALL=zh_CN.UTF-8（否则 samp.exe 找不到中文路径的主程序）
# 2. --workdir 'C:\GTA'（否则 cwd 不对，同样找不到主程序）
# 3. 把 Wine 的 stderr 同时写到终端和 ~/samp-debug-<时间>.log
```

闪退时终端里如果出现 `Unhandled page fault` 或 `wine: ...` 回溯，那就是我们要的地址。
