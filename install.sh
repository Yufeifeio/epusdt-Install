#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/etc/epusdt-one-click.env"
REPO_API_URL="https://api.github.com/repos/GMWalletApp/epusdt/releases/latest"
REPO_RELEASE_BASE="https://github.com/GMWalletApp/epusdt/releases/download"

if [[ -f "${STATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
fi

suggest_install_dir() {
  local state_dir="${EPUSDT_INSTALL_DIR:-}"
  local cwd="${PWD}"
  if [[ -n "${cwd}" && "${cwd}" != "/" && "${cwd}" != "/root" ]]; then
    printf '%s' "${cwd}"
    return 0
  fi
  if [[ -n "${state_dir}" && ( -f "${state_dir}/epusdt" || -f "${state_dir}/.env" ) ]]; then
    printf '%s' "${state_dir}"
    return 0
  fi
  printf '%s' "/opt/epusdt"
}

DEFAULT_INSTALL_DIR="$(suggest_install_dir)"
DEFAULT_SERVICE_NAME="${EPUSDT_SERVICE_NAME:-epusdt}"
DEFAULT_SERVICE_USER="${EPUSDT_SERVICE_USER:-epusdt}"
DEFAULT_SERVICE_GROUP="${EPUSDT_SERVICE_GROUP:-${DEFAULT_SERVICE_USER}}"
DEFAULT_VERSION="${EPUSDT_VERSION:-latest}"
DEFAULT_DOMAIN="${EPUSDT_DOMAIN:-}"
DEFAULT_APP_NAME="${EPUSDT_APP_NAME:-epusdt}"
DEFAULT_BIND_ADDR="${EPUSDT_BIND_ADDR:-}"
DEFAULT_PORT="${EPUSDT_PORT:-}"
DEFAULT_API_RATE_URL="${EPUSDT_API_RATE_URL:-}"
DEFAULT_NGINX_CONF_PATH="${EPUSDT_NGINX_CONF_PATH:-}"
DEFAULT_ACME_EMAIL="${EPUSDT_ACME_EMAIL:-}"
DEFAULT_ACCESS_URL="${EPUSDT_ACCESS_URL:-}"

COMMAND="${1:-}"
shift || true

FORCE=0
NON_INTERACTIVE=0
FROM_MENU=0
INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
SERVICE_NAME="${DEFAULT_SERVICE_NAME}"
SERVICE_USER="${DEFAULT_SERVICE_USER}"
SERVICE_GROUP="${DEFAULT_SERVICE_GROUP}"
VERSION="${DEFAULT_VERSION}"
DOMAIN="${DEFAULT_DOMAIN}"
APP_NAME="${DEFAULT_APP_NAME}"
APP_URI=""
BIND_ADDR="${DEFAULT_BIND_ADDR}"
PORT="${DEFAULT_PORT}"
API_RATE_URL="${DEFAULT_API_RATE_URL}"
WITH_NGINX="0"
NGINX_CONF_PATH="${DEFAULT_NGINX_CONF_PATH}"
ACME_EMAIL="${DEFAULT_ACME_EMAIL}"
ACCESS_URL="${DEFAULT_ACCESS_URL}"

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
  printf '\n'
  print_line
  printf ' Epusdt 一键部署脚本\n'
  printf ' 鱼肥肥 @pyufc\n'
  print_line
  printf '\n'
}
support_info() {
  printf '\n'
  printf '鱼肥肥 @pyufc\n'
}

usage() {
  cat <<'EOF'
用法：
  bash install.sh
  bash install.sh menu
  bash install.sh install [参数]
  bash install.sh update [参数]
  bash install.sh https [参数]
  bash install.sh start
  bash install.sh restart
  bash install.sh stop
  bash install.sh status
  bash install.sh logs
  bash install.sh version

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
  --api-rate-url URL
  --nginx-conf-path PATH
  --acme-email EMAIL
  --non-interactive
  --force
EOF
  support_info
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
    --api-rate-url) API_RATE_URL="$2"; shift 2 ;;
    --nginx-conf-path) NGINX_CONF_PATH="$2"; shift 2 ;;
    --acme-email) ACME_EMAIL="$2"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

command_exists() {
  command -v "$1" >/dev/null 2>&1
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
    printf 'EPUSDT_BIND_ADDR=%q\n' "${BIND_ADDR}"
    printf 'EPUSDT_PORT=%q\n' "${PORT}"
    printf 'EPUSDT_API_RATE_URL=%q\n' "${API_RATE_URL}"
    printf 'EPUSDT_NGINX_CONF_PATH=%q\n' "${NGINX_CONF_PATH}"
    printf 'EPUSDT_ACME_EMAIL=%q\n' "${ACME_EMAIL}"
    printf 'EPUSDT_ACCESS_URL=%q\n' "${ACCESS_URL}"
  } > "${STATE_FILE}"
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 执行"
}

require_systemd() {
  command_exists systemctl || die "未找到 systemctl"
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
  pgrep -x nginx >/dev/null 2>&1
}

install_packages() {
  local need_https="${1:-0}"
  local packages=(curl tar ca-certificates)
  local pm
  pm="$(detect_package_manager)"

  if [[ "${need_https}" == "1" ]]; then
    packages+=(openssl)
    if ! has_nginx_runtime; then
      packages+=(nginx)
    fi
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

detect_local_ip() {
  local ip_addr=""
  if command_exists ip; then
    ip_addr="$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}' || true)"
  fi
  if [[ -z "${ip_addr}" ]] && command_exists hostname; then
    ip_addr="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  fi
  [[ -n "${ip_addr}" ]] && printf '%s' "${ip_addr}" || printf '%s' "127.0.0.1"
}

detect_public_ip() {
  local ip_addr=""
  for url in \
    "https://api.ipify.org" \
    "https://ifconfig.me/ip" \
    "https://ipv4.icanhazip.com"; do
    ip_addr="$(curl -4 -fsSL --max-time 8 "${url}" 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "${ip_addr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      printf '%s' "${ip_addr}"
      return 0
    fi
  done
  detect_local_ip
}

resolve_domain_ipv4s() {
  local domain_name="$1"
  if command_exists getent; then
    getent ahostsv4 "${domain_name}" 2>/dev/null | awk '{print $1}' | sort -u
    return 0
  fi
  if command_exists host; then
    host -t A "${domain_name}" 2>/dev/null | awk '/has address/ {print $4}' | sort -u
    return 0
  fi
  return 1
}

domain_points_here() {
  local domain_name="$1"
  local public_ip local_ip resolved_ip
  public_ip="$(detect_public_ip)"
  local_ip="$(detect_local_ip)"

  while IFS= read -r resolved_ip; do
    [[ -z "${resolved_ip}" ]] && continue
    if [[ "${resolved_ip}" == "${public_ip}" || "${resolved_ip}" == "${local_ip}" ]]; then
      return 0
    fi
  done < <(resolve_domain_ipv4s "${domain_name}")
  return 1
}

validate_domain_for_https() {
  [[ -n "${DOMAIN}" ]] || return 0
  if ! domain_points_here "${DOMAIN}"; then
    local public_ip resolved_ips
    public_ip="$(detect_public_ip)"
    resolved_ips="$(resolve_domain_ipv4s "${DOMAIN}" | paste -sd ',' - || true)"
    [[ -n "${resolved_ips}" ]] || resolved_ips="未解析到 A 记录"
    die "域名 ${DOMAIN} 当前未指向本机。当前公网 IP: ${public_ip}，当前解析: ${resolved_ips}"
  fi
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

prepare_install_values() {
  local default_port default_uri public_ip

  if [[ -z "${INSTALL_DIR}" ]]; then
    INSTALL_DIR="$(suggest_install_dir)"
  fi

  if [[ -z "${PORT}" ]]; then
    PORT="$(find_available_port 8000)"
  fi

  if [[ "${NON_INTERACTIVE}" -eq 0 && ( "${COMMAND}" == "install" || "${FROM_MENU}" -eq 1 ) ]]; then
    INSTALL_DIR="$(prompt_default "安装目录" "${INSTALL_DIR}")"
    VERSION="$(prompt_default "版本（latest 或具体 tag）" "${VERSION}")"
    DOMAIN="$(prompt_default "域名（留空则端口访问）" "${DOMAIN}")"
    PORT="$(prompt_default "监听端口" "${PORT}")"
    APP_NAME="$(prompt_default "应用名称" "${APP_NAME}")"
    if [[ -n "${DOMAIN}" ]]; then
      ACME_EMAIL="$(prompt_default "证书邮箱" "${ACME_EMAIL}")"
    fi
  fi

  validate_port "${PORT}" || die "端口不合法: ${PORT}"

  if [[ -n "${DOMAIN}" ]]; then
    WITH_NGINX="1"
    BIND_ADDR="127.0.0.1"
    [[ -n "${ACME_EMAIL}" ]] || die "配置域名时必须提供证书邮箱"
    validate_domain_for_https
    APP_URI="https://${DOMAIN}"
    ACCESS_URL="${APP_URI}"
  else
    WITH_NGINX="0"
    if [[ -z "${BIND_ADDR}" ]]; then
      BIND_ADDR="0.0.0.0"
    fi
    public_ip="$(detect_public_ip)"
    default_uri="http://${public_ip}:${PORT}"
    APP_URI="${default_uri}"
    ACCESS_URL="${APP_URI}"
  fi

  VERSION="$(normalize_version "${VERSION}")"
  resolve_group
}

prepare_https_values() {
  if [[ "${NON_INTERACTIVE}" -eq 0 && ( "${COMMAND}" == "https" || "${FROM_MENU}" -eq 1 ) ]]; then
    DOMAIN="$(prompt_default "域名" "${DOMAIN}")"
    ACME_EMAIL="$(prompt_default "证书邮箱" "${ACME_EMAIL}")"
  fi

  [[ -n "${DOMAIN}" ]] || die "请先提供域名"
  [[ -n "${ACME_EMAIL}" ]] || die "请先提供证书邮箱"
  [[ -n "${PORT}" ]] || PORT="$(find_available_port 8000)"
  validate_port "${PORT}" || die "端口不合法: ${PORT}"
  BIND_ADDR="127.0.0.1"
  WITH_NGINX="1"
  APP_URI="https://${DOMAIN}"
  ACCESS_URL="${APP_URI}"
  validate_domain_for_https
}

detect_nginx_conf_path() {
  if [[ -n "${NGINX_CONF_PATH}" ]]; then
    printf '%s' "${NGINX_CONF_PATH}"
    return 0
  fi

  local base_dir file_name
  file_name="${SERVICE_NAME}"
  if [[ -n "${DOMAIN}" ]]; then
    file_name="${DOMAIN}"
  fi

  for base_dir in \
    /www/server/panel/vhost/nginx \
    /www/server/nginx/conf/vhost \
    /etc/nginx/conf.d \
    /etc/nginx/sites-enabled; do
    if [[ -d "${base_dir}" ]]; then
      printf '%s/%s.conf' "${base_dir}" "${file_name}"
      return 0
    fi
  done

  return 1
}

nginx_reload() {
  local nginx_bin
  nginx_bin="$(detect_nginx_binary || true)"
  [[ -n "${nginx_bin}" ]] || die "已写入 nginx 配置，但未找到 nginx 可执行文件"

  "${nginx_bin}" -t

  if [[ "${nginx_bin}" == "/www/server/nginx/sbin/nginx" ]]; then
    if pgrep -x nginx >/dev/null 2>&1; then
      "${nginx_bin}" -s reload || die "nginx reload 失败"
    else
      die "检测到宝塔 nginx，但当前 nginx 进程未运行"
    fi
    return 0
  fi

  if systemctl is-active --quiet nginx; then
    systemctl reload nginx
  else
    systemctl start nginx
  fi
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
}

install_release_files() {
  local tmpdir="$1"
  local mode="$2"
  local old_dir=""

  mkdir -p "${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}/runtime"
  mkdir -p "${INSTALL_DIR}/runtime/logs"
  mkdir -p "${INSTALL_DIR}/.old_versions"

  if [[ -f "${INSTALL_DIR}/epusdt" || -d "${INSTALL_DIR}/www" || -f "${INSTALL_DIR}/.env" ]]; then
    old_dir="${INSTALL_DIR}/.old_versions/$(date +%Y%m%d%H%M%S)"
    mkdir -p "${old_dir}"
    [[ -f "${INSTALL_DIR}/epusdt" ]] && cp -f "${INSTALL_DIR}/epusdt" "${old_dir}/epusdt"
    [[ -f "${INSTALL_DIR}/.env" ]] && cp -f "${INSTALL_DIR}/.env" "${old_dir}/.env"
    [[ -d "${INSTALL_DIR}/www" ]] && cp -a "${INSTALL_DIR}/www" "${old_dir}/www"
  fi

  install -m 755 "${tmpdir}/epusdt" "${INSTALL_DIR}/epusdt"
  install -m 644 "${tmpdir}/.env.example" "${INSTALL_DIR}/.env.upstream.example"

  if [[ ! -f "${INSTALL_DIR}/.env" || "${mode}" == "install" ]]; then
    cp -f "${INSTALL_DIR}/.env.upstream.example" "${INSTALL_DIR}/.env"
  fi

  set_env_value "${INSTALL_DIR}/.env" "app_name" "${APP_NAME}"
  set_env_value "${INSTALL_DIR}/.env" "app_uri" "${APP_URI}"
  set_env_value "${INSTALL_DIR}/.env" "http_listen" "${BIND_ADDR}:${PORT}"
  set_env_value "${INSTALL_DIR}/.env" "runtime_root_path" "./runtime"
  set_env_value "${INSTALL_DIR}/.env" "log_save_path" "./runtime/logs"
  set_env_value "${INSTALL_DIR}/.env" "db_type" "sqlite"
  set_env_value "${INSTALL_DIR}/.env" "sqlite_database_filename" ""
  set_env_value "${INSTALL_DIR}/.env" "runtime_sqlite_filename" "epusdt-runtime.db"
  set_env_value "${INSTALL_DIR}/.env" "order_expiration_time" "10"
  set_env_value "${INSTALL_DIR}/.env" "order_notice_max_retry" "1"
  if [[ -n "${API_RATE_URL}" ]]; then
    set_env_value "${INSTALL_DIR}/.env" "api_rate_url" "${API_RATE_URL}"
  fi
  set_env_value "${INSTALL_DIR}/.env" "install" "false"

  chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}"
}

update_release_files() {
  local tmpdir="$1"
  local old_dir=""

  [[ -f "${INSTALL_DIR}/.env" ]] || die "现有 .env 不存在，无法安全更新"

  mkdir -p "${INSTALL_DIR}/.old_versions"
  old_dir="${INSTALL_DIR}/.old_versions/update-$(date +%Y%m%d%H%M%S)"
  mkdir -p "${old_dir}"
  [[ -f "${INSTALL_DIR}/epusdt" ]] && cp -f "${INSTALL_DIR}/epusdt" "${old_dir}/epusdt"
  [[ -d "${INSTALL_DIR}/www" ]] && cp -a "${INSTALL_DIR}/www" "${old_dir}/www"

  install -m 755 "${tmpdir}/epusdt" "${INSTALL_DIR}/epusdt"
  install -m 644 "${tmpdir}/.env.example" "${INSTALL_DIR}/.env.upstream.example"

  chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}"
}

wait_for_http() {
  local url="$1"
  local max_attempts="${2:-40}"
  local attempt=1
  local code=""

  while (( attempt <= max_attempts )); do
    code="$(curl -L -s -o /dev/null -w '%{http_code}' "${url}" || true)"
    if [[ "${code}" =~ ^(200|301|302|307|308)$ ]]; then
      return 0
    fi
    sleep 1
    attempt=$((attempt + 1))
  done

  return 1
}

wait_for_app_api() {
  local url="http://127.0.0.1:${PORT}/admin/api/v1/auth/init-password-hash"
  if wait_for_http "${url}" 80; then
    success "应用接口已就绪"
    return 0
  fi
  die "应用启动后接口未就绪：${url}"
}

json_field() {
  local json="$1"
  local key="$2"
  printf '%s' "${json}" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n1
}

json_status_code() {
  local json="$1"
  printf '%s' "${json}" | sed -n 's/.*"status_code"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -n1
}

fetch_initial_admin_credentials() {
  local response status_code username password
  response="$(curl -fsSL "http://127.0.0.1:${PORT}/admin/api/v1/auth/init-password")"
  status_code="$(json_status_code "${response}")"
  [[ "${status_code}" == "200" ]] || die "获取初始管理员密码失败：${response}"

  username="$(json_field "${response}" "username")"
  password="$(json_field "${response}" "password")"
  [[ -n "${username}" && -n "${password}" ]] || die "初始管理员账号信息解析失败：${response}"

  printf '%s\n%s\n' "${username}" "${password}"
}

verify_admin_login() {
  local username="$1"
  local password="$2"
  local payload response status_code
  payload="$(printf '{"username":"%s","password":"%s"}' "${username}" "${password}")"
  response="$(curl -fsSL \
    -H 'Content-Type: application/json' \
    -X POST \
    -d "${payload}" \
    "http://127.0.0.1:${PORT}/admin/api/v1/auth/login")"
  status_code="$(json_status_code "${response}")"
  [[ "${status_code}" == "200" ]] || die "管理员登录验证失败：${response}"
}

acme_sh_path() {
  printf '%s' "${HOME}/.acme.sh/acme.sh"
}

ensure_acme_installed() {
  local acme_sh
  acme_sh="$(acme_sh_path)"
  if [[ -x "${acme_sh}" ]]; then
    return 0
  fi

  info "安装 acme.sh"
  curl -fsSL https://get.acme.sh | sh -s email="${ACME_EMAIL}"
  [[ -x "${acme_sh}" ]] || die "acme.sh 安装失败"
}

nginx_proxy_block() {
  cat <<EOF
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300;
        proxy_send_timeout 300;
EOF
}

write_nginx_http_config() {
  local conf_path acme_webroot
  conf_path="$(detect_nginx_conf_path)" || die "未找到 nginx 配置目录，请使用 --nginx-conf-path 指定"
  NGINX_CONF_PATH="${conf_path}"
  acme_webroot="/www/wwwroot/_acme/${DOMAIN}"

  mkdir -p "${acme_webroot}/.well-known/acme-challenge"
  mkdir -p "$(dirname "${conf_path}")"
  backup_file_if_exists "${conf_path}"

  cat > "${conf_path}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    client_max_body_size 20m;

    location ^~ /.well-known/acme-challenge/ {
        root ${acme_webroot};
        default_type text/plain;
    }

    location / {
$(nginx_proxy_block)
    }
}
EOF

  nginx_reload
}

write_nginx_https_config() {
  local conf_path cert_dir cert_key cert_fullchain acme_webroot
  conf_path="$(detect_nginx_conf_path)" || die "未找到 nginx 配置目录，请使用 --nginx-conf-path 指定"
  NGINX_CONF_PATH="${conf_path}"
  cert_dir="/etc/ssl/epusdt/${DOMAIN}"
  cert_key="${cert_dir}/privkey.pem"
  cert_fullchain="${cert_dir}/fullchain.pem"
  acme_webroot="/www/wwwroot/_acme/${DOMAIN}"

  mkdir -p "$(dirname "${conf_path}")"
  backup_file_if_exists "${conf_path}"

  cat > "${conf_path}" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location ^~ /.well-known/acme-challenge/ {
        root ${acme_webroot};
        default_type text/plain;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate ${cert_fullchain};
    ssl_certificate_key ${cert_key};
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 20m;

    location / {
$(nginx_proxy_block)
    }
}
EOF

  nginx_reload
  success "HTTPS 已启用并强制跳转"
}

issue_certificate() {
  local acme_sh cert_dir cert_key cert_fullchain nginx_bin acme_webroot
  acme_sh="$(acme_sh_path)"
  cert_dir="/etc/ssl/epusdt/${DOMAIN}"
  cert_key="${cert_dir}/privkey.pem"
  cert_fullchain="${cert_dir}/fullchain.pem"
  nginx_bin="$(detect_nginx_binary)"
  acme_webroot="/www/wwwroot/_acme/${DOMAIN}"

  mkdir -p "${cert_dir}"
  ensure_acme_installed

  "${acme_sh}" --set-default-ca --server letsencrypt >/dev/null
  "${acme_sh}" --register-account -m "${ACME_EMAIL}" --server letsencrypt >/dev/null 2>&1 || true

  info "开始申请证书"
  "${acme_sh}" --issue -d "${DOMAIN}" -w "${acme_webroot}" --server letsencrypt --keylength ec-256
  "${acme_sh}" --install-cert -d "${DOMAIN}" \
    --ecc \
    --key-file "${cert_key}" \
    --fullchain-file "${cert_fullchain}" \
    --reloadcmd "${nginx_bin} -s reload"
}

enable_https_if_needed() {
  [[ -n "${DOMAIN}" ]] || return 0
  write_nginx_http_config
  issue_certificate
  write_nginx_https_config
}

print_install_summary() {
  local username="$1"
  local password="$2"

  success "安装完成"
  printf '\n'
  printf '版本: %s\n' "${VERSION}"
  printf '安装目录: %s\n' "${INSTALL_DIR}"
  printf '服务名: %s\n' "${SERVICE_NAME}"
  printf '监听地址: %s:%s\n' "${BIND_ADDR}" "${PORT}"
  printf '访问地址: %s\n' "${ACCESS_URL}"
  printf '账号: %s\n' "${username}"
  printf '密码: %s\n' "${password}"
  support_info
}

do_install() {
  require_root
  require_systemd
  prepare_install_values

  if [[ -f "${INSTALL_DIR}/epusdt" && "${FORCE}" -ne 1 ]]; then
    die "${INSTALL_DIR} 已存在 epusdt，请使用一键更新；如果要覆盖重装请加 --force"
  fi

  ensure_service_account
  resolve_group
  install_packages "${WITH_NGINX}"

  local tmpdir arch admin_info admin_user admin_pass
  tmpdir="$(mktemp -d)"
  arch="$(detect_arch)"
  trap "cleanup_tmpdir '${tmpdir}'" EXIT

  download_release "${VERSION}" "${arch}" "${tmpdir}"
  install_release_files "${tmpdir}" "install"
  write_systemd_service
  enable_https_if_needed
  systemctl restart "${SERVICE_NAME}.service"
  wait_for_app_api

  admin_info="$(fetch_initial_admin_credentials)"
  admin_user="$(printf '%s' "${admin_info}" | sed -n '1p')"
  admin_pass="$(printf '%s' "${admin_info}" | sed -n '2p')"
  verify_admin_login "${admin_user}" "${admin_pass}"

  if [[ -n "${DOMAIN}" ]]; then
    wait_for_http "https://${DOMAIN}/admin/api/v1/auth/init-password-hash" 20 || warn "外部 HTTPS 检查暂未通过，请确认防火墙和 CDN 配置"
  fi

  save_state
  print_install_summary "${admin_user}" "${admin_pass}"
}

do_update() {
  require_root
  require_systemd

  [[ -x "${INSTALL_DIR}/epusdt" ]] || die "未在 ${INSTALL_DIR} 发现 epusdt"

  VERSION="$(normalize_version "${VERSION}")"
  ensure_service_account
  resolve_group
  install_packages "0"

  local tmpdir arch
  tmpdir="$(mktemp -d)"
  arch="$(detect_arch)"
  trap "cleanup_tmpdir '${tmpdir}'" EXIT

  download_release "${VERSION}" "${arch}" "${tmpdir}"
  update_release_files "${tmpdir}"
  systemctl restart "${SERVICE_NAME}.service"

  if wait_for_http "http://127.0.0.1:${PORT}/admin/api/v1/auth/init-password-hash" 40; then
    success "已更新到 ${VERSION}"
  else
    warn "服务已重启，但接口健康检查未通过"
  fi

  save_state
  printf '访问地址: %s\n' "${ACCESS_URL}"
  support_info
}

do_https() {
  require_root
  require_systemd

  [[ -x "${INSTALL_DIR}/epusdt" ]] || die "未在 ${INSTALL_DIR} 发现 epusdt，请先安装"
  prepare_https_values

  if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    systemctl restart "${SERVICE_NAME}.service"
  fi

  wait_for_app_api
  enable_https_if_needed
  save_state
  printf '访问地址: %s\n' "${ACCESS_URL}"
  support_info
}

do_start() {
  require_root
  systemctl start "${SERVICE_NAME}.service"
  success "服务已启动: ${SERVICE_NAME}"
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
  if [[ -n "${ACCESS_URL}" ]]; then
    printf '访问地址：%s\n' "${ACCESS_URL}"
  fi
  support_info
}

menu_loop() {
  while true; do
    print_banner
    echo "1. 开始部署"
    echo "2. 一键更新"
    echo "3. 配置 HTTPS"
    echo "4. 日常管理"
    echo "5. 检查版本"
    echo "0. 退出"
    echo ""
    local choice=""
    choice="$(prompt_default "请选择" "1")"
    case "${choice}" in
      1)
        FROM_MENU=1
        do_install
        FROM_MENU=0
        ;;
      2) do_update ;;
      3)
        FROM_MENU=1
        do_https
        FROM_MENU=0
        ;;
      4)
        print_banner
        echo "1. 查看服务状态"
        echo "2. 查看日志"
        echo "3. 启动服务"
        echo "4. 重启服务"
        echo "5. 停止服务"
        echo "6. 返回上级菜单"
        echo ""
        local mgmt=""
        mgmt="$(prompt_default "请选择" "1")"
        case "${mgmt}" in
          1) do_status ;;
          2) do_logs ;;
          3) do_start ;;
          4) do_restart ;;
          5) do_stop ;;
          6) ;;
          *) warn "无效选项" ;;
        esac
        ;;
      5) show_version ;;
      0) exit 0 ;;
      *) warn "无效选项" ;;
    esac
    printf '\n'
    read -r -p "按回车继续..." _dummy
  done
}

case "${COMMAND}" in
  menu) menu_loop ;;
  install) do_install ;;
  update) do_update ;;
  https) do_https ;;
  start) do_start ;;
  restart) do_restart ;;
  stop) do_stop ;;
  status) do_status ;;
  logs) do_logs ;;
  version) show_version ;;
  "") menu_loop ;;
  help|-h|--help) usage ;;
  *) die "未知命令: ${COMMAND}，可直接运行进入菜单，或使用 --help 查看命令行参数" ;;
esac
