# 附录 H：试过 DXVK，不适用（2026-11-01 22:43，已回滚）

> 原 README 附录 H · 拆分于 2026-11-01 · [← 返回正文](../README.md)

## H.1 动机

特效密集场景（自制地图 + 大量半透明物件 + 满屏 TextDraw）帧率不稳，游戏内画质已经全最低（分辨率 `800×600×32`、`VISUAL FX QUALITY = LOW`、`DRAW DISTANCE = 0`、AA 关），说明瓶颈在翻译层而不是画质设置。于是尝试把图形后端从 `d3dmetal` 换成 `dxvk`。

链路确认过是通的：游戏目录的自制 `d3d9.dll` 只拦 `EnumAdapterModes` / `GetAdapterDisplayMode`，其余转发到 `C:\windows\system32\d3d9.dll`，而 `CX_GRAPHICS_BACKEND=dxvk` 替换的正是那个文件——所以换后端确实会生效，不是空转。

## H.2 结果：直接崩溃

```
SA-MP 0.3.7-R3
Exception At Address: 0x00000000
Base: 0x020B0000
EAX=0x00000000  EBX=0x00000016  ECX=0x015CC408  EDX=0x015A0000
ESI=0x015CC408  EDI=0x0000000E  EBP=0x7FFFFFFF  ESP=0x0032FCC8
```

`0x00000000` 表示**跳到空指针执行**，典型是 COM 接口 vtable 里某个方法为 `NULL` 却被调用。和 `0x0053388E` 那个路牌空指针**完全无关**，也和附录 E 的补丁无关——补丁只影响 `CEntity::CreateEffects`，管不到渲染后端。

## H.3 结论

**这个组合跑不通**：自制 `d3d9` 代理 + DXVK + 32 位 D3D9。已把 `CX_GRAPHICS_BACKEND` 改回 `d3dmetal`。

以后再想动后端，先记住这个结果，别再重复试 DXVK；`dxmt` 没试过，但同样的代理链路风险类似。

特效场景的卡顿因此**维持现状**——游戏内已无可调项，后端这条路也堵了。
