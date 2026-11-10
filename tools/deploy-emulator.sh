#!/bin/bash
#
# 模拟器部署脚本：一键完成「构建 → 体检 hdc 通道 → 安装 → 启动」
#
# 【为什么需要这个脚本】
# DevEco 报「推送超时」时，**通常与代码无关**：DevEco 安装应用的第一步是把 HAP
# 通过 hdc 推送到设备，若主机侧 hdc server 的「文件传输会话」卡死，
# `hdc file send` 会无限挂起（连 5 字节的小文件也推不动），
# 而 `hdc shell` 仍然正常 —— 这种「命令通、数据不通」的现象极易被误判成应用问题。
#
# 本脚本的体检环节就是区分这两种情况：
#   - 命令通道 + 文件通道都正常 → 大概率是应用问题，继续排查代码/签名
#   - 命令通、文件通道挂死     → 环境问题，重启 hdc server 即可恢复
#
# 用法：
#   tools/deploy-emulator.sh              # 体检 + 安装 + 启动（不重新构建）
#   tools/deploy-emulator.sh --build      # 先构建再安装
#   tools/deploy-emulator.sh --health     # 只做通道体检，不安装
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
HDC="$(find "$SDK_HOME" -path '*/toolchains/hdc' -type f 2>/dev/null | head -1)"
HAP="$PROJECT_DIR/entry/build/default/outputs/default/entry-default-signed.hap"
BUNDLE="cn.ccn.music"
ABILITY="EntryAbility"

DO_BUILD=0
HEALTH_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --build) DO_BUILD=1 ;;
    --health) HEALTH_ONLY=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
  esac
done

say()  { printf '\033[1;36m[deploy]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m  ✗\033[0m %s\n' "$*"; exit 1; }

# 带超时的执行（macOS 自带没有 timeout，用 perl 的 alarm 兜）
run_with_timeout() {
  local secs="$1"; shift
  perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
}

[ -n "$HDC" ] || die "找不到 hdc（SDK_HOME=$SDK_HOME）"

# ---------------------------------------------------------------- 1. 设备在线
say "检查设备连接…"
TARGETS="$(run_with_timeout 15 "$HDC" list targets 2>/dev/null | head -3)"
if ! echo "$TARGETS" | grep -qE '^[0-9a-zA-Z].*:'; then
  warn "没有已连接的设备，尝试连接本机模拟器 127.0.0.1:5555"
  run_with_timeout 15 "$HDC" tconn 127.0.0.1:5555 >/dev/null 2>&1
  for _ in $(seq 1 15); do
    TARGETS="$(run_with_timeout 10 "$HDC" list targets 2>/dev/null | head -3)"
    echo "$TARGETS" | grep -qE '^[0-9a-zA-Z].*:' && break
    sleep 1
  done
fi
echo "$TARGETS" | grep -qE '^[0-9a-zA-Z].*:' || die "设备未连接（$TARGETS）。请先在 DevEco 的 Device Manager 启动模拟器。"
ok "设备：$(echo "$TARGETS" | head -1)"

# ---------------------------------------------------------------- 2. 通道体检
PROBE_LOCAL="$(mktemp)"
echo "hdc-probe" > "$PROBE_LOCAL"

probe_cmd_channel() {
  run_with_timeout 12 "$HDC" shell "echo probe_ok" 2>/dev/null | grep -q probe_ok
}

probe_file_channel() {
  run_with_timeout 15 "$HDC" file send "$PROBE_LOCAL" /data/local/tmp/hdc_probe.txt >/dev/null 2>&1
}

restart_hdc_server() {
  say "重启 hdc server（主机侧文件传输会话卡死时的标准修复动作）…"
  run_with_timeout 15 "$HDC" kill >/dev/null 2>&1
  sleep 2
  # 模拟器通常会自动回连；最多等 30s
  for _ in $(seq 1 30); do
    if run_with_timeout 10 "$HDC" list targets 2>/dev/null | grep -qE '^[0-9a-zA-Z].*:'; then
      break
    fi
    sleep 1
  done
  run_with_timeout 15 "$HDC" tconn 127.0.0.1:5555 >/dev/null 2>&1
  sleep 1
}

say "体检 hdc 通道…"
if ! probe_cmd_channel; then
  die "hdc shell 命令通道也不通 —— 模拟器本身可能已挂死，请在 Device Manager 里重启模拟器"
fi
ok "命令通道正常"

if probe_file_channel; then
  ok "文件传输通道正常"
else
  warn "文件传输通道挂死（这正是 DevEco「推送超时」的成因，与应用代码无关）"
  restart_hdc_server
  probe_cmd_channel || die "重启 hdc server 后命令通道仍不通，请重启模拟器"
  probe_file_channel || die "重启 hdc server 后文件通道仍不通，请重启模拟器（Device Manager → 停止 → 启动）"
  ok "重启 hdc server 后文件传输通道已恢复"
fi
rm -f "$PROBE_LOCAL"

if [ "$HEALTH_ONLY" = "1" ]; then
  say "体检完成（--health，未安装）"
  exit 0
fi

# ---------------------------------------------------------------- 3. 构建
if [ "$DO_BUILD" = "1" ]; then
  say "构建 HAP…"
  NODE="$SDK_HOME/../tools/node/bin/node"
  [ -x "$NODE" ] || NODE="$(command -v node || true)"
  [ -n "$NODE" ] || die "找不到 node"
  ( cd "$PROJECT_DIR" && DEVECO_SDK_HOME="$SDK_HOME" "$NODE" \
      "$SDK_HOME/../tools/hvigor/bin/hvigorw.js" \
      --mode module -p product=default assembleHap --parallel --incremental --no-daemon ) \
    | grep -E 'ERROR|BUILD SUCCESS|BUILD FAILED'
  ok "构建完成"
fi

[ -f "$HAP" ] || die "找不到 HAP：$HAP（先跑一次 --build）"

# ---------------------------------------------------------------- 4. 安装
say "安装到设备…"
INSTALL_OUT="$(run_with_timeout 120 "$HDC" install -r "$HAP" 2>&1)"
echo "$INSTALL_OUT" | tail -3
echo "$INSTALL_OUT" | grep -q 'install bundle successfully' || die "安装失败"
ok "安装成功"

# ---------------------------------------------------------------- 5. 启动
say "启动应用…"
START_OUT="$(run_with_timeout 60 "$HDC" shell "aa start -a $ABILITY -b $BUNDLE" 2>&1)"
echo "$START_OUT" | tail -2
echo "$START_OUT" | grep -q 'start ability successfully' || die "启动失败"
ok "启动成功（${BUNDLE}/${ABILITY}）"

say "完成。查看日志：$HDC shell hilog | grep $BUNDLE"
