# Linux 部署

适用于 x86_64 Debian 10+、Ubuntu 20.04+。DST 专用服务器使用原生 Linux ELF，
不需要 Proton 或 Steam Linux Runtime。

只使用 GitHub Release 中的 `linux_Mod.zip`。不要在游戏服务器上运行
`build_linux_compatible.sh`，也不要单独替换 `libInjector.so`。

## 安装

把 `linux_Mod.zip` 上传到服务器后解压到任意目录：

```bash
tmp_dir="$(mktemp -d)"
unzip -q /root/linux_Mod.zip -d "$tmp_dir"
find "$tmp_dir" -type f -name install_dst_luajit.sh \
  -exec bash {} \; -quit
rm -rf "$tmp_dir"
```

安装器会自动完成三件事：

1. 找到 DST 的 `bin64`。
2. 把完整 Mod 安装到 `mods/DontStarveLuaJIT2`。
3. 安装 Linux 运行库并生成同名启动器。

已经解压但不知道放在哪里时，可以直接全盘查找并执行：

```bash
find / -type f -name install_dst_luajit.sh \
  -exec bash {} \; -quit 2>/dev/null
```

找不到游戏时显式指定目录：

```bash
bash install_dst_luajit.sh \
  --bin-dir /root/dst-dedicated-server/bin64
```

成功时最后会显示：

```text
[INFO] Installation completed successfully (1 launcher(s)).
```

SteamCMD 执行 `app_update 343050 validate` 后会恢复官方可执行文件。每次更新 DST
后重新运行一次安装器即可。

## dst-admin-go

面板只需要保持标准配置：

| 配置 | 值 |
| --- | --- |
| DST 安装目录 / `force_install_dir` | `/root/dst-dedicated-server` |
| 位数 / bin | `64` |
| 启动文件 | `dontstarve_dedicated_server_nullrenderer_x64` |

不要把路径填到 `bin64`，不要选择 `bin=100`，也不要给面板进程配置
`LD_PRELOAD`。安装器生成的启动器会接收面板原有的 `-cluster`、`-shard`
等参数，面板命令无需修改。

默认情况下不需要在 Master、Caves 的 `modoverrides.lua` 中手动启用
`DontStarveLuaJIT2`，但服务器上必须保留安装器复制的完整 Mod 目录。

## 裸机启动

首次排错建议前台运行：

```bash
cd /root/dst-dedicated-server/bin64
./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Master
```

正常后使用 `screen`：

```bash
cd /root/dst-dedicated-server/bin64
screen -L -Logfile /root/dst-master-screen.log \
  -dmS DST_MyDediServer_Master \
  ./dontstarve_dedicated_server_nullrenderer_x64 \
  -console -cluster MyDediServer -shard Master
```

Caves 只需把 `Master` 改成 `Caves`，并使用不同的 screen 名称和日志文件。

## 验证

```bash
cd /root/dst-dedicated-server/bin64
head -n 2 dontstarve_dedicated_server_nullrenderer_x64
file dontstarve_dedicated_server_nullrenderer_x64_1
screen -ls
pgrep -a -f '[d]ontstarve_dedicated_server_nullrenderer_x64_1'
tail -n 100 DontStarveInjector_server*.log
```

正确结果：标准文件名是带 `# DontStarveLuaJIT launcher` 标记的 Bash 启动器，
`_1` 文件是官方 ELF。游戏控制台执行 `print(jit)` 应返回一个 table。

启动后立即退出时，先看：

- `bin64/DontStarveInjector_server*.log`
- `~/.klei/DoNotStarveTogether/<世界>/<分片>/server_log.txt`
- screen 的 `-Logfile`

出现 `libInjector.so is missing` 说明执行了源码或旧 Workshop 中的安装器，
请重新下载最新 `linux_Mod.zip`。出现 `GLIBC_* not found` 时不要替换系统 libc，
应改用当前 Debian 兼容 Release。
