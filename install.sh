#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/etc/epusdt-one-click.env"

if [[ -f "${STATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
fi

REPO_API_URL="https://api.github.com/repos/GMWalletApp/epusdt/releases/latest"
REPO_RELEASE_BASE="https://github.com/GMWalletApp/epusdt/releases/download"

DEFAULT_INSTALL_DIR="${EPUSDT_INSTALL_DIR:-/opt/epusdt}"
DEFAULT_SERVICE_NAME="${EPUSDT_SERVICE_NAME:-epusdt}"
DEFAULT_SERVICE_USER="${EPUSDT_SERVICE_USER:-epusdt}"
DEFAULT_SERVICE_GROUP="${EPUSDT_SERVICE_GROUP:-${DEFAULT_SERVICE_USER}}"
DEFAULT_VERSION="${EPUSDT_VERSION:-latest}"
DEFAULT_DOMAIN="${EPUSDT_DOMAIN:-}"
DEFAULT_APP_NAME="${EPUSDT_APP_NAME:-epusdt}"
DEFAULT_APP_URI="${EPUSDT_APP_URI:-}"
DEFAULT_BIND_ADDR="${EPUSDT_BIND_ADDR:-}"
DEFAULT_PORT="${EPUSDT_PORT:-}"
DEFAULT_API_RATE_URL="${EPUSDT_API_RATE_URL:-}"
DEFAULT_WITH_NGINX="${EPUSDT_WITH_NGINX:-auto}"
DEFAULT_NGINX_CONF_PATH="${EPUSDT_NGINX_CONF_PATH:-}"

COMMAND="${1:-}"
shift || true

FORCE=0
NON_INTERACTIVE=0
INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
SERVICE_NAME="${DEFAULT_SERVICE_NAME}"
SERVICE_USER="${DEFAULT_SERVICE_USER}"
SERVICE_GROUP="${DEFAULT_SERVICE_GROUP}"
VERSION="${DEFAULT_VERSION}"
DOMAIN="${DEFAULT_DOMAIN}"
APP_NAME="${DEFAULT_APP_NAME}"
APP_URI="${DEFAULT_APP_URI}"
BIND_ADDR="${DEFAULT_BIND_ADDR}"
PORT="${DEFAULT_PORT}"
API_RATE_URL="${DEFAULT_API_RATE_URL}"
WITH_NGINX="${DEFAULT_WITH_NGINX}"
NGINX_CONF_PATH="${DEFAULT_NGINX_CONF_PATH}"

if [[ -t 1 ]]; then
  R=$'\033[0;31m'
  G=$'\033[0;32m'
  Y=$'\033[1;33m'
  B=$'\033[0;34m'
  NC=$'\033[0m'
else
  R=''
  G=''
  Y=''
  B=''
  NC=''
fi

info() { printf "${B}[信息]${NC} %s\n" "$1"; }
warn() { printf "${Y}[警告]${NC} %s\n" "$1"; }
success() { printf "${G}[完成]${NC} %s\n" "$1"; }
error() { printf "${R}[错误]${NC} %s\n" "$1" >&2; }
die() { error "$1"; exit 1; }
print_line() { printf '%s\n' "--------------------------------------------------"; }
print_banner() {
  echo ""
  print_line
  printf ' Epusdt 一键部署脚本 | 品牌：鱼肥肥\n'
  printf ' 支持联系：https://t.me/pyufc\n'
  print_line
  echo ""
}
support_info() {
  printf '\n'
  printf '品牌支持：鱼肥肥\n'
  printf '联系方式：https://t.me/pyufc\n'
}

usage() {
  cat <<'EOF'
用法：
  bash install.sh install [参数]
  bash install.sh update [参数]
  bash install.sh restart
  bash install.sh stop
  bash install.sh status
  bash install.sh logs

参数：
  --install-dir PATH
  --service-name NAME
  --service-user USER
  --service-group GROUP
  --version VERSION|latest
  --domain DOMAIN
  --port PORT
  --bind-addr ADDR
  --app-name NAME
  --app-uri URI
  --api-rate-url URL
  --with-nginx 1|0|auto
  --nginx-conf-path PATH
  --non-interactive
  --force
EOF
  printf '\n'
  printf '品牌支持：鱼肥肥\n'
  printf '联系方式：https://t.me/pyufc\n'
}

cleanup_tmpdir() {
  local dir="${1:-}"
  if [[ -n "${dir}" && -d "${dir}" ]]; then
    rm -rf "${dir}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --service-name) SERVICE_NAME="$2"; shift 2 ;;
    --service-user) SERVICE_USER="$2"; shift 2 ;;
    --service-group) SERVICE_GROUP="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --bind-addr) BIND_ADDR="$2"; shift 2 ;;
    --app-name) APP_NAME="$2"; shift 2 ;;
    --app-uri) APP_URI="$2"; shift 2 ;;
    --api-rate-url) API_RATE_URL="$2"; shift 2 ;;
    --with-nginx) WITH_NGINX="$2"; shift 2 ;;
    --nginx-conf-path) NGINX_CONF_PATH="$2"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_nginx_binary() {
  if command_exists nginx; then
    command -v nginx
    return 0
  fi
  if [[ -x /www/server/nginx/sbin/nginx ]]; then
    printf '%s' "/www/server/nginx/sbin/nginx"
    return 0
  fi
  return 1
}

has_nginx_runtime() {
  if detect_nginx_binary >/dev/null 2>&1; then
    return 0
  fi
  if pgrep -x nginx >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 执行"
}

require_systemd() {
  command_exists systemctl || die "未找到 systemctl"
}

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

prompt_default() {
  local prompt="$1"
  local default="${2:-}"
  local answer=""
  if [[ -n "${default}" ]]; then
    printf '%s [%s]: ' "${prompt}" "${default}" >&2
  else
    printf '%s: ' "${prompt}" >&2
  fi
  read -r answer
  answer="$(trim "${answer}")"
  if [[ -z "${answer}" ]]; then
    printf '%s' "${default}"
  else
    printf '%s' "${answer}"
  fi
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped
  escaped="$(escape_sed_replacement "${value}")"
  if grep -qE "^${key}=" "${file}"; then
    sed -i "s|^${key}=.*$|${key}=${escaped}|" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${file}"
  fi
}

backup_file_if_exists() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    cp -f "${file}" "${file}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

save_state() {
  {
    printf 'EPUSDT_INSTALL_DIR=%q\n' "${INSTALL_DIR}"
    printf 'EPUSDT_SERVICE_NAME=%q\n' "${SERVICE_NAME}"
    printf 'EPUSDT_SERVICE_USER=%q\n' "${SERVICE_USER}"
    printf 'EPUSDT_SERVICE_GROUP=%q\n' "${SERVICE_GROUP}"
    printf 'EPUSDT_VERSION=%q\n' "${VERSION}"
    printf 'EPUSDT_DOMAIN=%q\n' "${DOMAIN}"
    printf 'EPUSDT_APP_NAME=%q\n' "${APP_NAME}"
    printf 'EPUSDT_APP_URI=%q\n' "${APP_URI}"
    printf 'EPUSDT_BIND_ADDR=%q\n' "${BIND_ADDR}"
    printf 'EPUSDT_PORT=%q\n' "${PORT}"
    printf 'EPUSDT_API_RATE_URL=%q\n' "${API_RATE_URL}"
    printf 'EPUSDT_WITH_NGINX=%q\n' "${WITH_NGINX}"
    printf 'EPUSDT_NGINX_CONF_PATH=%q\n' "${NGINX_CONF_PATH}"
  } > "${STATE_FILE}"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf '%s' "amd64" ;;
    aarch64|arm64) printf '%s' "arm64" ;;
    *) die "不支持的架构: $(uname -m)" ;;
  esac
}

detect_package_manager() {
  if command_exists apt-get; then
    printf '%s' "apt"
  elif command_exists dnf; then
    printf '%s' "dnf"
  elif command_exists yum; then
    printf '%s' "yum"
  else
    die "未找到支持的包管理器"
  fi
}

install_packages() {
  local need_nginx="$1"
  local packages=(curl tar ca-certificates)
  local pm
  pm="$(detect_package_manager)"
  if [[ "${need_nginx}" == "1" ]] && ! has_nginx_runtime; then
    packages+=(nginx)
  fi

  if [[ "${#packages[@]}" -eq 3 ]]; then
    info "基础依赖已满足，跳过额外软件安装"
  fi

  case "${pm}" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "${packages[@]}"
      ;;
    dnf)
      dnf install -y "${packages[@]}"
      ;;
    yum)
      yum install -y "${packages[@]}"
      ;;
  esac
}

port_in_use() {
  local port="$1"
  if command_exists ss; then
    ss -ltnH "( sport = :${port} )" 2>/dev/null | grep -q .
    return $?
  fi
  return 1
}

find_available_port() {
  local port="${1:-8000}"
  while port_in_use "${port}"; do
    port=$((port + 1))
  done
  printf '%s' "${port}"
}

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] || return 1
  (( "$1" >= 1 && "$1" <= 65535 ))
}

detect_server_ip() {
  local ip_addr=""
  if command_exists ip; then
    ip_addr="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}' || true)"
  fi
  if [[ -z "${ip_addr}" ]] && command_exists hostname; then
    ip_addr="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  [[ -n "${ip_addr}" ]] && printf '%s' "${ip_addr}" || printf '%s' "127.0.0.1"
}

get_latest_version() {
  curl -fsSL "${REPO_API_URL}" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

normalize_version() {
  local version="$1"
  if [[ "${version}" == "latest" ]]; then
    version="$(get_latest_version)"
  fi
  [[ -n "${version}" ]] || die "无法获取最新版本"
  if [[ "${version}" != v* ]]; then
    version="v${version}"
  fi
  printf '%s' "${version}"
}

download_release() {
  local version="$1"
  local arch="$2"
  local tmpdir="$3"
  local clean_version="${version#v}"
  local asset_name="epusdt-${clean_version}-linux-${arch}.tar.gz"
  local asset_url="${REPO_RELEASE_BASE}/${version}/${asset_name}"
  local sums_url="${REPO_RELEASE_BASE}/${version}/SHA256SUMS"

  info "开始下载 ${asset_name}"
  curl -fsSL -o "${tmpdir}/${asset_name}" "${asset_url}"
  curl -fsSL -o "${tmpdir}/SHA256SUMS" "${sums_url}"

  if ! grep -q " ${asset_name}$" "${tmpdir}/SHA256SUMS"; then
    die "未找到 ${asset_name} 的校验信息"
  fi

  (
    cd "${tmpdir}"
    grep " ${asset_name}$" SHA256SUMS | sha256sum -c -
  )

  tar -xzf "${tmpdir}/${asset_name}" -C "${tmpdir}"
  [[ -f "${tmpdir}/epusdt" ]] || die "压缩包内未找到 epusdt"
  [[ -f "${tmpdir}/.env.example" ]] || die "压缩包内未找到 .env.example"
}

ensure_service_account() {
  if id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    return 0
  fi

  local shell_path="/usr/sbin/nologin"
  [[ -x "${shell_path}" ]] || shell_path="/sbin/nologin"
  [[ -x "${shell_path}" ]] || shell_path="/bin/false"

  info "创建服务用户 ${SERVICE_USER}"
  useradd --system --home-dir "${INSTALL_DIR}" --shell "${shell_path}" "${SERVICE_USER}"
}

resolve_group() {
  if getent group "${SERVICE_GROUP}" >/dev/null 2>&1; then
    return 0
  fi
  if id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    SERVICE_GROUP="$(id -gn "${SERVICE_USER}")"
  fi
}

prepare_values() {
  local server_ip
  server_ip="$(detect_server_ip)"

  if [[ "${NON_INTERACTIVE}" -eq 0 && "${COMMAND}" == "install" ]]; then
    INSTALL_DIR="$(prompt_default "安装目录" "${INSTALL_DIR}")"
    SERVICE_NAME="$(prompt_default "服务名" "${SERVICE_NAME}")"
    SERVICE_USER="$(prompt_default "服务用户" "${SERVICE_USER}")"
    SERVICE_GROUP="$(prompt_default "服务用户组" "${SERVICE_GROUP}")"
    VERSION="$(prompt_default "版本（latest 或具体 tag）" "${VERSION}")"
    DOMAIN="$(prompt_default "域名（留空则直接端口访问）" "${DOMAIN}")"

    if [[ -n "${DOMAIN}" ]]; then
      if [[ -z "${WITH_NGINX}" || "${WITH_NGINX}" == "auto" ]]; then
        WITH_NGINX="1"
      fi
      WITH_NGINX="$(prompt_default "是否启用 nginx 反代？1=是 0=否" "${WITH_NGINX}")"
      case "${WITH_NGINX}" in
        0|1) ;;
        *) die "nginx 选项只能是 0 或 1" ;;
      esac
    else
      WITH_NGINX="0"
    fi

    if [[ -z "${PORT}" ]]; then
      PORT="$(find_available_port 8000)"
    fi
    if [[ -z "${BIND_ADDR}" ]]; then
      if [[ "${WITH_NGINX}" == "1" ]]; then
        BIND_ADDR="127.0.0.1"
      else
        BIND_ADDR="0.0.0.0"
      fi
    fi
    if [[ -z "${APP_URI}" ]]; then
      if [[ -n "${DOMAIN}" ]]; then
        APP_URI="http://${DOMAIN}"
      else
        APP_URI="http://${server_ip}:${PORT}"
      fi
    fi

    PORT="$(prompt_default "监听端口" "${PORT}")"
    BIND_ADDR="$(prompt_default "绑定地址" "${BIND_ADDR}")"
    APP_NAME="$(prompt_default "应用名称" "${APP_NAME}")"
    APP_URI="$(prompt_default "应用地址" "${APP_URI}")"
    API_RATE_URL="$(prompt_default "汇率接口地址（留空使用上游默认）" "${API_RATE_URL}")"
  fi

  if [[ -z "${PORT}" ]]; then
    PORT="$(find_available_port 8000)"
  fi
  validate_port "${PORT}" || die "端口不合法: ${PORT}"

  if [[ -z "${WITH_NGINX}" || "${WITH_NGINX}" == "auto" ]]; then
    if [[ -n "${DOMAIN}" ]]; then
      WITH_NGINX="1"
    else
      WITH_NGINX="0"
    fi
  fi

  case "${WITH_NGINX}" in
    0|1) ;;
    *) die "--with-nginx 只支持 0、1 或 auto" ;;
  esac

  if [[ -z "${BIND_ADDR}" ]]; then
    if [[ "${WITH_NGINX}" == "1" ]]; then
      BIND_ADDR="127.0.0.1"
    else
      BIND_ADDR="0.0.0.0"
    fi
  fi

  if [[ -z "${APP_URI}" ]]; then
    if [[ -n "${DOMAIN}" ]]; then
      APP_URI="http://${DOMAIN}"
    else
      APP_URI="http://${server_ip}:${PORT}"
    fi
  fi

  if [[ "${WITH_NGINX}" == "1" && -z "${DOMAIN}" ]]; then
    die "启用 nginx 时必须提供域名"
  fi

  VERSION="$(normalize_version "${VERSION}")"
  resolve_group
}

detect_nginx_conf_path() {
  if [[ -n "${NGINX_CONF_PATH}" ]]; then
    printf '%s' "${NGINX_CONF_PATH}"
    return 0
  fi

  local base_dir
  for base_dir in \
    /www/server/panel/vhost/nginx \
    /www/server/nginx/conf/vhost \
    /etc/nginx/conf.d \
    /etc/nginx/sites-enabled; do
    if [[ -d "${base_dir}" ]]; then
      printf '%s/%s.conf' "${base_dir}" "${SERVICE_NAME}"
      return 0
    fi
  done

  return 1
}

write_systemd_service() {
  local unit_path="/etc/systemd/system/${SERVICE_NAME}.service"
  backup_file_if_exists "${unit_path}"
  cat > "${unit_path}" <<EOF
[Unit]
Description=Epusdt Crypto Payment Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/epusdt --config ${INSTALL_DIR} http start
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service"
  systemctl restart "${SERVICE_NAME}.service"
}

write_nginx_config() {
  [[ "${WITH_NGINX}" == "1" ]] || return 0

  local conf_path
  local nginx_bin=""
  conf_path="$(detect_nginx_conf_path)" || die "未找到 nginx 配置目录，请使用 --nginx-conf-path 指定"
  NGINX_CONF_PATH="${conf_path}"
  nginx_bin="$(detect_nginx_binary || true)"

  mkdir -p "$(dirname "${conf_path}")"
  backup_file_if_exists "${conf_path}"

  cat > "${conf_path}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    client_max_body_size 20m;

    location / {
        proxy_pass http://${BIND_ADDR}:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF

  [[ -n "${nginx_bin}" ]] || die "nginx 配置已写入，但未找到 nginx 可执行文件"
  "${nginx_bin}" -t

  if [[ "${nginx_bin}" == "/www/server/nginx/sbin/nginx" ]]; then
    if pgrep -x nginx >/dev/null 2>&1; then
      "${nginx_bin}" -s reload || warn "宝塔 nginx 配置已写入，但 reload 未成功，请手动重载"
    else
      warn "检测到宝塔 nginx 二进制，但当前 nginx 进程未运行。配置已写入，请在面板里启动或重载 nginx"
    fi
  else
    systemctl enable nginx >/dev/null 2>&1 || true
    if systemctl is-active --quiet nginx; then
      systemctl reload nginx
    else
      systemctl start nginx || true
      if systemctl is-active --quiet nginx; then
        success "nginx 已启动并加载新配置"
      else
        warn "nginx 未处于 active 状态，已写入配置但未能通过 systemctl 启动，常见原因是 80 端口已被其他 nginx 占用"
      fi
    fi
  fi
  success "nginx 配置已写入 ${conf_path}"
}

install_binary_and_env() {
  local tmpdir="$1"
  local mode="$2"
  local old_dir=""
  local env_exists_before=0
  local reset_env=0

  [[ -f "${INSTALL_DIR}/.env" ]] && env_exists_before=1

  mkdir -p "${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}/runtime"
  mkdir -p "${INSTALL_DIR}/.old_versions"

  if [[ -f "${INSTALL_DIR}/epusdt" ]]; then
    old_dir="${INSTALL_DIR}/.old_versions/$(date +%Y%m%d%H%M%S)"
    mkdir -p "${old_dir}"
    cp -f "${INSTALL_DIR}/epusdt" "${old_dir}/epusdt"
    [[ -f "${INSTALL_DIR}/.env" ]] && cp -f "${INSTALL_DIR}/.env" "${old_dir}/.env"
  fi

  install -m 755 "${tmpdir}/epusdt" "${INSTALL_DIR}/epusdt"
  install -m 644 "${tmpdir}/.env.example" "${INSTALL_DIR}/.env.upstream.example"

  if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
    cp -f "${INSTALL_DIR}/.env.upstream.example" "${INSTALL_DIR}/.env"
    reset_env=1
  elif [[ "${mode}" == "install" && "${FORCE}" -eq 1 ]]; then
    cp -f "${INSTALL_DIR}/.env.upstream.example" "${INSTALL_DIR}/.env"
    reset_env=1
  fi

  if [[ "${mode}" == "update" && "${env_exists_before}" -ne 1 ]]; then
    die "现有 .env 不存在，无法安全更新"
  fi

  if [[ "${mode}" == "install" ]]; then
    set_env_value "${INSTALL_DIR}/.env" "app_name" "${APP_NAME}"
    set_env_value "${INSTALL_DIR}/.env" "app_uri" "${APP_URI}"
    set_env_value "${INSTALL_DIR}/.env" "http_listen" "${BIND_ADDR}:${PORT}"
    set_env_value "${INSTALL_DIR}/.env" "runtime_root_path" "./runtime"
    set_env_value "${INSTALL_DIR}/.env" "db_type" "sqlite"
    set_env_value "${INSTALL_DIR}/.env" "sqlite_database_filename" "epusdt.db"
    set_env_value "${INSTALL_DIR}/.env" "runtime_sqlite_filename" "epusdt-runtime.db"
    if [[ -n "${API_RATE_URL}" ]]; then
      set_env_value "${INSTALL_DIR}/.env" "api_rate_url" "${API_RATE_URL}"
    fi
    if [[ "${reset_env}" -eq 1 || "${env_exists_before}" -eq 0 ]]; then
      set_env_value "${INSTALL_DIR}/.env" "install" "true"
    fi
  fi

  chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}"
}

wait_for_http() {
  local url="$1"
  local max_attempts="${2:-20}"
  local attempt=1
  local code=""

  while (( attempt <= max_attempts )); do
    code="$(curl -L -s -o /dev/null -w '%{http_code}' "${url}" || true)"
    if [[ "${code}" =~ ^(200|301|302|307|308)$ ]]; then
      success "服务检测通过: ${url} (${code})"
      return 0
    fi
    sleep 1
    attempt=$((attempt + 1))
  done

  warn "服务已启动，但健康检查暂未通过: ${url}"
  return 1
}

do_install() {
  require_root
  require_systemd
  prepare_values

  if [[ -f "${INSTALL_DIR}/epusdt" && "${FORCE}" -ne 1 ]]; then
    die "${INSTALL_DIR} 已存在 epusdt，请使用 update 或加 --force"
  fi

  ensure_service_account
  resolve_group
  install_packages "${WITH_NGINX}"

  local tmpdir arch
  tmpdir="$(mktemp -d)"
  arch="$(detect_arch)"
  trap "cleanup_tmpdir '${tmpdir}'" EXIT

  download_release "${VERSION}" "${arch}" "${tmpdir}"
  install_binary_and_env "${tmpdir}" "install"
  write_systemd_service
  write_nginx_config
  save_state
  wait_for_http "http://127.0.0.1:${PORT}/" || true

  success "安装完成"
  printf '\n'
  printf '版本: %s\n' "${VERSION}"
  printf '安装目录: %s\n' "${INSTALL_DIR}"
  printf '服务名: %s\n' "${SERVICE_NAME}"
  printf '监听地址: %s:%s\n' "${BIND_ADDR}" "${PORT}"
  printf '访问地址: %s\n' "${APP_URI}"
  printf '\n'
  printf '下一步：打开上面的访问地址，完成官方 Epusdt 安装向导。\n'
  support_info
}

do_update() {
  require_root
  require_systemd

  [[ -f "${INSTALL_DIR}/epusdt" ]] || die "未在 ${INSTALL_DIR} 发现 epusdt"

  if [[ -z "${PORT}" && -f "${INSTALL_DIR}/.env" ]]; then
    PORT="$(sed -n 's/^http_listen=.*:\([0-9][0-9]*\)$/\1/p' "${INSTALL_DIR}/.env" | tail -n1)"
  fi
  [[ -n "${PORT}" ]] || PORT="8000"

  VERSION="$(normalize_version "${VERSION}")"
  ensure_service_account
  resolve_group
  install_packages "0"

  local tmpdir arch
  tmpdir="$(mktemp -d)"
  arch="$(detect_arch)"
  trap "cleanup_tmpdir '${tmpdir}'" EXIT

  download_release "${VERSION}" "${arch}" "${tmpdir}"
  install_binary_and_env "${tmpdir}" "update"
  save_state
  systemctl restart "${SERVICE_NAME}.service"
  wait_for_http "http://127.0.0.1:${PORT}/" || true
  success "已更新到 ${VERSION}"
  support_info
}

do_restart() {
  require_root
  systemctl restart "${SERVICE_NAME}.service"
  success "服务已重启: ${SERVICE_NAME}"
  support_info
}

do_stop() {
  require_root
  systemctl stop "${SERVICE_NAME}.service"
  success "服务已停止: ${SERVICE_NAME}"
  support_info
}

do_status() {
  systemctl status "${SERVICE_NAME}.service" --no-pager
}

do_logs() {
  journalctl -u "${SERVICE_NAME}.service" -n 200 --no-pager
}

show_version() {
  local local_version="unknown"
  local latest_version="unknown"
  if [[ -x "${INSTALL_DIR}/epusdt" ]]; then
    local_version="$("${INSTALL_DIR}/epusdt" version 2>/dev/null | sed -n 's/^version: //p' | head -n1 || true)"
    [[ -n "${local_version}" ]] || local_version="unknown"
  fi
  latest_version="$(get_latest_version 2>/dev/null || true)"
  [[ -n "${latest_version}" ]] || latest_version="unknown"

  print_banner
  printf '安装目录：%s\n' "${INSTALL_DIR}"
  printf '服务名：%s\n' "${SERVICE_NAME}"
  printf '当前版本：%s\n' "${local_version}"
  printf '最新版本：%s\n' "${latest_version}"
  printf '联系支持：https://t.me/pyufc\n'
}

menu_loop() {
  while true; do
    print_banner
    echo "1. 开始部署"
    echo "2. 一键更新"
    echo "3. 日常管理"
    echo "4. 检查版本"
    echo "0. 退出"
    echo ""
    local choice=""
    choice="$(prompt_default "请选择" "1")"
    case "${choice}" in
      1) do_install ;;
      2) do_update ;;
      3)
        print_banner
        echo "1. 查看服务状态"
        echo "2. 查看日志"
        echo "3. 重启服务"
        echo "4. 停止服务"
        echo "5. 返回上级菜单"
        echo ""
        local mgmt=""
        mgmt="$(prompt_default "请选择" "1")"
        case "${mgmt}" in
          1) do_status ;;
          2) do_logs ;;
          3) do_restart ;;
          4) do_stop ;;
          5) ;;
          *) warn "无效选项" ;;
        esac
        ;;
      4) show_version ;;
      0) exit 0 ;;
      *) warn "无效选项" ;;
    esac
    echo ""
    read -r -p "按回车继续..." _dummy
  done
}

case "${COMMAND}" in
  menu) menu_loop ;;
  install) do_install ;;
  update) do_update ;;
  restart) do_restart ;;
  stop) do_stop ;;
  status) do_status ;;
  logs) do_logs ;;
  version) show_version ;;
  "") menu_loop ;;
  help|-h|--help) usage ;;
  *) die "未知命令: ${COMMAND}，可直接运行进入菜单，或使用 --help 查看命令行参数" ;;
esac
