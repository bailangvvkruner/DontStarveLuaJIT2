# Linux 专用服务器部署

本文适用于 x86_64 Debian 10+、Ubuntu 20.04+，包括两种运行方式：

- 使用 `dst-admin-go` 管理面板启动服务器。
- 不使用面板，直接在裸机上通过前台或 `screen` 启动。

Linux 发布包以 glibc 2.28 为兼容基线。DST 专用服务器使用原生 Linux ELF，
不需要 Proton。Steam Linux Runtime 可以作为额外测试环境，但不是 Debian/Ubuntu
服务器运行的必需组件。

## 重要原则

1. 使用 Release 中的 `linux_Mod.zip`，不要只复制 `libInjector.so`。
2. 必须运行 `Mod/install_linux.sh`。安装器会复制完整运行库、签名文件并生成启动器。
3. 不要把 `LD_PRELOAD` 配到 `dst-admin-go`、`screen` 或 systemd 的面板进程上。
   安装器生成的游戏启动器会只给 DST 游戏进程设置环境变量。
4. SteamCMD 执行 `app_update 343050 validate` 后可能恢复官方 ELF，更新游戏后应重新运行安装器。
5. 安装和启动前备份 `~/.klei/DoNotStarveTogether` 中的存档。

## 安装发布包

以下示例假定：

- DST 安装目录为 `/root/dst-dedicated-server`。
- `linux_Mod.zip` 已上传到 `/root`。

示例沿用常见面板的 root 路径；生产环境更推荐使用独立的服务账号，并把命令中的
路径换成该账号拥有的目录。

```bash
DST_SERVER_DIR=/root/dst-dedicated-server
DST_LUAJIT_RELEASE_DIR="$(mktemp -d /root/dst-luajit-release.XXXXXX)"

unzip -o /root/linux_Mod.zip -d "$DST_LUAJIT_RELEASE_DIR"
mkdir -p "$DST_SERVER_DIR/mods/DontStarveLuaJIT2"
cp -a "$DST_LUAJIT_RELEASE_DIR/Mod/." \
  "$DST_SERVER_DIR/mods/DontStarveLuaJIT2/"
bash "$DST_SERVER_DIR/mods/DontStarveLuaJIT2/install_linux.sh" \
  --bin-dir "$DST_SERVER_DIR/bin64"
```

成功时应看到：

```text
[INFO] Installing Linux files into: /root/dst-dedicated-server/bin64
[INFO] Installation completed successfully (1 launcher(s) installed).
```

### 启用本地 Mod

把下面这一项合并到 Master 和 Caves 各自已有的 `modoverrides.lua` 返回表中，
不要覆盖文件里原有的其他 Mod：

```lua
["DontStarveLuaJIT2"] = {
    enabled = true,
    configuration_options = {},
},
```

示例目录名和配置键必须保持一致。如果把 Mod 文件夹改成其他名称，
`modoverrides.lua` 中也要使用相同名称。

检查安装结果：

```bash
cd /root/dst-dedicated-server/bin64
file dontstarve_dedicated_server_nullrenderer_x64 \
     dontstarve_dedicated_server_nullrenderer_x64_1
head -n 2 dontstarve_dedicated_server_nullrenderer_x64
```

正确结果是：

- `dontstarve_dedicated_server_nullrenderer_x64` 是 Bash 脚本，并包含
  `# DontStarveLuaJIT launcher`。
- `dontstarve_dedicated_server_nullrenderer_x64_1` 是原始 ELF 可执行文件。

如果标准文件仍显示为 ELF，说明安装器没有作用于服务器实际使用的 `bin64` 目录。

## 配合 dst-admin-go

`dst-admin-go` 在 Linux 下会进入 `force_install_dir/bin64`，然后执行标准文件名：

```text
./dontstarve_dedicated_server_nullrenderer_x64
```

因此不需要修改面板源码或启动命令。安装器生成的同名启动器会接收面板原有的
`-cluster`、`-shard` 等参数，再执行 `_1` 原始 ELF。

### 面板配置

以宿主机部署为例：

| 配置项 | 示例值 | 说明 |
| --- | --- | --- |
| SteamCMD 路径 | `/root/steamcmd` | 目录内应有 `steamcmd.sh` 或 `steamcmd` |
| 饥荒服务器安装路径 | `/root/dst-dedicated-server` | 对应 `force_install_dir`，不要填到 `bin64` |
| 位数 / bin | `64` | 必须选择 64 位 |
| beta | `0` | 使用正式服；测试分支按面板实际目录安装 |

不要选择 `bin=100`。当前 `dst-admin-go` 会在该模式下执行
`dontstarve_dedicated_server_nullrenderer_x64_luajit`，而本项目安装器使用的是
兼容 SteamCMD 和面板默认流程的标准文件名。

安装完成后不需要重启面板，直接在房间页面启动即可。面板实际执行的命令应类似：

```text
cd /root/dst-dedicated-server/bin64 ; screen -d -m \
  -S "DST_<房间>_<分片>" \
  ./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Master
```

检查是否真正启动：

```bash
screen -ls
pgrep -a -f '[d]ontstarve_dedicated_server_nullrenderer_x64_1'
tail -n 100 \
  /root/.klei/DoNotStarveTogether/MyDediServer/Master/server_log.txt
```

`screen -r dst` 通常连接的是面板自身，不是游戏。游戏会话名称以面板日志中的
`DST_...` 为准。HTTP 200 只表示面板接受了启动请求；如果游戏立即崩溃，screen
会话仍会消失，因此还要检查进程和日志。

### 面板运行在 Docker 中

安装必须发生在面板实际启动游戏的同一个文件系统中。只修改宿主机上未挂载进容器的
目录不会生效。

1. 将 DST 目录和解压后的 `Mod` 目录挂载到容器。
2. 在容器内把 `Mod` 本体复制到游戏的 `mods/DontStarveLuaJIT2`。
3. 对 `/app/dst-dedicated-server/bin64` 运行安装器。
4. 确认面板的 `force_install_dir` 也是 `/app/dst-dedicated-server`。

示例命令中的容器名和挂载路径需要替换为实际值：

```bash
docker exec -it dst-admin-go bash -lc \
  'mkdir -p /app/dst-dedicated-server/mods/DontStarveLuaJIT2 && \
   cp -a /mnt/dst-luajit/Mod/. \
     /app/dst-dedicated-server/mods/DontStarveLuaJIT2/ && \
   bash /app/dst-dedicated-server/mods/DontStarveLuaJIT2/install_linux.sh \
    --bin-dir /app/dst-dedicated-server/bin64'
```

容器更新或重建后，如果 DST 目录没有持久化，必须重新安装。

### 面板更新游戏后的顺序

```text
停止所有分片
    -> SteamCMD 更新或 validate
    -> 如果升级 LuaJIT，更新游戏 mods 中的 Mod 本体
    -> 重新运行 install_linux.sh
    -> 确认标准文件是 Bash 启动器
    -> 从面板启动所有分片
```

## 裸机运行

### 1. 安装 DST 专用服务器

如果服务器尚未安装，可使用 SteamCMD 匿名下载 App 343050。先按
[Valve SteamCMD 文档](https://developer.valvesoftware.com/wiki/SteamCMD)中的说明安装系统依赖，
然后执行：

```bash
apt-get update
apt-get install -y ca-certificates curl tar unzip screen
mkdir -p /root/steamcmd /root/dst-dedicated-server
cd /root/steamcmd
curl -fsSL \
  https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
  -o steamcmd_linux.tar.gz
tar -xzf steamcmd_linux.tar.gz
./steamcmd.sh \
  +force_install_dir /root/dst-dedicated-server \
  +login anonymous \
  +app_update 343050 validate \
  +quit
```

然后按本文前面的步骤安装 `linux_Mod.zip`。

### 2. 准备存档

默认存档目录是：

```text
/root/.klei/DoNotStarveTogether/MyDediServer
```

其中至少需要 `cluster.ini`、`cluster_token.txt` 和 `Master/server.ini`。
洞穴分片还需要 `Caves/server.ini`。如果不是以 root 启动，应把 `/root` 换成实际
运行用户的家目录，并确保安装文件、存档和日志都属于同一个运行用户。面板配置了
`persistent_storage_root` 或 `conf_dir` 时，应以对应的实际目录为准。

防火墙需要放行各分片 `server.ini` 中配置的游戏和 Steam UDP 端口。分片间使用的
`master_port` 如果绑定在 `127.0.0.1`，无需暴露到公网。

### 3. 前台启动

前台启动最适合首次排错，因为退出原因会直接显示：

```bash
cd /root/dst-dedicated-server/bin64
./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Master
```

不要直接执行 `_1`，否则会绕过 Injector 启动器。

### 4. screen 后台启动

Master：

```bash
cd /root/dst-dedicated-server/bin64
screen -L -Logfile /root/dst-master-screen.log \
  -dmS DST_MyDediServer_Master \
  ./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Master
```

Caves：

```bash
cd /root/dst-dedicated-server/bin64
screen -L -Logfile /root/dst-caves-screen.log \
  -dmS DST_MyDediServer_Caves \
  ./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Caves
```

查看或进入会话：

```bash
screen -ls
screen -r DST_MyDediServer_Master
```

在 DST 控制台输入 `c_shutdown(true)` 可保存并关闭当前分片。按 `Ctrl+A`，再按 `D`
只会脱离 screen，不会关闭服务器。

## 验证 LuaJIT

进入游戏控制台或对应 screen 会话后执行：

```lua
print(jit)
```

返回类似下面的 table 表示 LuaJIT 已启用：

```text
table: 0x7f0092e83b68
```

同时检查：

```bash
screen -ls
pgrep -a -f '[d]ontstarve_dedicated_server_nullrenderer_x64_1'
tail -n 100 /root/dst-dedicated-server/bin64/DontStarveInjector_server*.log
```

## 常见问题

### `libInjector.so is missing`

运行的是未构建的源码目录，或发布包没有完整解压。请使用 GitHub Release 中的
`linux_Mod.zip`；源码构建则先执行 Linux install target。

### 点击启动后 screen 会话立即消失

用本文的前台命令运行一次，或为 screen 添加 `-L -Logfile`。重点查看：

- `bin64/DontStarveInjector_server*.log`
- `~/.klei/DoNotStarveTogether/<房间>/<分片>/server_log.txt`
- screen 的 `-Logfile` 文件

### `Cannot load Lua module liblua51.so`

确认使用最新 Linux Release，并重新运行完整安装器。不要只替换
`lib64/libInjector.so`，因为签名文件和其他 Lua 运行库也必须来自同一次构建。

### `GLIBC_* not found` 或 `GLIBCXX_* not found`

使用以 glibc 2.28 为基线的 Linux Release。不要手动替换 Debian/Ubuntu 的 libc。

### 面板启动的目录不对

检查面板 `force_install_dir`，并在该目录下确认：

```bash
DST_PANEL_SERVER_DIR=/root/dst-dedicated-server
file "$DST_PANEL_SERVER_DIR/bin64/dontstarve_dedicated_server_nullrenderer_x64"
```

Docker 部署还要在容器内执行同一检查。

### 权限错误

运行面板或游戏的用户需要读取和执行 `bin64` 文件，并能写入存档及日志目录。
应修正目录所有者，不建议使用 `chmod -R 777`。

## 卸载或回滚

先停止所有分片并备份存档，然后在 `bin64` 中恢复 `_1` 原始 ELF：

```bash
cd /root/dst-dedicated-server/bin64
mv dontstarve_dedicated_server_nullrenderer_x64 \
   dontstarve_dedicated_server_nullrenderer_x64.luajit-wrapper
mv dontstarve_dedicated_server_nullrenderer_x64_1 \
   dontstarve_dedicated_server_nullrenderer_x64
```

需要重新启用时，再运行 `install_linux.sh`。
