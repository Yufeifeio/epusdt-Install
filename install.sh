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
  if [[ -n "${cwd}" && "${cwd}" != "/" && "${cwd}" != "/root" && ! "${cwd}" =~ [[:space:]] ]]; then
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
INSTALL_DIR_EXPLICIT=0
SERVICE_NAME_EXPLICIT=0
SERVICE_USER_EXPLICIT=0
SERVICE_GROUP_EXPLICIT=0
BIND_ADDR_EXPLICIT=0
PORT_EXPLICIT=0
DOMAIN_EXPLICIT=0
APP_NAME_EXPLICIT=0
API_RATE_URL_EXPLICIT=0
NGINX_CONF_PATH_EXPLICIT=0
ACME_EMAIL_EXPLICIT=0
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
  BM=$'\033[1;34m'
  C=$'\033[0;36m'
  W=$'\033[1;37m'
  NC=$'\033[0m'
else
  R=''
  G=''
  Y=''
  B=''
  BM=''
  C=''
  W=''
  NC=''
fi

info() { printf "${C}[信息]${NC} %s\n" "$1"; }
warn() { printf "${Y}[警告]${NC} %s\n" "$1"; }
success() { printf "${G}[完成]${NC} %s\n" "$1"; }
error() { printf "${R}[失败]${NC} %s\n" "$1" >&2; }
die() { error "$1"; exit 1; }

print_line() {
  printf '%s\n' "================================================================"
}

supports_utf8() {
  local charset=""
  charset="$(locale charmap 2>/dev/null || true)"
  charset="${charset,,}"
  [[ "${charset}" == "utf-8" || "${charset}" == "utf8" ]]
}

print_plain_banner() {
  printf '\n'
  printf "${B}================================================================${NC}\n"
  printf "${W}  EPUSDT 一键部署与运维脚本${NC}\n"
  printf "${C}  鱼肥肥 @pyufc${NC}\n"
  printf "${C}  联系地址: https://t.me/pyufc${NC}\n"
  printf "${C}  发布仓库: Yufeifeio/epusdt-Install${NC}\n"
  printf "${B}================================================================${NC}\n"
  printf '\n'
}

print_banner() {
  if ! supports_utf8; then
    print_plain_banner
    return 0
  fi

  printf '\n'
  printf '%b\n' "${BM}╔══════════════════════════════════════════════════════════╗${NC}"
  printf '%b\n' "${BM}║             🐟 EPUSDT 一键部署与运维脚本              ║${NC}"
  printf '%b\n' "${BM}║        鱼肥肥 @pyufc   联系: https://t.me/pyufc        ║${NC}"
  printf '%b\n' "${BM}╚══════════════════════════════════════════════════════════╝${NC}"
  printf '%b\n' "${C}███████╗██████╗ ██╗   ██╗███████╗██████╗ ████████╗${NC}"
  printf '%b\n' "${C}██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗╚══██╔══╝${NC}"
  printf '%b\n' "${C}█████╗  ██████╔╝██║   ██║███████╗██║  ██║   ██║   ${NC}"
  printf '%b\n' "${C}██╔══╝  ██╔═══╝ ██║   ██║╚════██║██║  ██║   ██║   ${NC}"
  printf '%b\n' "${C}███████╗██║     ╚██████╔╝███████║██████╔╝   ██║   ${NC}"
  printf '%b\n' "${C}╚══════╝╚═╝      ╚═════╝ ╚══════╝╚═════╝    ╚═╝   ${NC}"
  printf '%b\n' "${W}鱼肥肥 @pyufc  |  发布仓库: Yufeifeio/epusdt-Install${NC}"
  printf '\n'
}

menu_item() {
  local code="$1"
  local title="$2"
  local desc="$3"
  printf "${W} [%s]${NC} %-14s ${C}%s${NC}\n" "${code}" "${title}" "${desc}"
}

support_info() {
  printf '\n'
  printf '鱼肥肥 @pyufc\n'
  printf '联系地址: https://t.me/pyufc\n'
  printf '仓库地址: https://github.com/Yufeifeio/epusdt-Install\n'
}

usage() {
  cat <<'EOF'
用法：
  bash install.sh
  bash install.sh menu
  bash install.sh install [参数]
  bash install.sh update [参数]
  bash install.sh https [参数]
  bash install.sh info
  bash install.sh uninstall [参数]
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
    --install-dir) INSTALL_DIR="$2"; INSTALL_DIR_EXPLICIT=1; shift 2 ;;
    --service-name) SERVICE_NAME="$2"; SERVICE_NAME_EXPLICIT=1; shift 2 ;;
    --service-user) SERVICE_USER="$2"; SERVICE_USER_EXPLICIT=1; shift 2 ;;
    --service-group) SERVICE_GROUP="$2"; SERVICE_GROUP_EXPLICIT=1; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; DOMAIN_EXPLICIT=1; shift 2 ;;
    --port) PORT="$2"; PORT_EXPLICIT=1; shift 2 ;;
    --bind-addr) BIND_ADDR="$2"; BIND_ADDR_EXPLICIT=1; shift 2 ;;
    --app-name) APP_NAME="$2"; APP_NAME_EXPLICIT=1; shift 2 ;;
    --api-rate-url) API_RATE_URL="$2"; API_RATE_URL_EXPLICIT=1; shift 2 ;;
    --nginx-conf-path) NGINX_CONF_PATH="$2"; NGINX_CONF_PATH_EXPLICIT=1; shift 2 ;;
    --acme-email) ACME_EMAIL="$2"; ACME_EMAIL_EXPLICIT=1; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_service_name() {
  local value="$1"
  [[ -n "${value}" ]] || die "服务名不能为空"
  [[ "${value}" =~ ^[A-Za-z0-9_.@-]+$ ]] || die "服务名只能包含字母、数字、点、下划线、横线和 @ 符号: ${value}"
}

validate_account_name() {
  local label="$1"
  local value="$2"
  [[ -n "${value}" ]] || die "${label}不能为空"
  [[ "${value}" != "root" ]] || die "${label}不能使用 root"
  [[ "${value}" =~ ^[A-Za-z0-9_.-]+$ ]] || die "${label}只能包含字母、数字、点、下划线和横线: ${value}"
}

validate_install_dir() {
  local value="$1"
  [[ -n "${value}" ]] || die "安装目录不能为空"
  [[ "${value}" == /* ]] || die "安装目录必须是绝对路径: ${value}"
  [[ "${value}" != "/" ]] || die "安装目录不能是根目录 /"
  [[ ! "${value}" =~ [[:space:]] ]] || die "安装目录不能包含空格，请换一个不带空格的路径: ${value}"
}

validate_runtime_settings() {
  validate_install_dir "${INSTALL_DIR}"
  validate_service_name "${SERVICE_NAME}"
  validate_account_name "服务用户" "${SERVICE_USER}"
  validate_account_name "服务用户组" "${SERVICE_GROUP}"
  [[ -n "${APP_NAME}" ]] || die "应用名称不能为空"
}

service_unit_path() {
  printf '%s' "/etc/systemd/system/${SERVICE_NAME}.service"
}

service_exists() {
  systemctl cat "${SERVICE_NAME}.service" >/dev/null 2>&1
}

has_installation_in_dir() {
  [[ -x "${INSTALL_DIR}/epusdt" || -f "${INSTALL_DIR}/.env" || -d "${INSTALL_DIR}/runtime" ]]
}

prefer_saved_install_dir() {
  local state_dir="${EPUSDT_INSTALL_DIR:-}"
  if [[ "${INSTALL_DIR_EXPLICIT}" -eq 0 ]] && ! has_installation_in_dir; then
    if [[ -n "${state_dir}" && ( -x "${state_dir}/epusdt" || -f "${state_dir}/.env" || -d "${state_dir}/runtime" ) ]]; then
      INSTALL_DIR="${state_dir}"
    fi
  fi
}

ensure_existing_instance() {
  if service_exists || has_installation_in_dir; then
    return 0
  fi
  die "未识别到可管理的实例，请先执行安装，或使用 --install-dir 指定正确目录"
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

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-1}"
  local hint="Y/n"
  local answer=""

  if [[ "${default}" == "0" ]]; then
    hint="y/N"
  fi

  printf '%s [%s]: ' "${prompt}" "${hint}" >&2
  read -r answer
  answer="$(trim "${answer}")"
  answer="${answer,,}"

  if [[ -z "${answer}" ]]; then
    [[ "${default}" == "1" ]]
    return
  fi

  case "${answer}" in
    y|yes|1) return 0 ;;
    n|no|0) return 1 ;;
    *) [[ "${default}" == "1" ]] ;;
  esac
}

pause_if_interactive() {
  if [[ "${FROM_MENU}" -eq 1 ]]; then
    printf '\n'
    read -r -p "按回车继续..." _dummy
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

clear_state_file() {
  rm -f "${STATE_FILE}"
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
  if [[ -x /www/server/nginx/sbin/nginx ]]; then
    printf '%s' "/www/server/nginx/sbin/nginx"
    return 0
  fi
  if command_exists nginx; then
    command -v nginx
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
  local response=""
  response="$(curl -fsSL "${REPO_API_URL}" 2>/dev/null)" || die "获取官方最新版本失败，请检查 GitHub 连通性"
  printf '%s' "${response}" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
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
  curl -fsSL -o "${tmpdir}/${asset_name}" "${asset_url}" || die "下载失败: ${asset_url}"
  curl -fsSL -o "${tmpdir}/SHA256SUMS" "${sums_url}" || die "下载校验文件失败: ${sums_url}"

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

load_runtime_state_from_env() {
  prefer_saved_install_dir
  local env_file="${INSTALL_DIR}/.env"
  local uri host port_from_env bind_from_env app_name_from_env api_rate_from_env

  [[ -f "${env_file}" ]] || return 0

  uri="$(sed -n 's/^app_uri=//p' "${env_file}" | tail -n1)"
  [[ -n "${uri}" ]] && ACCESS_URL="${uri}"

  if [[ "${PORT_EXPLICIT}" -eq 0 ]]; then
    port_from_env="$(sed -n 's/^http_listen=.*:\([0-9][0-9]*\)$/\1/p' "${env_file}" | tail -n1)"
    [[ -n "${port_from_env}" ]] && PORT="${port_from_env}"
  fi

  if [[ "${BIND_ADDR_EXPLICIT}" -eq 0 ]]; then
    bind_from_env="$(sed -n 's/^http_listen=\([^:]*\):[0-9][0-9]*$/\1/p' "${env_file}" | tail -n1)"
    [[ -n "${bind_from_env}" ]] && BIND_ADDR="${bind_from_env}"
  fi

  if [[ "${APP_NAME_EXPLICIT}" -eq 0 ]]; then
    app_name_from_env="$(sed -n 's/^app_name=//p' "${env_file}" | tail -n1)"
    [[ -n "${app_name_from_env}" ]] && APP_NAME="${app_name_from_env}"
  fi

  if [[ "${API_RATE_URL_EXPLICIT}" -eq 0 ]]; then
    api_rate_from_env="$(sed -n 's/^api_rate_url=//p' "${env_file}" | tail -n1)"
    [[ -n "${api_rate_from_env}" ]] && API_RATE_URL="${api_rate_from_env}"
  fi

  if [[ "${DOMAIN_EXPLICIT}" -eq 0 && -n "${ACCESS_URL}" ]]; then
    host="$(printf '%s' "${ACCESS_URL}" | sed -n 's#^https\?://\([^/:]*\).*$#\1#p')"
    if [[ -n "${host}" && ! "${host}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      DOMAIN="${host}"
    else
      DOMAIN=""
    fi
  fi
}

prepare_install_values() {
  local public_ip default_uri

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

  resolve_group
  validate_runtime_settings
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
    if [[ "${BIND_ADDR_EXPLICIT}" -eq 0 ]]; then
      BIND_ADDR="0.0.0.0"
    fi
    public_ip="$(detect_public_ip)"
    default_uri="http://${public_ip}:${PORT}"
    APP_URI="${default_uri}"
    ACCESS_URL="${APP_URI}"
  fi

  VERSION="$(normalize_version "${VERSION}")"
}

prepare_https_values() {
  load_runtime_state_from_env

  if [[ "${NON_INTERACTIVE}" -eq 0 && ( "${COMMAND}" == "https" || "${FROM_MENU}" -eq 1 ) ]]; then
    DOMAIN="$(prompt_default "域名" "${DOMAIN}")"
    ACME_EMAIL="$(prompt_default "证书邮箱" "${ACME_EMAIL}")"
  fi

  [[ -n "${DOMAIN}" ]] || die "请先提供域名"
  [[ -n "${ACME_EMAIL}" ]] || die "请先提供证书邮箱"
  [[ -n "${PORT}" ]] || PORT="$(find_available_port 8000)"
  resolve_group
  validate_runtime_settings
  validate_port "${PORT}" || die "端口不合法: ${PORT}"
  BIND_ADDR="127.0.0.1"
  WITH_NGINX="1"
  APP_URI="https://${DOMAIN}"
  ACCESS_URL="${APP_URI}"
  validate_domain_for_https
}

detect_nginx_conf_path() {
  if [[ "${NGINX_CONF_PATH_EXPLICIT}" -eq 1 && -n "${NGINX_CONF_PATH}" ]]; then
    validate_explicit_nginx_conf_path
    printf '%s' "${NGINX_CONF_PATH}"
    return 0
  fi

  local base_dir file_name
  file_name="${SERVICE_NAME}"
  if [[ -n "${DOMAIN}" ]]; then
    file_name="${DOMAIN}"
  fi

  while IFS= read -r base_dir; do
    [[ -d "${base_dir}" ]] || continue
    printf '%s/%s.conf' "${base_dir}" "${file_name}"
    return 0
  done < <(nginx_loaded_conf_dirs)

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

nginx_loaded_conf_dirs() {
  local nginx_bin config_dump include_path include_dir
  nginx_bin="$(detect_nginx_binary || true)"
  [[ -n "${nginx_bin}" ]] || return 0
  config_dump="$("${nginx_bin}" -T 2>/dev/null || true)"
  [[ -n "${config_dump}" ]] || return 0

  config_dump="$(printf '%s\n' "${config_dump}" | awk '
    /^[[:space:]]*http[[:space:]]*\{/ { in_http=1; depth=1; print; next }
    in_http {
      opens=gsub(/\{/, "{")
      closes=gsub(/\}/, "}")
      depth += opens - closes
      print
      if (depth <= 0) {
        in_http=0
        depth=0
      }
    }
  ')"
  [[ -n "${config_dump}" ]] || return 0

  while IFS= read -r include_path; do
    include_path="$(printf '%s' "${include_path}" | sed 's/^[[:space:]]*include[[:space:]]\+//; s/;[[:space:]]*$//')"
    include_dir="${include_path%/*}"
    [[ -n "${include_dir}" && "${include_dir}" == /* ]] || continue
    printf '%s\n' "${include_dir}"
  done < <(printf '%s\n' "${config_dump}" | sed -n 's/^[[:space:]]*include[[:space:]].*;/&/p') | awk '!seen[$0]++'
}

validate_explicit_nginx_conf_path() {
  local target_dir loaded_dir loaded_dirs=""
  target_dir="$(dirname "${NGINX_CONF_PATH}")"

  while IFS= read -r loaded_dir; do
    [[ -n "${loaded_dir}" ]] || continue
    loaded_dirs+="${loaded_dir} "
    if [[ "${loaded_dir}" == "${target_dir}" ]]; then
      return 0
    fi
  done < <(nginx_loaded_conf_dirs)

  loaded_dirs="$(trim "${loaded_dirs}")"
  if [[ -z "${loaded_dirs}" ]]; then
    warn "未能自动识别当前 Nginx 的已加载目录，将继续使用你指定的配置路径: ${NGINX_CONF_PATH}"
    return 0
  fi

  die "你指定的 Nginx 配置路径未被当前 Nginx 主配置加载: ${NGINX_CONF_PATH}。当前已加载目录: ${loaded_dirs}"
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
  local unit_path
  unit_path="$(service_unit_path)"
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

  # Remove generated and stale artifacts so the new version starts cleanly.
  rm -rf "${INSTALL_DIR}/www"
  rm -f "${INSTALL_DIR}/.env.example" "${INSTALL_DIR}/SHA256SUMS"
  find "${INSTALL_DIR}" -maxdepth 1 -type f \( -name 'epusdt-*.tar.gz' -o -name 'SHA256SUMS*' \) -delete 2>/dev/null || true

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
  response="$(curl -fsSL "http://127.0.0.1:${PORT}/admin/api/v1/auth/init-password" 2>/dev/null)" || die "获取后台初始账号密码失败，请检查应用日志"
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
    "http://127.0.0.1:${PORT}/admin/api/v1/auth/login" 2>/dev/null)" || die "后台登录验证失败，请检查应用日志"
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
    listen 443 ssl;
    http2 on;
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

service_status_label() {
  if systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    printf '%s' "运行中"
  elif service_exists; then
    printf '%s' "已停止"
  elif has_installation_in_dir; then
    printf '%s' "目录存在，服务缺失"
  else
    printf '%s' "未安装"
  fi
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

show_info() {
  local local_version="未知"
  local latest_version="未知"
  local current_state=""
  local version_output=""

  load_runtime_state_from_env

  if [[ -x "${INSTALL_DIR}/epusdt" ]]; then
    version_output="$("${INSTALL_DIR}/epusdt" version 2>/dev/null || true)"
    local_version="$(printf '%s\n' "${version_output}" | sed -n 's/^version: //p' | head -n1)"
    [[ -n "${local_version}" ]] || local_version="未知"
  fi

  latest_version="$(get_latest_version 2>/dev/null || true)"
  [[ -n "${latest_version}" ]] || latest_version="未知"
  current_state="$(service_status_label)"

  print_banner
  printf '实例信息\n'
  print_line
  printf '安装目录: %s\n' "${INSTALL_DIR}"
  printf '服务名: %s\n' "${SERVICE_NAME}"
  printf '服务状态: %s\n' "${current_state}"
  printf '当前版本: %s\n' "${local_version}"
  printf '最新版本: %s\n' "${latest_version}"
  [[ -n "${PORT}" ]] && printf '监听端口: %s\n' "${PORT}"
  [[ -n "${ACCESS_URL}" ]] && printf '访问地址: %s\n' "${ACCESS_URL}"
  [[ -n "${DOMAIN}" ]] && printf '域名: %s\n' "${DOMAIN}"
  [[ -n "${NGINX_CONF_PATH}" ]] && printf 'Nginx 配置: %s\n' "${NGINX_CONF_PATH}"
  support_info
}

do_install() {
  require_root
  require_systemd
  prepare_install_values

  if [[ -f "${INSTALL_DIR}/epusdt" && "${FORCE}" -ne 1 ]]; then
    die "${INSTALL_DIR} 已存在 epusdt，请使用一键更新；如果要覆盖重装请加 --force"
  fi

  if service_exists && [[ "${FORCE}" -ne 1 ]]; then
    die "服务 ${SERVICE_NAME} 已存在，请更换服务名，或确认后使用 --force 覆盖"
  fi

  if service_exists; then
    systemctl stop "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
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
  load_runtime_state_from_env
  ensure_existing_instance
  service_exists || die "未找到服务 ${SERVICE_NAME}，无法执行更新，请先完成安装或修复服务"
  resolve_group
  validate_runtime_settings

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

  if [[ -n "${PORT}" ]] && wait_for_http "http://127.0.0.1:${PORT}/admin/api/v1/auth/init-password-hash" 40; then
    success "已更新到 ${VERSION}"
  else
    warn "服务已重启，但接口健康检查未通过"
  fi

  save_state
  printf '已清理: 旧版前端目录、上游示例环境文件、校验文件、遗留安装包\n'
  [[ -n "${ACCESS_URL}" ]] && printf '访问地址: %s\n' "${ACCESS_URL}"
  support_info
}

do_https() {
  require_root
  require_systemd
  load_runtime_state_from_env
  ensure_existing_instance
  [[ -x "${INSTALL_DIR}/epusdt" ]] || die "未在 ${INSTALL_DIR} 发现 epusdt，请先安装"
  service_exists || die "未找到服务 ${SERVICE_NAME}，无法配置 HTTPS，请先完成安装或修复服务"
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

do_uninstall() {
  require_root
  require_systemd
  load_runtime_state_from_env
  ensure_existing_instance
  resolve_group
  validate_runtime_settings

  local remove_dir=1
  local remove_https=1
  local remove_user=1
  local cert_dir=""
  local acme_webroot=""
  local removed_nginx=0

  cert_dir="/etc/ssl/epusdt/${DOMAIN}"
  acme_webroot="/www/wwwroot/_acme/${DOMAIN}"

  if [[ "${NON_INTERACTIVE}" -eq 0 ]]; then
    print_banner
    printf '即将卸载当前实例\n'
    print_line
    printf '安装目录: %s\n' "${INSTALL_DIR}"
    printf '服务名: %s\n' "${SERVICE_NAME}"
    [[ -n "${ACCESS_URL}" ]] && printf '访问地址: %s\n' "${ACCESS_URL}"
    [[ -n "${DOMAIN}" ]] && printf '域名: %s\n' "${DOMAIN}"
    print_line
    prompt_yes_no "删除安装目录和全部数据" 1 && remove_dir=1 || remove_dir=0
    if [[ -n "${DOMAIN}" ]]; then
      prompt_yes_no "删除 HTTPS 配置和证书" 1 && remove_https=1 || remove_https=0
    else
      remove_https=0
    fi
    prompt_yes_no "删除服务用户 ${SERVICE_USER}" 1 && remove_user=1 || remove_user=0
  else
    [[ "${FORCE}" -eq 1 ]] || die "非交互卸载请加 --force"
  fi

  if service_exists; then
    systemctl stop "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
    systemctl disable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
  fi

  rm -f "$(service_unit_path)"
  systemctl daemon-reload

  if [[ "${remove_https}" -eq 1 ]]; then
    if [[ "${NGINX_CONF_PATH_EXPLICIT}" -eq 0 ]]; then
      NGINX_CONF_PATH=""
    fi
    if [[ -z "${NGINX_CONF_PATH}" ]]; then
      NGINX_CONF_PATH="$(detect_nginx_conf_path || true)"
    fi
    if [[ -n "${NGINX_CONF_PATH}" && -f "${NGINX_CONF_PATH}" ]]; then
      rm -f "${NGINX_CONF_PATH}"
      removed_nginx=1
    fi
    [[ -d "${cert_dir}" ]] && rm -rf "${cert_dir}"
    [[ -d "${acme_webroot}" ]] && rm -rf "${acme_webroot}"
  fi

  if [[ "${remove_dir}" -eq 1 && -d "${INSTALL_DIR}" ]]; then
    rm -rf "${INSTALL_DIR}"
  fi

  if [[ "${remove_user}" -eq 1 && "$(id -u "${SERVICE_USER}" >/dev/null 2>&1; printf '%s' "$?")" == "0" ]]; then
    userdel "${SERVICE_USER}" >/dev/null 2>&1 || true
  fi

  if [[ "${removed_nginx}" -eq 1 ]] && detect_nginx_binary >/dev/null 2>&1; then
    nginx_reload || warn "Nginx 配置已删除，但重载失败，请手动重载"
  fi

  clear_state_file
  success "卸载完成"
  support_info
}

do_start() {
  require_root
  require_systemd
  service_exists || die "未找到服务 ${SERVICE_NAME}，请先完成安装"
  systemctl start "${SERVICE_NAME}.service"
  success "服务已启动: ${SERVICE_NAME}"
  support_info
}

do_restart() {
  require_root
  require_systemd
  service_exists || die "未找到服务 ${SERVICE_NAME}，请先完成安装"
  systemctl restart "${SERVICE_NAME}.service"
  success "服务已重启: ${SERVICE_NAME}"
  support_info
}

do_stop() {
  require_root
  require_systemd
  service_exists || die "未找到服务 ${SERVICE_NAME}，请先完成安装"
  systemctl stop "${SERVICE_NAME}.service"
  success "服务已停止: ${SERVICE_NAME}"
  support_info
}

do_status() {
  require_systemd
  service_exists || die "未找到服务 ${SERVICE_NAME}，请先完成安装"
  systemctl status "${SERVICE_NAME}.service" --no-pager
}

do_logs() {
  require_systemd
  service_exists || die "未找到服务 ${SERVICE_NAME}，请先完成安装"
  journalctl -u "${SERVICE_NAME}.service" -n 200 --no-pager
}

menu_manage() {
  while true; do
    print_banner
    menu_item "1" "查看状态" "systemd 当前状态"
    menu_item "2" "查看日志" "最近 200 行日志"
    menu_item "3" "启动服务" "启动当前实例"
    menu_item "4" "重启服务" "重启当前实例"
    menu_item "5" "停止服务" "停止当前实例"
    menu_item "0" "返回上级" "返回主菜单"
    printf '\n'

    local mgmt=""
    mgmt="$(prompt_default "请选择" "1")"
    case "${mgmt}" in
      1) do_status ;;
      2) do_logs ;;
      3) do_start ;;
      4) do_restart ;;
      5) do_stop ;;
      0) return 0 ;;
      *) warn "无效选项" ;;
    esac
    pause_if_interactive
  done
}

menu_loop() {
  while true; do
    print_banner
    menu_item "1" "开始部署" "自动安装并回显后台账号密码"
    menu_item "2" "一键更新" "拉取官方最新 release"
    menu_item "3" "配置 HTTPS" "申请证书并强制跳转 https"
    menu_item "4" "运行管理" "状态 / 日志 / 启停 / 重启"
    menu_item "5" "实例信息" "目录 / 版本 / 地址 / 服务状态"
    menu_item "6" "一键卸载" "删除服务与部署文件"
    menu_item "0" "退出脚本" "结束本次操作"
    printf '\n'

    local choice=""
    choice="$(prompt_default "请选择" "1")"
    case "${choice}" in
      1)
        FROM_MENU=1
        do_install
        pause_if_interactive
        ;;
      2)
        FROM_MENU=1
        do_update
        pause_if_interactive
        ;;
      3)
        FROM_MENU=1
        do_https
        pause_if_interactive
        ;;
      4)
        FROM_MENU=1
        menu_manage
        ;;
      5)
        FROM_MENU=1
        show_info
        pause_if_interactive
        ;;
      6)
        FROM_MENU=1
        do_uninstall
        pause_if_interactive
        ;;
      0) exit 0 ;;
      *) warn "无效选项" ;;
    esac
  done
}

case "${COMMAND}" in
  menu) menu_loop ;;
  install) do_install ;;
  update) do_update ;;
  https) do_https ;;
  info|version) show_info ;;
  uninstall) do_uninstall ;;
  start) do_start ;;
  restart) do_restart ;;
  stop) do_stop ;;
  status) do_status ;;
  logs) do_logs ;;
  "") menu_loop ;;
  help|-h|--help) usage ;;
  *) die "未知命令: ${COMMAND}，可直接运行进入菜单，或使用 --help 查看命令行参数" ;;
esac
