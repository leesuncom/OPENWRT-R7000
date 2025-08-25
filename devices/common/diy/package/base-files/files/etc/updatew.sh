#!/bin/bash
# 完整版 SmartDNS 配置自动更新脚本
# 功能：拉取并格式化 GFW 列表、国内加速域名、IP 黑名单、DNS SPKI 指纹，自动部署到 SmartDNS 配置目录
# 适用环境：OpenWRT（需提前安装 curl、openssl、sed、grep 等基础工具）
set -e  # 脚本出错时立即退出，避免生成无效配置

##############################################################################
# 1. 初始化配置（关键路径、日志输出）
##############################################################################
# 定义 SmartDNS 核心配置目录（与用户原路径保持一致）
SMARTDNS_CONF_DIR="etc/smartdns"
# 定义临时文件目录（使用 /tmp，OpenWRT 中为内存挂载，重启自动清空）
TEMP_DIR="/tmp"
# 定义日志输出函数（带时间戳）
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# 创建 SmartDNS 配置目录（确保父目录存在）
log "=== 初始化：创建 SmartDNS 配置目录 ==="
mkdir -p "${SMARTDNS_CONF_DIR}/domain-set" "${SMARTDNS_CONF_DIR}/conf.d"
# 检查目录创建结果
if [ ! -d "${SMARTDNS_CONF_DIR}" ]; then
  log "ERROR：SmartDNS 配置目录创建失败！路径：${SMARTDNS_CONF_DIR}"
  exit 1
fi

##############################################################################
# 2. 拉取并格式化 GFW 列表（生成 proxy-domain-list.conf）
##############################################################################
log "=== 步骤1：拉取并聚合 GFW 域名列表 ==="
# 源1：gfwlist.txt（base64 解码，过滤无用规则）
GFW_SRC1="${TEMP_DIR}/temp_gfwlist1"
curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt" | \
  base64 -d | sort -u | sed '/^$\|@@/d' | \
  sed 's#!.\+##; s#|##g; s#@##g; s#http:\/\/##; s#https:\/\/##;' | \
  sed '/apple\.com/d; /sina\.cn/d; /sina\.com\.cn/d; /baidu\.com/d; /qq\.com/d' | \
  sed '/^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$/d' | grep '^[0-9a-zA-Z\.-]\+$' | \
  grep '\.' | sed 's#^\.\+##' | sort -u > "${GFW_SRC1}"

# 源2：fancyss gfwlist.conf（过滤 ipset 格式，保留纯域名）
GFW_SRC2="${TEMP_DIR}/temp_gfwlist2"
curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/hq450/fancyss/master/rules/gfwlist.conf" | \
  sed 's/ipset=\/\.//g; s/\/gfwlist//g; /^server/d' | sort -u > "${GFW_SRC2}"

# 源3：v2ray-rules-dat gfw.txt（直接拉取，去重）
GFW_SRC3="${TEMP_DIR}/temp_gfwlist3"
curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/gfw.txt" | \
  sort -u > "${GFW_SRC3}"

# 合并所有源（检查 extra.conf 是否存在，不存在则跳过）
GFW_MERGED="${TEMP_DIR}/temp_gfwlist"
EXTRA_CONF="script/extra.conf"
if [ -f "${EXTRA_CONF}" ]; then
  log "检测到 extra.conf，合并到 GFW 列表"
  cat "${GFW_SRC1}" "${GFW_SRC2}" "${GFW_SRC3}" "${EXTRA_CONF}" | sort -u | sed 's/^\.*//g' > "${GFW_MERGED}"
else
  log "未检测到 extra.conf，跳过该文件"
  cat "${GFW_SRC1}" "${GFW_SRC2}" "${GFW_SRC3}" | sort -u | sed 's/^\.*//g' > "${GFW_MERGED}"
fi

# 格式化为 SmartDNS 规则（nameserver /域名/oversea）
PROXY_DOMAIN_FILE="${SMARTDNS_CONF_DIR}/domain-set/proxy-domain-list.conf"
sed -i.bak \
  -e '/^$/d' \
  -e 's/^full://g' \
  -e '/^regexp:.*$/d' \
  -e 's/^/nameserver \//g' \
  -e 's/$/\/oversea/g' \
  "${GFW_MERGED}" && rm -f "${GFW_MERGED}.bak"

# 部署到目标路径
cat "${GFW_MERGED}" > "${PROXY_DOMAIN_FILE}"
log "GFW 列表更新完成！目标文件：${PROXY_DOMAIN_FILE}"
log "GFW 域名总数：$(grep -c '^nameserver' "${PROXY_DOMAIN_FILE}") 条"

##############################################################################
# 3. 拉取 Cloudflare IPv4 列表（用于防污染）
##############################################################################
log "=== 步骤2：拉取 Cloudflare IPv4 列表 ==="
CF_IP_FILE="${SMARTDNS_CONF_DIR}/cloudflare-ipv4.txt"
curl -kLfsm 10 --retry 2 "https://www.cloudflare.com/ips-v4/" | \
  sort -u | sed '/^$/d' > "${CF_IP_FILE}"

# 检查拉取结果
if [ $(wc -l < "${CF_IP_FILE}") -lt 5 ]; then
  log "WARNING：Cloudflare IPv4 列表拉取异常，可能为空或不完整"
else
  log "Cloudflare IPv4 列表更新完成！条目数：$(wc -l < "${CF_IP_FILE}")"
fi

##############################################################################
# 4. 自动获取 DNS 服务器 SPKI 指纹（防中间人攻击）
##############################################################################
log "=== 步骤3：获取 DNS 服务器 SPKI 指纹 ==="
SPKI_FILE="${SMARTDNS_CONF_DIR}/spki"
> "${SPKI_FILE}"  # 清空旧文件

# 定义要获取 SPKI 的 DNS 服务器列表（格式：名称 地址:端口）
declare -A DNS_SPKI_LIST=(
  ["cloudflare"]="1.0.0.1:853"
  ["google"]="8.8.8.8:853"
  ["DNSPod"]="120.53.53.53:853"
  ["SB"]="185.222.222.222:853"
  ["OpenDNS"]="208.67.222.222:853"
)

# 循环获取每个 DNS 的 SPKI 并校验
for NAME in "${!DNS_SPKI_LIST[@]}"; do
  ADDR="${DNS_SPKI_LIST[$NAME]}"
  log "正在获取 ${NAME} DNS 的 SPKI（${ADDR}）..."
  
  # 执行 openssl 命令获取 SPKI-PIN
  SPKI=$(echo | openssl s_client -connect "${ADDR}" 2>/dev/null | \
    openssl x509 -pubkey -noout | \
    openssl pkey -pubin -outform der | \
    openssl dgst -sha256 -binary | \
    openssl enc -base64)
  
  # 校验 SPKI 有效性（正常长度约 44 字符）
  if [ ${#SPKI} -lt 40 ]; then
    log "WARNING：${NAME} DNS 的 SPKI 获取失败，跳过该条目"
    continue
  fi
  
  # 写入 SPKI 文件
  echo "spki_${NAME}: ${SPKI}" >> "${SPKI_FILE}"
  log "✅ ${NAME} DNS SPKI 获取成功：${SPKI:0:20}..."
done

# 检查 SPKI 文件是否有效
if [ $(wc -l < "${SPKI_FILE}") -eq 0 ]; then
  log "ERROR：所有 DNS 的 SPKI 均获取失败，可能是网络问题或端口被屏蔽"
else
  log "SPKI 指纹文件更新完成！目标文件：${SPKI_FILE}"
fi

##############################################################################
# 5. 拉取国内 IP 列表（生成 blacklist-ip.conf）
##############################################################################
log "=== 步骤4：拉取国内 IP 列表（生成黑名单） ==="
BLACKLIST_IP_FILE="${SMARTDNS_CONF_DIR}/blacklist-ip.conf"

# 拉取 3 个国内 IP 源并合并
IP_SRC_QQWRY=$(curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/metowolf/iplist/master/data/special/china.txt")
IP_SRC_IPIP=$(curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt")
IP_SRC_CLANG=$(curl -kLfsm 10 --retry 2 "https://ispip.clang.cn/all_cn.txt")

# 检查是否所有源都拉取失败
if [ -z "${IP_SRC_QQWRY}" ] && [ -z "${IP_SRC_IPIP}" ] && [ -z "${IP_SRC_CLANG}" ]; then
  log "ERROR：所有国内 IP 源均拉取失败，无法生成 IP 黑名单"
else
  # 合并、去重、过滤无效格式（仅保留 IP/CIDR 格式）
  echo -e "${IP_SRC_QQWRY}\n${IP_SRC_IPIP}\n${IP_SRC_CLANG}" | \
    sort -u | \
    grep -E '^([0-9]+\.){3}[0-9]+(/[0-9]+)?$' | \
    sed -e '/^$/d' -e 's/^/blacklist-ip /g' > "${BLACKLIST_IP_FILE}"
  log "国内 IP 黑名单更新完成！条目数：$(grep -c '^blacklist-ip' "${BLACKLIST_IP_FILE}") 条"
fi

##############################################################################
# 6. 拉取国内加速域名列表（生成 domains.china.smartdns.conf）
##############################################################################
log "=== 步骤5：拉取国内加速域名列表 ==="
CHINA_DOMAIN_FILE="${SMARTDNS_CONF_DIR}/domain-set/domains.china.smartdns.conf"
CHINA_DOMAIN_TEMP="${TEMP_DIR}/domains.china.smartdns.conf"

# 拉取 3 个国内域名源（accelerated-domains、apple、google 国内域名）
DOMAIN_SRC_ACCEL=$(curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf")
DOMAIN_SRC_APPLE=$(curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf")
DOMAIN_SRC_GOOGLE=$(curl -kLfsm 10 --retry 2 "https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf")

# 合并、去重、过滤无效格式
echo -e "${DOMAIN_SRC_ACCEL}\n${DOMAIN_SRC_APPLE}\n${DOMAIN_SRC_GOOGLE}" | \
  sort -u | \
  sed -e 's/#.*//g' -e '/^$/d' -e 's/server=\///g' -e 's/\/114.114.114.114//g' | \
  sort -u > "${CHINA_DOMAIN_TEMP}"

# 格式化为 SmartDNS 规则（nameserver /域名/china）
sed -i.bak \
  -e 's/^full://g' \
  -e '/^regexp:.*$/d' \
  -e 's/^/nameserver \//g' \
  -e 's/$/\/china/g' \
  "${CHINA_DOMAIN_TEMP}" && rm -f "${CHINA_DOMAIN_TEMP}.bak"

# 部署到目标路径
cat "${CHINA_DOMAIN_TEMP}" > "${CHINA_DOMAIN_FILE}"
log "国内加速域名列表更新完成！目标文件：${CHINA_DOMAIN_FILE}"
log "国内域名总数：$(grep -c '^nameserver' "${CHINA_DOMAIN_FILE}") 条"

##############################################################################
# 7. 更新 Hosts 文件（GitHub/Docker 等服务优化）
##############################################################################
log "=== 步骤6：更新 Hosts 文件 ==="
HOSTS_FILE="etc/hosts"
HOSTS_SRC_URL="https://ghfast.top/https://raw.githubusercontent.com/shidahuilang/hosts/main/hosts"

# 检查 Hosts 文件是否存在
if [ ! -f "${HOSTS_FILE}" ]; then
  log "WARNING：Hosts 文件不存在，跳过更新！路径：${HOSTS_FILE}"
else
  # 清理旧的 ING Hosts 区块（避免重复）
  sed -i '/# ING Hosts Start/,/# ING Hosts End/d' "${HOSTS_FILE}"
  
  # 拉取新 Hosts 并追加
  log "正在拉取新 Hosts 列表（${HOSTS_SRC_URL}）..."
  HOSTS_CONTENT=$(curl -kLfsm 10 --retry 2 "${HOSTS_SRC_URL}")
  if [ -z "${HOSTS_CONTENT}" ]; then
    log "WARNING：Hosts 列表拉取失败，跳过更新"
  else
    echo -e "\n# ING Hosts Start" >> "${HOSTS_FILE}"
    echo -e "${HOSTS_CONTENT}" >> "${HOSTS_FILE}"
    echo -e "# ING Hosts End" >> "${HOSTS_FILE}"
    log "Hosts 文件更新完成！新增条目数：$(echo "${HOSTS_CONTENT}" | grep -c '^[0-9]') 条"
  fi
fi

##############################################################################
# 8. 清理临时文件 + 重启 SmartDNS（生效配置）
##############################################################################
log "=== 步骤7：清理临时文件 ==="
# 清理所有临时文件
rm -f \
  "${GFW_SRC1}" "${GFW_SRC2}" "${GFW_SRC3}" "${GFW_MERGED}" \
  "${CHINA_DOMAIN_TEMP}" \
  "${TEMP_DIR}/proxy-domain-list.conf" "${TEMP_DIR}/temp_hosts"
log "临时文件清理完成"

# 重启 SmartDNS（仅在 OpenWRT 环境下执行）
log "=== 步骤8：重启 SmartDNS 生效配置 ==="
if [ -f "/etc/init.d/smartdns" ]; then
  /etc/init.d/smartdns restart
  if [ $? -eq 0 ]; then
    log "✅ SmartDNS 重启成功，新配置已生效"
  else
    log "ERROR：SmartDNS 重启失败，请手动检查配置文件！"
    exit 1
  fi
else
  log "WARNING：未检测到 SmartDNS 服务脚本，需手动重启生效配置"
fi

##############################################################################
# 脚本执行完成
##############################################################################
log "=== 所有任务执行完成！==="
log "关键文件路径："
log " - GFW 列表：${PROXY_DOMAIN_FILE}"
log " - 国内域名列表：${CHINA_DOMAIN_FILE}"
log " - IP 黑名单：${BLACKLIST_IP_FILE}"
log " - SPKI 指纹：${SPKI_FILE}"
exit 0