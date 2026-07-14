#!/usr/bin/env bash
# Debian 12: 通过 sysctl 永久关闭 / 开启 IPv6（方法一）
# 用法:
#   sudo ./offipv6.sh          # 关闭 IPv6
#   sudo ./offipv6.sh disable  # 关闭 IPv6
#   sudo ./offipv6.sh enable   # 恢复 IPv6
#   sudo ./offipv6.sh status   # 查看状态

set -euo pipefail

SYSCTL_FILE="/etc/sysctl.d/99-disable-ipv6.conf"
ACTION="${1:-disable}"

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "错误: 请使用 root 运行，例如: sudo $0 $*" >&2
    exit 1
  fi
}

write_disable_config() {
  cat > "$SYSCTL_FILE" <<'EOF'
# Disable IPv6 permanently (Debian 12)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
}

write_enable_config() {
  cat > "$SYSCTL_FILE" <<'EOF'
# Enable IPv6 (Debian 12)
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOF
}

apply_sysctl() {
  sysctl -p "$SYSCTL_FILE" >/dev/null
}

show_status() {
  local all_val default_val lo_val
  all_val="$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo N/A)"
  default_val="$(cat /proc/sys/net/ipv6/conf/default/disable_ipv6 2>/dev/null || echo N/A)"
  lo_val="$(cat /proc/sys/net/ipv6/conf/lo/disable_ipv6 2>/dev/null || echo N/A)"

  echo "===== IPv6 状态 ====="
  echo "all:     disable_ipv6 = ${all_val}  (1=已关闭, 0=已开启)"
  echo "default: disable_ipv6 = ${default_val}"
  echo "lo:      disable_ipv6 = ${lo_val}"
  echo

  if [[ -f "$SYSCTL_FILE" ]]; then
    echo "配置文件: $SYSCTL_FILE"
    echo "----------"
    cat "$SYSCTL_FILE"
    echo "----------"
  else
    echo "配置文件: 不存在 ($SYSCTL_FILE)"
  fi
  echo

  echo "当前 inet6 地址:"
  if ip -6 addr show 2>/dev/null | grep -q "inet6"; then
    ip -6 addr show | sed 's/^/  /'
  else
    echo "  (无 inet6 地址，或 IPv6 已关闭)"
  fi
}

disable_ipv6() {
  require_root "$@"
  echo "正在关闭 IPv6..."
  write_disable_config
  apply_sysctl
  echo "已写入并应用: $SYSCTL_FILE"
  echo
  show_status
  echo
  echo "完成: IPv6 已关闭（重启后仍然生效）。"
}

enable_ipv6() {
  require_root "$@"
  echo "正在恢复 IPv6..."
  write_enable_config
  apply_sysctl
  echo "已写入并应用: $SYSCTL_FILE"
  echo
  show_status
  echo
  echo "完成: IPv6 已恢复。"
  echo "提示: 若仍无地址，可重启网络或执行: systemctl restart networking"
  echo "      或对 NetworkManager: nmcli networking off && nmcli networking on"
}

usage() {
  cat <<EOF
用法: sudo $0 [disable|enable|status]

  disable  关闭 IPv6（默认）
  enable   恢复 IPv6
  status   查看当前状态（无需 root）

配置文件: $SYSCTL_FILE
EOF
}

case "$ACTION" in
  disable|off|0)
    disable_ipv6 "$@"
    ;;
  enable|on|1)
    enable_ipv6 "$@"
    ;;
  status|show|check)
    show_status
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "未知参数: $ACTION" >&2
    usage >&2
    exit 1
    ;;
esac
