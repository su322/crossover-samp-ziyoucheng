# 附录 A–C：d3d9 代理（原理 / 源码 / 编译）

> 原 README 附录 A / B / C · 拆分于 2026-11-01 · [← 返回正文](../README.md)

## A. d3d9 代理原理

1. 游戏加载同目录的 `d3d9.dll`（需要 `d3d9=native,builtin` 覆盖）。
2. 代理在 `DllMain` 中不做任何渲染工作，只把 `Direct3DCreate9` / `Direct3DCreate9Ex` 转发给 `C:\windows\system32\d3d9.dll`。
3. 拿到真正的 `IDirect3D9` 对象后，复制一份虚函数表，替换其中两个函数：
   - `GetAdapterModeCount`：返回值 +1；
   - `EnumAdapterModes`：多出来的那一项返回 `800×600`、`RefreshRate=0`、格式为请求的 32 位格式。
4. 游戏因此能在模式列表里找到 `800x600x32`，正常进入。
5. 除这两个方法外，其余 D3D9 调用全部走原实现，不影响渲染。

## B. `d3d9proxy.c`（最终无日志版）

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

## C. 编译方法

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
