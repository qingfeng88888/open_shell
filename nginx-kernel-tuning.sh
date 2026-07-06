#!/bin/bash
# =====================================================================
# Nginx 生产级内核调优脚本
# 来源: nginx.txt「第一道防线：操作系统内核调优」
# 流程: root 检查 -> 备份原始配置 -> 生成回滚脚本 -> 应用调优 -> 验证
# 适用: CentOS 7+ / Ubuntu 18.04+ 等主流 Linux
# =====================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }

# ---------- 0. 前置检查 ----------
if [[ $EUID -ne 0 ]]; then
    log_error "必须以 root 权限运行"; log_info "请使用: sudo $0 $*"; exit 1
fi
[[ -f /etc/sysctl.conf ]] || { log_error "未找到 /etc/sysctl.conf，退出"; exit 1; }

# 解析 --yes 参数，跳过交互确认
ASSUME_YES=false
[[ "${1:-}" == "--yes" ]] && ASSUME_YES=true

# ---------- 1. 备份 ----------
BACKUP_DIR="/root/kernel_tuning_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
log_step "[1/4] 备份原始配置 -> $BACKUP_DIR"
cp -a /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak"
[[ -f /etc/security/limits.conf ]] && cp -a /etc/security/limits.conf "$BACKUP_DIR/limits.conf.bak"
sysctl -a > "$BACKUP_DIR/sysctl_runtime_snapshot.txt" 2>/dev/null || true
ulimit -a > "$BACKUP_DIR/ulimit_snapshot.txt" 2>/dev/null || true
log_info "备份完成"

# 生成回滚脚本
cat > "$BACKUP_DIR/rollback.sh" <<EOF
#!/bin/bash
set -e
[[ \$EUID -ne 0 ]] && { echo "请以 root 运行"; exit 1; }
BD="$BACKUP_DIR"
echo "恢复 sysctl.conf ...";  cp -a "\$BD/sysctl.conf.bak" /etc/sysctl.conf
[[ -f "\$BD/limits.conf.bak" ]] && { echo "恢复 limits.conf ..."; cp -a "\$BD/limits.conf.bak" /etc/security/limits.conf; }
sysctl --system >/dev/null 2>&1 || sysctl -p
echo "回滚完成，请重新登录会话使 limits 生效"
EOF
chmod +x "$BACKUP_DIR/rollback.sh"
log_info "回滚脚本: $BACKUP_DIR/rollback.sh"

# ---------- 2. 预览变更 ----------
SYSCTL_KEYS=(
    "fs.file-max=655350"
    "net.ipv4.tcp_tw_reuse=1"
    "net.ipv4.tcp_fin_timeout=15"
    "net.ipv4.tcp_max_tw_buckets=262144"
    "net.core.somaxconn=65535"
    "net.ipv4.tcp_max_syn_backlog=262144"
    "net.ipv4.tcp_keepalive_time=600"
    "net.ipv4.tcp_keepalive_intvl=15"
    "net.ipv4.tcp_keepalive_probes=3"
    "net.core.rmem_max=16777216"
    "net.core.wmem_max=16777216"
)

echo ""
echo -e "${BLUE}========== 即将应用的内核参数 ==========${NC}"
printf "  %-42s %-10s %-10s\n" "参数" "当前值" "目标值"
for entry in "${SYSCTL_KEYS[@]}"; do
    key="${entry%%=*}"; val="${entry##*=}"
    cur=$(sysctl -n "$key" 2>/dev/null || echo "N/A")
    printf "  %-42s %-10s %-10s\n" "$key" "$cur" "$val"
done
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}!!! 禁止开启 tcp_tw_recycle，本脚本不会设置它 (NAT 下严重丢包) !!!${NC}"
echo ""

if [[ "$ASSUME_YES" != true ]]; then
    read -r -p "确认应用以上调优? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { log_warn "已取消"; exit 0; }
fi

# ---------- 3. 配置 limits.conf ----------
log_step "[2/4] 配置文件句柄 (/etc/security/limits.conf)"
LIMITS_FILE="/etc/security/limits.conf"
if [[ -f "$LIMITS_FILE" ]]; then
    sed -i '/^[#[:space:]]*\*[[:space:]]*\(soft\|hard\)[[:space:]]*nofile/d' "$LIMITS_FILE"
    cat >> "$LIMITS_FILE" <<'EOF'

# === Nginx 内核调优 - 文件句柄 ===
* soft nofile 655350
* hard nofile 655350
EOF
    log_info "limits.conf 已更新: nofile -> 655350 (需重新登录会话生效)"
else
    log_warn "$LIMITS_FILE 不存在，跳过"
fi

# ---------- 4. 配置 sysctl.conf ----------
log_step "[3/4] 写入内核参数 (/etc/sysctl.conf)"
SYSCTL_FILE="/etc/sysctl.conf"
# 去重: 删除已存在的同名键(含被注释行)，再追加干净配置块
for entry in "${SYSCTL_KEYS[@]}"; do
    key="${entry%%=*}"
    sed -i -E "/^[[:space:]]*#?[[:space:]]*${key//./\\.}[[:space:]]*=/d" "$SYSCTL_FILE"
done

cat >> "$SYSCTL_FILE" <<'EOF'

# ====== Nginx 生产级内核调优 (nginx-kernel-tuning.sh) ======
# 文件句柄
fs.file-max = 655350
# TIME_WAIT 复用 (短连接关键) ; tcp_tw_recycle 已废弃, 禁止开启
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_tw_buckets = 262144
# 连接队列, 防瞬时并发丢 SYN
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 262144
# Keepalive 探测加速
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 3
# TCP 缓冲区 (大文件/高延迟)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
# ====== Nginx 内核调优结束 ======
EOF
log_info "sysctl.conf 已更新"

# ---------- 5. 应用 ----------
log_step "[4/4] 应用配置 (sysctl --system)"
if ! sysctl --system >/dev/null 2>&1; then
    log_warn "sysctl --system 失败，回退到 sysctl -p"
    sysctl -p || { log_error "应用失败，请执行回滚: $BACKUP_DIR/rollback.sh"; exit 1; }
fi
log_info "配置已生效"

# ---------- 6. 验证 ----------
echo ""
echo -e "${BLUE}==================== 验证结果 ====================${NC}"
fail=0
check_param() {
    local key="$1" expect="$2" actual
    actual=$(sysctl -n "$key" 2>/dev/null || echo "N/A")
    if [[ "$actual" == "$expect" ]]; then
        printf "  ${GREEN}%-44s = %-10s [OK]${NC}\n" "$key" "$actual"
    else
        printf "  ${RED}%-44s = %-10s (期望 %s) [FAIL]${NC}\n" "$key" "$actual" "$expect"
        fail=1
    fi
}
check_param "fs.file-max"                    "655350"
check_param "net.ipv4.tcp_tw_reuse"          "1"
check_param "net.ipv4.tcp_fin_timeout"       "15"
check_param "net.ipv4.tcp_max_tw_buckets"    "262144"
check_param "net.core.somaxconn"             "65535"
check_param "net.ipv4.tcp_max_syn_backlog"   "262144"
check_param "net.ipv4.tcp_keepalive_time"    "600"
check_param "net.ipv4.tcp_keepalive_intvl"   "15"
check_param "net.ipv4.tcp_keepalive_probes"  "3"
check_param "net.core.rmem_max"              "16777216"
check_param "net.core.wmem_max"              "16777216"
echo -e "${BLUE}==================================================${NC}"
echo ""

if [[ $fail -eq 0 ]]; then
    log_info "所有内核参数校验通过"
else
    log_warn "部分参数未达预期，可能是内核版本不支持或被其它配置覆盖，请人工核查"
fi
log_info "limits.conf 的 nofile 需重新登录会话后生效 (ulimit -n 查看)"
log_info "回滚命令: $BACKUP_DIR/rollback.sh"
log_info "内核调优流程结束"
