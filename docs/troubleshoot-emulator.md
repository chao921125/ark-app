# 排障：本地运行到模拟器报「推送超时」

> 记录一次真实故障的定位与修复过程。**结论先说：这个问题与应用代码无关。**

---

## 一、症状

在 DevEco Studio 里点 Run 部署到本地模拟器：

- 应用装不上，IDE 报 **「推送超时」**
- 有时表现为「装上了但打不开」

---

## 二、根因

DevEco 安装应用的第一步，是把 HAP 通过 **hdc 的文件传输通道**推送到设备。
当**主机侧 hdc server 的文件传输会话卡死**时，这一步会无限挂起，最终超时。

关键特征（本次故障的实测表现）：

| 操作 | 结果 |
|---|---|
| `hdc shell "echo hi"` | ✅ 正常返回 |
| `hdc shell "cat > file" < 输入` | ❌ 无限挂起 |
| `hdc file send 5字节文件` | ❌ 无限挂起 |
| `hdc file recv` | ❌ 无限挂起 |

也就是说：**命令通道通、数据通道不通**。
因为 DevEco 的报错文案是「推送超时」，很容易被误判成应用/签名/包体问题。

排查过程中**已排除**的可能：

| 假设 | 排除依据 |
|---|---|
| 签名材料缺失 | `~/.ohos/config/` 下 `.cer` / `.p7b` / `.p12` 三个文件均在 |
| hdc 版本不匹配 | 主机两个 hdc（SDK 内 + `~/Library/OpenHarmony/Sdk/26.0.0/`）均为 `3.2.0f` |
| 设备侧守护进程挂了 | 设备上 `hdcd` 进程存在（PID 990） |
| 磁盘空间不足 | `/data` 剩余 3.9G；根分区剩 438M（88% 已用，但装 1.7M 的包绰绰有余） |
| API 版本不匹配 | 模拟器 API 26，应用 targetSdkVersion 26.0.0、compatibleSdkVersion 6.0.0(20)，匹配 |
| 包管理服务异常 | `bm dump -a` 正常列出全部应用，`bm` 服务存活 |
| 应用本身崩溃 | 安装启动后初始化序列完整跑通，无 FATAL / JS 错误 |

---

## 三、修复

重启**主机侧** hdc server 即可，无需重启模拟器：

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc

"$HDC" kill          # 停掉卡死的 hdc server
sleep 2
"$HDC" list targets  # 模拟器会自动回连，等它出现 127.0.0.1:5555
```

回连后立即验证：

```bash
"$HDC" file send 本地文件 /data/local/tmp/t.txt
# → FileTransfer finish, Size:..., time:20ms
```

实测：重启后 1.7MB 的 HAP 推送耗时 20ms，随后 `hdc install` 报
`install bundle successfully`，应用正常启动。

> 若模拟器迟迟不回连，可尝试 `"$HDC" tconn 127.0.0.1:5555`；
> 仍不通则重启模拟器（Device Manager → 停止 → 启动）。

---

## 四、日常用法：一键部署脚本

以上步骤已固化为 `tools/deploy-emulator.sh`：

```bash
tools/deploy-emulator.sh            # 体检 + 安装 + 启动
tools/deploy-emulator.sh --build    # 先构建再安装
tools/deploy-emulator.sh --health   # 只体检通道，不安装
```

脚本会：

1. 确认设备在线（不在线则尝试 `tconn` 本机模拟器）
2. **分别体检命令通道与文件传输通道**
   - 两个都通 → 直接装
   - 命令通、文件通道挂死 → 判定为本文的环境问题，自动重启 hdc server 并复检
   - 命令通道也不通 → 明确提示「请重启模拟器」，而不是让你去查代码
3. 构建（`--build`）→ 安装 → 启动，每步校验返回值

脚本的自动恢复分支已用打桩方式验证过（首次探测强制失败 → 自愈 → 安装启动成功，退出码 0）。

---

## 五、遇到「推送超时」时的排查顺序

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc

# 1) 命令通道通吗？
"$HDC" shell "echo hi"                # 不通 → 模拟器挂了，重启模拟器

# 2) 文件通道通吗？（推 5 字节就够）
echo x > /tmp/p.txt
"$HDC" file send /tmp/p.txt /data/local/tmp/p.txt   # 挂起 → 走第四节重启 hdc server

# 3) 两通道都通却仍推不动 → 看设备侧日志
"$HDC" shell "hilog -x | grep -iE 'bm|install|signature' | tail -30"
```

第 3 步的日志能区分：签名校验失败、profile 过期、API 版本不符等**真正的应用侧问题**。

---

## 六、附带发现

模拟器根分区 `/dev/block/vda` 使用率已达 **88%**（3.4G 用掉 3.0G）。
目前不影响安装，但体积继续增长后会成为新的故障源。
可在 Device Manager 里对模拟器执行「擦除数据」释放空间（会清空模拟器内的应用数据）。
