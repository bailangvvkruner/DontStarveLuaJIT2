[English](README_EN.md) | [下载 Release](../../releases) | [构建状态](../../actions/workflows/release.yaml)

# DontStarveLuaJIT

	Don't Starve LuaJIT 优化补丁

  QQ群: 348368954

## 快速导航

- [选择发布包](#选择发布包)
- [Linux 专用服务器快速安装](#linux-专用服务器快速安装)
- [配合 dst-admin-go](#配合-dst-admin-go)
- [裸机后台运行](#裸机后台运行)
- [常见问题](#常见问题)
- [云编译与发布](#云编译与发布)

## 注意

请务必备份您的存档，因为我们无法保证插件不会导致存档损坏！
使用专用服务器开服需要注意，设置中`服务器禁用luajit`选项是无效的，你应该直接卸载luajit再启动服务器

## 存档路径

- Windows: `~/Documents/Klei/DoNotStarveTogether`
- macOS: `~/Documents/Klei/DoNotStarveTogether`
- Linux: `~/.klei/DoNotStarveTogether`
- 专用服务器传入 `-persistent_storage_root APP:Klei/` 时，Windows 和 macOS 会展开到 `~/Documents/Klei`，Linux 会展开到 `~/.klei`

# 计划

## Don't Starve Together

- [x] windows x64
- [x] ~~windows x86~~
- [x] linux x64
- [x] ~~linux x86~~
- [x] macos
- [ ] andorid
- [ ] switch

## Don't Starve

- [ ] windows x64
- [ ] ~~windows x86~~
- [ ] linux
- [ ] macos
- [ ] andorid
- [ ] switch

## 完全兼容加密mod

功能描述:

完全解决加密mod不兼容luajit的问题,除非代码依赖了lua语言的未定义行为

赞助:
 ██████████████████░░ (436/500)

## 加密插件

功能描述:

不损失任何性能地加密mod,加密后仅能在luajit上运行

## 多线程并发GC插件

功能描述:

极大减少stopworld时间,减少逻辑帧过长导致的卡顿

目前看服务器进程效果显著

赞助:
██████████████████████ (500/500)

## Nintendo switch插件

功能描述:

支持pc玩家跨平台游戏.(ps: 🫓)

# 下载、安装与运行

## 选择发布包

不要下载 GitHub 自动生成的 `Source code.zip` 代替成品包。请进入
[Releases](../../releases)，按运行环境下载：

| 文件 | 适用环境 | 说明 |
| --- | --- | --- |
| `windows_Mod.zip` | Windows x64 | Windows 客户端和专用服务器 |
| `linux_Mod.zip` | Ubuntu 24.04 x64 | Ubuntu 24.04 原生构建 |
| `debian_Mod.zip` | Debian/Ubuntu x64 | 推荐用于 Linux 专用服务器；要求 glibc 2.28 或更高，静态链接 libstdc++ |
| `macos_Mod.zip` | macOS x64 | Intel x64 构建 |

`debian_Mod.zip` 不是只给 Debian 使用。Ubuntu 服务器如果不确定系统运行库
版本，也可以优先选择这个包。两个 Linux ZIP 的 CI 包体上限均为 12 MiB。

发布包解压后的顶层目录是 `Mod/`，里面同时包含：

- Lua Mod 本体：`modinfo.lua`、`modmain.lua`、`scripts/`；
- Linux 注入库：`bin64/linux/lib64/libInjector.so` 和四套 Lua VM；
- Linux 安装器：`install_linux.sh`。

不能只复制 `libInjector.so`。Mod 本体、签名文件和其余动态库必须使用同一个
Release 中的版本，不能混用旧包。

## Linux 专用服务器快速安装

下面以游戏目录 `/root/dst-dedicated-server` 为例。其他路径只需要修改
`DST_ROOT`。

### 1. 检查系统并停止服务器

```bash
uname -m
ldd --version | head -n 1

pgrep -af 'dontstarve_(steam|dedicated_server)'
```

目前仅提供 `x86_64`。安装前请在面板中停止所有世界，确认 Master 和 Caves
进程都已退出，并备份存档。

### 2. 解压完整 Mod

把下载好的 `debian_Mod.zip` 上传到服务器，然后执行：

```bash
DST_ROOT=/root/dst-dedicated-server
MOD_DIR="$DST_ROOT/mods/DontStarveLuaJIT2"

apt-get update
apt-get install -y file screen unzip
DST_LUAJIT_TMP="$(mktemp -d)"
mkdir -p "$MOD_DIR"
unzip -o /root/debian_Mod.zip -d "$DST_LUAJIT_TMP"
cp -a "$DST_LUAJIT_TMP/Mod/." "$MOD_DIR/"

test -f "$MOD_DIR/modmain.lua"
test -f "$MOD_DIR/bin64/linux/lib64/libInjector.so"
```

如果下载的是 `linux_Mod.zip`，只需替换上面的 ZIP 文件名。

### 3. 执行安装器

必须在 Mod 根目录执行：

```bash
cd /root/dst-dedicated-server/mods/DontStarveLuaJIT2
chmod +x install_linux.sh
bash ./install_linux.sh
```

当前安装器不接受 `--bin-dir`。它根据 Mod 所在位置定位游戏 `bin64`：

- 本地 Mod：`<游戏目录>/mods/<模组目录>/install_linux.sh`；
- Steam Workshop：`steamapps/workshop/content/322330/<模组 ID>/install_linux.sh`。

安装器会：

1. 停止仍在运行的 DST 客户端/专服进程；
2. 把 `bin64/linux` 中的完整文件集复制到游戏 `bin64`；
3. 将原始专服程序重命名为
   `dontstarve_dedicated_server_nullrenderer_x64_1`；
4. 在原文件名处创建设置 `LD_LIBRARY_PATH` 和 `LD_PRELOAD` 的启动脚本。

安装后应满足：

```bash
DST_BIN=/root/dst-dedicated-server/bin64

file "$DST_BIN/dontstarve_dedicated_server_nullrenderer_x64"
file "$DST_BIN/dontstarve_dedicated_server_nullrenderer_x64_1"
ls -lh "$DST_BIN/lib64/libInjector.so"
ldd "$DST_BIN/lib64/libInjector.so" | grep 'not found' || true
```

预期结果：不带 `_1` 的文件是 shell 脚本，带 `_1` 的文件是 x86-64 ELF，
并且 `ldd` 没有输出 `not found`。

### 4. 启用 Mod

安装注入器不等于启用 Lua Mod。标准安装需要同时保留整个 Mod 目录，并在
Master 和 Caves 的 `modoverrides.lua` 中启用它。

使用 Release 中的本地目录时：

```lua
return {
    ["DontStarveLuaJIT2"] = {
        enabled = true,
        configuration_options = {
            EnabledJIT = true,
            AlwaysEnableMod = true,
        },
    },
}
```

如果文件里已经配置了其他 Mod，只合并上面的条目，不要覆盖原有 `return`
表。

使用 Steam Workshop 版本时，在 `dedicated_server_mods_setup.lua` 中加入：

```lua
ServerModSetup("3444078585")
```

对应的 `modoverrides.lua` 键名使用 `workshop-3444078585`。每个 shard 都有
自己的 `modoverrides.lua`，例如：

```text
~/.klei/DoNotStarveTogether/MyDediServer/Master/modoverrides.lua
~/.klei/DoNotStarveTogether/MyDediServer/Caves/modoverrides.lua
```

实际根目录会受到 `-persistent_storage_root` 和运行账号影响。

### 5. 先以前台方式验证

第一次安装后不要直接依赖面板状态。先在 `bin64` 前台启动 Master：

```bash
cd /root/dst-dedicated-server/bin64
./dontstarve_dedicated_server_nullrenderer_x64 \
  -console \
  -cluster MyDediServer \
  -shard Master
```

确认没有动态库错误并进入正常加载流程后，用 `Ctrl+C` 停止，再交给面板或
后台进程管理器启动。验证 Caves 时将 `Master` 改为 `Caves`。

专服控制台执行 `print(jit)`，返回一个 table（例如 `table: 0x...`）表示
LuaJIT 已加载。

## 配合 dst-admin-go

`dst-admin-go` 不需要新增启动参数，也不要把程序路径改成带 `_1` 的文件。
面板仍应启动安装器生成的原文件名：

```text
游戏目录: /root/dst-dedicated-server
工作目录: /root/dst-dedicated-server/bin64
可执行文件: dontstarve_dedicated_server_nullrenderer_x64
```

正常命令形态如下：

```bash
cd /root/dst-dedicated-server/bin64
screen -d -m -S "DST_MyDediServer_Master" \
  ./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Master
```

包装脚本会自动设置 `LD_LIBRARY_PATH=./lib64` 和
`LD_PRELOAD=./lib64/libInjector.so`，面板中不需要重复填写。

面板显示启动成功但看不到窗口时，先列出真实 session 名：

```bash
screen -ls
screen -r DST_MyDediServer_Master
```

不要固定执行 `screen -r dst`；`dst-admin-go` 通常会按世界、集群和 shard
生成不同的 session 名。如果 session 启动后立即消失，请回到上一节以前台
方式运行，终端中的第一条错误通常就是根因。

## 裸机后台运行

不使用面板时，可以直接用 `screen`：

```bash
screen -dmS DST_Master bash -lc '
  cd /root/dst-dedicated-server/bin64 &&
  exec ./dontstarve_dedicated_server_nullrenderer_x64 \
    -console -cluster MyDediServer -shard Master
'
```

查看和停止：

```bash
screen -ls
screen -r DST_Master
```

进入 session 后按 `Ctrl+C` 停止；按 `Ctrl+A`、`D` 退出但保持后台运行。
Master 与 Caves 应使用不同的 session 名。

## Linux 手动安装

只有在 Mod 不位于游戏 `mods/` 或 Workshop 标准目录时才需要手动安装。
以下命令仅处理专用服务器：

```bash
DST_ROOT=/root/dst-dedicated-server
MOD_DIR=/path/to/extracted/Mod
DST_BIN="$DST_ROOT/bin64"

cp -a "$MOD_DIR/bin64/linux/." "$DST_BIN/"
cd "$DST_BIN"

if file dontstarve_dedicated_server_nullrenderer_x64 | grep -q ELF; then
    mv dontstarve_dedicated_server_nullrenderer_x64 \
       dontstarve_dedicated_server_nullrenderer_x64_1
fi

cat > dontstarve_dedicated_server_nullrenderer_x64 <<'EOF'
#!/usr/bin/env bash
export LD_LIBRARY_PATH=./lib64
export LD_PRELOAD=./lib64/libInjector.so
exec ./dontstarve_dedicated_server_nullrenderer_x64_1 "$@"
EOF

chmod +x dontstarve_dedicated_server_nullrenderer_x64
```

即使手动安装注入器，仍须把完整 `Mod/` 放入游戏的 `mods/` 并启用它。

## 常见问题

### `libInjector.so is missing`

通常是下载了源码包、只复制了脚本，或者在错误目录运行。成品包应存在：

```text
Mod/bin64/linux/lib64/libInjector.so
```

请重新下载 `debian_Mod.zip` 或 `linux_Mod.zip`，不要在生产服务器上运行
`tools/build_linux_compatible.sh`。该脚本用于 GitHub Actions/开发机通过 Docker
编译发布物，不是服务器安装命令。

### 面板请求返回 200，但游戏没有进程

`screen -d -m` 即使其中程序立即崩溃，也可能先让面板得到成功返回。执行：

```bash
screen -ls
cd /root/dst-dedicated-server/bin64
./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Master
```

然后检查：

```bash
tail -n 200 DontStarveInjector_server_master.log
tail -n 200 DontStarveInjector_server_caves.log
ldd lib64/libInjector.so | grep 'not found' || true
```

### 出现 `GLIBC_x.y not found` 或 `GLIBCXX_x.y not found`

优先改用 `debian_Mod.zip`。它在 manylinux 2.28 环境构建，CI 会拒绝高于
`GLIBC_2.28` 的符号，并检查不依赖宿主机 `libstdc++.so.6`。glibc 低于 2.28
的发行版不在支持范围内。

### SteamCMD 更新游戏后补丁失效

Steam 更新可能恢复原始可执行文件。停止所有世界后，从 Mod 目录重新执行：

```bash
bash ./install_linux.sh
```

### 加密 Mod 是否可用

默认的 `AutoDetectEncryptedMod` 和 `SlowTailCall` 会为常见加密 Lua Mod 启用
兼容处理。若 Mod 依赖 Lua 未定义行为、固定调用栈深度、私有原生扩展或特定
Lua VM 实现，仍可能不兼容。服务器和需要运行该 Mod 代码的客户端应分别安装
对应平台的补丁。

## 卸载

先停止所有 DST 进程。Linux 专服只需恢复原始入口即可停止注入：

```bash
cd /root/dst-dedicated-server/bin64

if [ -f dontstarve_dedicated_server_nullrenderer_x64_1 ]; then
    rm -f dontstarve_dedicated_server_nullrenderer_x64
    mv dontstarve_dedicated_server_nullrenderer_x64_1 \
       dontstarve_dedicated_server_nullrenderer_x64
fi
```

随后在各 shard 的 `modoverrides.lua` 中禁用 Mod。不要直接清空游戏的整个
`bin64/lib64`，其中可能包含 DST 自己的文件。必要时可用 SteamCMD 校验游戏
文件后重新安装服务端。

Windows 卸载时删除或重命名游戏 `bin64` 中的 `Winmm.dll`；macOS/Linux
客户端恢复安装时重命名为 `_1` 的原始程序。

## Windows 与 macOS

- Windows：将完整 Mod 放入游戏 `mods/`，运行 `install.bat`；手动安装时将
  `bin64/windows` 中的文件复制到游戏 `bin64`。
- macOS：需要允许 `DYLD_INSERT_LIBRARIES` 并重新签名游戏程序；将
  `bin64/osx` 文件复制到应用的 `MacOS` 目录，再用包装脚本设置
  `DYLD_INSERT_LIBRARIES=./libInjector.dylib` 启动原程序。

## 云编译与发布

- 推送 `master`：编译 Windows、Ubuntu、Debian compatible、macOS，并发布
  Preview Release；
- 推送普通功能分支：不会自动触发；请创建 PR 或在 Actions 页面手动运行；
- Pull Request 到 `master`：执行四平台编译验证，但不发布；
- Actions 页面 `Run workflow`：可选择分支手动编译；只有在 `master` 上运行
  才会发布 Preview；
- 推送正式 tag：发布正式 Release。

Debian compatible 构建使用 `tools/build_linux_compatible.sh`，在
manylinux 2.28 容器中完成 strip、ELF ABI 检查和 preload smoke test。该流程
只在构建机运行，游戏服务器只需要安装 Release ZIP。

# MOD作者兼容

## modinfo.lua

在modinfo里面添加兼容性标记

对于没有兼容标记的MOD,将会根据`SlowTailCall`或者`AutoDetectEncryptedMod`选项.

对启发式检测到加密MOD的代码, 自动启用`堆栈兼容性`

```lua
luajit_compatible = true --表示不依赖堆栈深度
--或者
luajit_compatible = {
  dep_tailcall = false --表示不依赖堆栈深度
}
```

## 堆栈深度

一般只有加密mod会严重依赖了堆栈深度, 比如说最常见的使用了

```lua
local target_level = 2
for i =0,255 do
    local info = debug.getinfo(i, 'f')
    if info.func == Target_func then
        assert(i == target_level) -- i变量就是堆栈深度
    end
end
```
# 如何调试游戏：

需要 `vscode` + `lua-debug` 插件

## 不通过 Steam 调试游戏的方法

在游戏目录/bin64 文件夹中创建 `steam_appid.txt` 文件，内容为 `322330`。

## 直接启用游戏调试

### 需要 `steam_appid.txt`

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(Windows) 启动服务器(lua)",
            "type": "lua",
            "request": "launch",
            "luaexe": "${config:steam.game.root}/bin64/dontstarve_steam_x64.exe",
            "program": "",
            "arg": [],
            "env": {
                //"lua_vm_type": "game", // jit|game|5.1
                "enable_lua_debugger": "1"
            },
            "sourceFormat": "string",
            "sourceMaps": [
                [
                    "../mods/workshop-*",
                    "C:/Program Files (x86)/Steam/steamapps/workshop/content/322330/*"
                ],
                [
                    "../mods/workshop-2847908822/*",
                    "${workspaceFolder}/tests/2847908822/*"
                ],
                [   
                    "C:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together/data/scripts/*",
                    "C:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together/dst-scripts/scripts/*"
                ],
                [
                    "scripts/*",
                    "C:/Program Files (x86)/Steam/steamapps/common/Don't Starve Together/dst-scripts/scripts/*"
                ],
                [
                    "GameLuaInjectFramework.lua",
                    "${workspaceFolder}/src/DontStarveInjector/GameLuaInjectFramework.lua"
                ]
            ],
            "cwd": "${config:steam.game.root}/bin64",
            "luaVersion": "lua51"
        },
    ]
}

```

## 传递进程参数 “-enable_lua_debugger”

若通过Steam启动，请在游戏属性 > 启动选项中添加：“ -enable_lua_debugger”

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "address": "127.0.0.1:12306",
            "name": "attach client",
            "request": "attach",
            "stopOnEntry": true,
            "type": "lua",
            "luaVersion": "luajit",
            "sourceMaps": [
                [
                    "../mods/workshop-*",
                    "E:/SteamLibrary/steamapps/workshop/content/322330/*"
                ]
            ]
        },
        {
            "address": "127.0.0.1:12307",
            "name": "attach server",
            "request": "attach",
            "stopOnEntry": true,
            "type": "lua",
            "luaVersion": "luajit",
            "sourceMaps": [
                [
                    "../mods/workshop-*",
                    "E:/SteamLibrary/steamapps/workshop/content/322330/*"
                ]
            ]
        },
        {
            "address": "127.0.0.1:12308",
            "name": "attach server cave",
            "request": "attach",
            "stopOnEntry": true,
            "type": "lua",
            "luaVersion": "luajit",
            "sourceMaps": [
                [
                    "../mods/workshop-*",
                    "E:/SteamLibrary/steamapps/workshop/content/322330/*"
                ]
            ]
        },
         {
            "name": "Launch game",
            "type": "lua",
            "request": "launch",
            "luaVersion": "luajit",
            "cwd": "${config:steam.game.root}/bin64",
            "luaexe": "${config:steam.game.root}/bin64/dontstarve_steam_x64.exe",
            "sourceMaps": [
                [
                    "../mods/workshop-*",
                    "${config:steam.game.modroot}/*"
                ],
                [   "${config:steam.game.root}/data/scripts/*",
                    "${config:steam.game.root}/dst-scripts/scripts/*" //scripts脚本文件夹目录
                ]
            ],
            "program": "",
            "arg": [
                "-enable_lua_debugger"
            ],
            "env": {
                "NOVSDEBUGGER": "1",
                "NOWAITDEBUGGER": "1",
            }
        },
    ], "compounds": [
        {
            "name": "Compound servers",
            "configurations": [
                "attach server",
                "attach server cave"
            ],
            "stopAll": true
        }
    ]
}
```


# 捐赠人列表

如果遗漏了你的捐赠,请联系我

| 姓名 | 金额 | 原因         |模组id|
|------|------|--------------|-----------|
| Dv**ce   | 50RMB| 兼容MOD | [Accomplishments](https://steamcommunity.com/sharedfiles/filedetails/?id=2843097516)|
| a*t   | 20RMB| 无 | (兼容mod) |
| 冰*羊    | 30RMB | 兼容MOD    | [自动崩溃恢复](https://steamcommunity.com/sharedfiles/filedetails/?id=3377689002)|
| 冰*羊    | 30RMB | 兼容MOD    | [性能优化包](https://steamcommunity.com/sharedfiles/filedetails/?id=2847908822)|
| Dv**ce   | 30RMB| 开发TRACY功能 | |
| 18**30   | 20RMB| 无 | (兼容mod) |
| 18**30   | 20RMB| 兼容虚拟机环境 | |
| Dv**ce   | 100RMB| 无 | (兼容mod) |
| 18**30   | 30RMB| 修复BUG | |
| 预*微笑   | 100RMB | MACOS | |
| 储*佛丝   | 50RMB | | |
| 轮回**剑  | 30RMB | (兼容mod) | |
| 大*雄     | 166RMB | (改进加密兼容性)| |
| 星*☆     | 100RMB | | |
| 18**30    | 50RMB| 无 | |
| 33**66    | 30RMB | 辅助安装| |
| 朝*花     | 50RMB | 无| |
| 匿名     | 20RMB | 无| |
| 18**30   | 100RMB| 无 | |
| 朝*花     | 100RMB | 无| |
| LST | 299RMB | 无| |

# 捐赠方式
![weixin_zanshang](https://github.com/user-attachments/assets/9f6485ce-5254-4207-a514-89bd02c332ce)


![微信图片_20250320092648](https://github.com/user-attachments/assets/6c754bc6-6b43-45af-bc41-fa4c502b4b3e)
