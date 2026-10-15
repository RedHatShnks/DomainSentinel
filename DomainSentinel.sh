#!/usr/bin/env bash
# ==============================================================================
# DomainSentinel.sh
# Advanced Domain Reconnaissance & OSINT
# Version: 1.3.1
# Usage:   ./DomainSentinel.sh <domain> [output_base]
#          ./DomainSentinel.sh                     (interactive)
# ==============================================================================

set -o pipefail
shopt -s nullglob

# ------------------------------------------------------------------------------
# Metadata
# ------------------------------------------------------------------------------
readonly DS_NAME="DomainSentinel"
readonly DS_VERSION="1.3.1"
readonly DS_TAGLINE="Domain Reconnaissance & OSINT"
readonly DS_DEFAULT_OUT="./domainsentinel-results"
readonly DS_TIMEOUT_NET=15
readonly DS_TIMEOUT_LONG=45
readonly DS_TIMEOUT_SUBFINDER=180
readonly DS_GEO_BATCH_URL="http://ip-api.com/batch"
readonly DS_GEO_BATCH_MAX=100
readonly DS_GEO_FIELDS="status,message,query,city,regionName,country,isp,org,as,reverse"

# ------------------------------------------------------------------------------
# State
# ------------------------------------------------------------------------------
DS_DOMAIN=""
DS_ROOT=""
DS_DIR=""
DS_START_EPOCH=0
DS_END_EPOCH=0
DS_TMPDIR=""
DS_CLEANUP=()
DS_QUIET=0
DS_VERBOSE=0

declare -A DS_STAGE_STATE=(
    [1]="pending" [2]="pending" [3]="pending"
    [4]="pending" [5]="pending" [6]="pending"
)
declare -A DS_STAGE_COUNT=(
    [1]="0" [2]="0" [3]="0" [4]="0" [5]="0" [6]="0"
)
declare -A DS_STAGE_STARTED=(
    [1]="" [2]="" [3]="" [4]="" [5]="" [6]=""
)

# ------------------------------------------------------------------------------
# Colors
# ------------------------------------------------------------------------------
DS_USE_COLOR=0
[[ -t 1 ]] && DS_USE_COLOR=1

if (( DS_USE_COLOR )); then
    C_RST=$'\033[0m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
    C_BLU=$'\033[0;34m'; C_MAG=$'\033[0;35m'; C_CYN=$'\033[0;36m'
    C_WHT=$'\033[0;37m'
else
    C_RST=""; C_BLD=""; C_DIM=""; C_RED=""; C_GRN=""
    C_YEL=""; C_BLU=""; C_MAG=""; C_CYN=""; C_WHT=""
fi

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------
ds_ts() { date '+%H:%M:%S'; }

ds_num() {
    local v="${1:-0}"
    v="${v//[$'\r\n\t ']/}"
    [[ "$v" =~ ^[0-9]+$ ]] || v=0
    printf '%s' "$v"
}

ds_log() {
    local lvl="$1"; shift
    local msg="$*"
    local ts; ts="$(ds_ts)"
    (( DS_QUIET )) && [[ "$lvl" != "ERR" ]] && return 0
    case "$lvl" in
        INFO) : ;;
        OK)   printf '  %s[%s] ✔%s %s\n' "$C_GRN" "$ts" "$C_RST" "$msg" ;;
        WARN) printf '  %s[%s] !%s %s\n' "$C_YEL" "$ts" "$C_RST" "$msg" ;;
        ERR)  printf '  %s[%s] ✘%s %s\n' "$C_RED" "$ts" "$C_RST" "$msg" ;;
        DBG)  (( DS_VERBOSE )) && printf '  %s[%s] ·%s %s\n' "$C_DIM" "$ts" "$C_RST" "$msg" ;;
        *)    : ;;
    esac
    if [[ -n "$DS_DIR" && -d "$DS_DIR" ]]; then
        printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$lvl" "$msg" >> "$DS_DIR/recon.log"
    fi
}
ds_info()  { ds_log INFO "$@"; }
ds_ok()    { ds_log OK   "$@"; }
ds_warn()  { ds_log WARN "$@"; }
ds_err()   { ds_log ERR  "$@"; }
ds_dbg()   { ds_log DBG  "$@"; }

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
ds_cleanup() {
    local f
    for f in "${DS_CLEANUP[@]}"; do [[ -f "$f" ]] && rm -f "$f"; done
    [[ -n "$DS_TMPDIR" && -d "$DS_TMPDIR" ]] && rm -rf "$DS_TMPDIR"
}
trap ds_cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
ds_banner() {
    printf '%s' "$C_CYN"
    cat <<'BANNER'

   ╔═══════════════════════════════════════════════════════════════════╗
   ║                                                                   ║
   ║   ██████╗  ██████╗ ███╗   ███╗ █████╗ ██╗███╗   ██╗               ║
   ║   ██╔══██╗██╔═══██╗████╗ ████║██╔══██╗██║████╗  ██║               ║
   ║   ██║  ██║██║   ██║██╔████╔██║███████║██║██╔██╗ ██║               ║
   ║   ██║  ██║██║   ██║██║╚██╔╝██║██╔══██║██║██║╚██╗██║               ║
   ║   ██████╔╝╚██████╔╝██║ ╚═╝ ██║██║  ██║██║██║ ╚████║               ║
   ║   ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝               ║
   ║                                                                   ║
   ║   ███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗      ║
   ║   ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║      ║
   ║   ███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║      ║
   ║   ╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║      ║
   ║   ███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗ ║
   ║   ╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝ ║
   ║                                                                   ║
   ╚═══════════════════════════════════════════════════════════════════╝
BANNER
    printf '%s' "$C_RST"
    printf '   %s%s%s\n' "$C_BLD" "$DS_TAGLINE" "$C_RST"
    printf '   %sv%s%s\n\n' "$C_DIM" "$DS_VERSION" "$C_RST"
}

# ------------------------------------------------------------------------------
# Prompts
# ------------------------------------------------------------------------------
ds_ask_target() {
    local input
    printf '   %s[?]%s Target domain (e.g. example.com): ' "$C_BLD" "$C_RST" >&2
    read -r input || exit 1
    printf '%s' "$input"
}

ds_ask_output_base() {
    local input
    printf '   %s[?]%s Output base [%s]: ' "$C_BLD" "$C_RST" "$DS_DEFAULT_OUT" >&2
    read -r input || exit 1
    [[ -z "$input" ]] && input="$DS_DEFAULT_OUT"
    printf '%s' "$input"
}

ds_confirm() {
    local prompt="$1" ans
    printf '   %s[?]%s %s [y/N]: ' "$C_BLD" "$C_RST" "$prompt" >&2
    read -r ans || exit 1
    [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

# ------------------------------------------------------------------------------
# Domain validation
# ------------------------------------------------------------------------------
ds_validate_domain() {
    local d="$1"
    [[ -z "$d" ]] && return 1
    d="${d%.}"
    [[ "$d" == *"://"* || "$d" == */* || "$d" == *@* || "$d" == *:* ]] && return 1
    [[ "$d" =~ [[:space:]] ]] && return 1
    [[ "$d" =~ [\;\|\&\$\`\'\"\<\>\(\)\{\}\[\]\!\*\?] ]] && return 1
    (( ${#d} > 253 )) && return 1
    [[ "$d" == *.* ]] || return 1
    [[ "$d" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ ]] || return 1
    printf '%s' "${d,,}"
}

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------
declare -A DS_DEP_STATUS=()
declare -A DS_DEP_CMD=(
    [subfinder]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    [httpx]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
    [subzy]="github.com/PentestPad/subzy@latest"
    [waybackurls]="github.com/tomnomnom/waybackurls@latest"
    [dnsx]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
)
declare -a DS_PKG_DEPS=(curl jq dig whois)

ds_pkg_mgr() {
    if command -v apt-get >/dev/null 2>&1; then echo apt-get
    elif command -v dnf    >/dev/null 2>&1; then echo dnf
    elif command -v yum    >/dev/null 2>&1; then echo yum
    elif command -v pacman >/dev/null 2>&1; then echo pacman
    else echo ""; fi
}

ds_pkg_name() {
    case "$1" in
        dig) echo "dnsutils" ;;
        *)   echo "$1" ;;
    esac
}

ds_pkg_install() {
    local name="$1" pm; pm="$(ds_pkg_mgr)"
    [[ -z "$pm" ]] && { ds_err "No supported package manager."; return 1; }
    local pkg; pkg="$(ds_pkg_name "$name")"
    case "$pm" in
        apt-get) sudo apt-get update -qq && sudo apt-get install -y "$pkg" ;;
        dnf|yum) sudo "$pm" install -y "$pkg" ;;
        pacman)  sudo pacman -Sy --noconfirm "$pkg" ;;
    esac
}

ds_ensure_go() {
    command -v go >/dev/null 2>&1 && return 0
    local pm; pm="$(ds_pkg_mgr)"
    case "$pm" in
        apt-get) sudo apt-get update -qq && sudo apt-get install -y golang-go ;;
        dnf|yum) sudo "$pm" install -y golang ;;
        pacman)  sudo pacman -Sy --noconfirm go ;;
        *)       ds_err "Cannot install Go automatically."; return 1 ;;
    esac
    command -v go >/dev/null 2>&1
}

ds_go_env() {
    export GOPATH="${GOPATH:-$HOME/go}"
    export PATH="$GOPATH/bin:$HOME/go/bin:$PATH"
}

ds_is_pd_httpx() {
    local bin="$1"
    [[ -x "$bin" ]] || return 1
    "$bin" -version 2>&1 | grep -qi projectdiscovery
}

ds_find_pd_httpx() {
    local c
    for c in "$GOPATH/bin/httpx" "$HOME/go/bin/httpx" "/root/go/bin/httpx" \
             "$(command -v httpx 2>/dev/null)"; do
        [[ -n "$c" && -x "$c" ]] || continue
        ds_is_pd_httpx "$c" && { printf '%s' "$c"; return 0; }
    done
    return 1
}

ds_install_go_tool() {
    local name="$1" pkg="${DS_DEP_CMD[$1]}"
    ds_ensure_go || { ds_err "Go unavailable."; return 1; }
    ds_go_env
    go install "$pkg" 2>&1 | tail -n 2
    ds_go_env
    hash -r 2>/dev/null || true
    command -v "$name" >/dev/null 2>&1
}

ds_check_dep() {
    local name="$1" optional="${2:-0}"
    if [[ "$name" == "httpx" ]]; then
        if ds_find_pd_httpx >/dev/null; then
            DS_DEP_STATUS[$name]="ok"
            printf '   %s✔%s %s\n' "$C_GRN" "$C_RST" "$name"
            return 0
        fi
        ds_install_go_tool httpx || { DS_DEP_STATUS[$name]="failed"; return 1; }
        ds_find_pd_httpx >/dev/null || { DS_DEP_STATUS[$name]="failed"; return 1; }
        DS_DEP_STATUS[$name]="ok"
        printf '   %s✔%s %s %s(installed)%s\n' "$C_GRN" "$C_RST" "$name" "$C_DIM" "$C_RST"
        return 0
    fi
    if printf '%s\n' "${DS_PKG_DEPS[@]}" | grep -qx "$name"; then
        if command -v "$name" >/dev/null 2>&1; then
            DS_DEP_STATUS[$name]="ok"
            printf '   %s✔%s %s\n' "$C_GRN" "$C_RST" "$name"
            return 0
        fi
        ds_pkg_install "$name" || { DS_DEP_STATUS[$name]="failed"; return 1; }
        if command -v "$name" >/dev/null 2>&1; then
            DS_DEP_STATUS[$name]="ok"
            printf '   %s✔%s %s %s(installed)%s\n' "$C_GRN" "$C_RST" "$name" "$C_DIM" "$C_RST"
            return 0
        fi
        DS_DEP_STATUS[$name]="failed"
        return 1
    fi
    if [[ -n "${DS_DEP_CMD[$name]}" ]]; then
        if command -v "$name" >/dev/null 2>&1; then
            DS_DEP_STATUS[$name]="ok"
            printf '   %s✔%s %s\n' "$C_GRN" "$C_RST" "$name"
            return 0
        fi
        if (( optional )); then
            DS_DEP_STATUS[$name]="skip"
            return 0
        fi
        ds_install_go_tool "$name" || { DS_DEP_STATUS[$name]="failed"; return 1; }
        if command -v "$name" >/dev/null 2>&1; then
            DS_DEP_STATUS[$name]="ok"
            printf '   %s✔%s %s %s(installed)%s\n' "$C_GRN" "$C_RST" "$name" "$C_DIM" "$C_RST"
            return 0
        fi
        DS_DEP_STATUS[$name]="failed"
        return 1
    fi
    DS_DEP_STATUS[$name]="unknown"
    return 1
}

ds_check_all_deps() {
    printf '\n   %sDependencies%s\n' "$C_BLD" "$C_RST"
    ds_go_env
    local t
    for t in curl jq dig whois subfinder httpx subzy waybackurls; do
        ds_check_dep "$t" 0 || true
    done
    ds_check_dep dnsx 1 || true
    local failed=0 name
    for name in curl jq dig whois; do
        [[ "${DS_DEP_STATUS[$name]:-failed}" != "ok" ]] && failed=1
    done
    return $failed
}

# ------------------------------------------------------------------------------
# Stage helpers
# ------------------------------------------------------------------------------
ds_stage_set() {
    DS_STAGE_STATE[$1]="$2"
    DS_STAGE_COUNT[$1]="$(ds_num "${3:-${DS_STAGE_COUNT[$1]}}")"
}

ds_stage_header() {
    local n="$1" label="$2"
    DS_STAGE_STARTED[$n]="$(ds_ts)"
    printf '\n   %s▸ Stage %d/6%s  %s\n' "$C_MAG" "$n" "$C_RST" "$label"
    printf '  %s[%s] Started %s%s\n' "$C_DIM" "${DS_STAGE_STARTED[$n]}" "$label" "$C_RST"
    ds_info "Stage $n/6 started: $label"
}

ds_stage_done() {
    local n="$1" state="$2" detail="$3"
    ds_stage_set "$n" "$state"
    case "$state" in
        completed)   printf '  %s✔%s %s\n'   "$C_GRN" "$C_RST" "$detail" ;;
        no_results)  printf '  %s·%s %s\n'   "$C_DIM" "$C_RST" "$detail" ;;
        partial)     printf '  %s!%s %s\n'   "$C_YEL" "$C_RST" "$detail" ;;
        failed)      printf '  %s✘%s %s\n'   "$C_RED" "$C_RST" "$detail" ;;
        skipped)     printf '  %s- %s%s\n'   "$C_DIM" "$detail" "$C_RST" ;;
        *)           printf '  %s%s%s\n'    "$C_DIM" "$detail" "$C_RST" ;;
    esac
    printf '  %s[%s] Finished%s\n' "$C_DIM" "$(ds_ts)" "$C_RST"
    printf '  %sstate=%s detail=%s%s\n' "$C_DIM" "$state" "$detail" "$C_RST"
    ds_info "Stage $n/6 finished: state=$state detail=$detail"
}

# ------------------------------------------------------------------------------
# HTTP status helper
# ------------------------------------------------------------------------------
ds_http_status() {
    local raw="$1"
    raw="$(printf '%s' "$raw" | tr -dc '0-9')"
    raw="${raw: -3}"
    [[ -z "$raw" ]] && raw="000"
    printf '%s' "$raw"
}

# ------------------------------------------------------------------------------
# Wildcard DNS detector
# ------------------------------------------------------------------------------
ds_wildcard_dns_ip() {
    local probe="ds-wildcard-probe-$RANDOM.$DS_DOMAIN"
    local ip
    ip="$(dig +short A "$probe" 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)"
    printf '%s' "$ip"
}

# ------------------------------------------------------------------------------
# Stage 1 — Subdomains
# ------------------------------------------------------------------------------
ds_stage1_subdomains() {
    ds_stage_header 1 "Subdomain enumeration"
    : > "$DS_DIR/subfinder.txt"
    : > "$DS_DIR/crtsh.txt"
    : > "$DS_DIR/subdomains.txt"

    local sf_count=0 ct_count=0

    if [[ "${DS_DEP_STATUS[subfinder]:-failed}" == "ok" ]]; then
        timeout "$DS_TIMEOUT_SUBFINDER" subfinder -d "$DS_DOMAIN" -silent -all \
            2>>"$DS_DIR/recon.log" \
            | tr '[:upper:]' '[:lower:]' \
            | sort -u > "$DS_DIR/subfinder.txt" || true
        sf_count="$(ds_num "$(wc -l < "$DS_DIR/subfinder.txt" 2>/dev/null)")"
    fi

    local ct_d; ct_d="$(mktemp)"; DS_CLEANUP+=("$ct_d")
    local http_d
    http_d="$(curl -sS -o "$ct_d" -w '%{http_code}' \
        --max-time "$DS_TIMEOUT_LONG" --retry 2 --retry-delay 2 \
        -H "User-Agent: DomainSentinel/$DS_VERSION" \
        -H "Accept: application/json" \
        "https://crt.sh/?q=${DS_DOMAIN}&output=json" 2>/dev/null)"
    http_d="$(ds_http_status "$http_d")"

    local ct_w; ct_w="$(mktemp)"; DS_CLEANUP+=("$ct_w")
    local http_w
    http_w="$(curl -sS -o "$ct_w" -w '%{http_code}' \
        --max-time "$DS_TIMEOUT_LONG" --retry 2 --retry-delay 2 \
        -H "User-Agent: DomainSentinel/$DS_VERSION" \
        -H "Accept: application/json" \
        "https://crt.sh/?q=%25.${DS_DOMAIN}&output=json" 2>/dev/null)"
    http_w="$(ds_http_status "$http_w")"

    local ct_cs; ct_cs="$(mktemp)"; DS_CLEANUP+=("$ct_cs")
    local http_cs
    http_cs="$(curl -sS -o "$ct_cs" -w '%{http_code}' \
        --max-time "$DS_TIMEOUT_LONG" \
        -H "User-Agent: DomainSentinel/$DS_VERSION" \
        -H "Accept: application/json" \
        "https://api.certspotter.com/v1/issuances?domain=${DS_DOMAIN}&include_subdomains=true&expand=dns_names" \
        2>/dev/null)"
    http_cs="$(ds_http_status "$http_cs")"

    local ct_us; ct_us="$(mktemp)"; DS_CLEANUP+=("$ct_us")
    local http_us
    http_us="$(curl -sS -o "$ct_us" -w '%{http_code}' \
        --max-time "$DS_TIMEOUT_LONG" \
        -H "User-Agent: DomainSentinel/$DS_VERSION" \
        -H "Accept: application/json" \
        "https://urlscan.io/api/v1/search/?q=domain:${DS_DOMAIN}&size=1000" \
        2>/dev/null)"
    http_us="$(ds_http_status "$http_us")"

    local ct_ht; ct_ht="$(mktemp)"; DS_CLEANUP+=("$ct_ht")
    local http_ht
    http_ht="$(curl -sS -o "$ct_ht" -w '%{http_code}' \
        --max-time 20 \
        -H "User-Agent: DomainSentinel/$DS_VERSION" \
        "https://api.hackertarget.com/hostsearch/?q=${DS_DOMAIN}" 2>/dev/null)"
    http_ht="$(ds_http_status "$http_ht")"

    if [[ "$http_d" == "200" && -s "$ct_d" ]] && jq -e 'type=="array" and length>0' "$ct_d" >/dev/null 2>&1; then
        jq -r '.[].name_value // empty' "$ct_d" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' | sed 's/^\*\.//' \
            | grep -v '^$' | sort -u >> "$DS_DIR/crtsh.txt" || true
    fi
    if [[ "$http_w" == "200" && -s "$ct_w" ]] && jq -e 'type=="array" and length>0' "$ct_w" >/dev/null 2>&1; then
        jq -r '.[].name_value // empty' "$ct_w" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' | sed 's/^\*\.//' \
            | grep -v '^$' | sort -u >> "$DS_DIR/crtsh.txt" || true
    fi
    if [[ "$http_cs" == "200" && -s "$ct_cs" ]] && jq -e 'type=="array"' "$ct_cs" >/dev/null 2>&1; then
        jq -r '.[].dns_names[]? // empty' "$ct_cs" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' | sed 's/^\*\.//' \
            | grep -v '^$' | sort -u >> "$DS_DIR/crtsh.txt" || true
    fi
    if [[ "$http_us" == "200" && -s "$ct_us" ]] && jq -e '.results' "$ct_us" >/dev/null 2>&1; then
        jq -r '.results[]?.page.domain // empty' "$ct_us" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' | sed 's/^\*\.//' \
            | grep -v '^$' | sort -u >> "$DS_DIR/crtsh.txt" || true
    fi
    if [[ "$http_ht" == "200" && -s "$ct_ht" ]] && ! grep -qi 'error\|no records' "$ct_ht"; then
        cut -d, -f1 "$ct_ht" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' \
            | grep -E "^[a-z0-9.-]+\.${DS_DOMAIN//./\\.}$" \
            | sort -u >> "$DS_DIR/crtsh.txt" || true
    fi

    sort -u "$DS_DIR/crtsh.txt" -o "$DS_DIR/crtsh.txt" 2>/dev/null || true
    ct_count="$(ds_num "$(wc -l < "$DS_DIR/crtsh.txt" 2>/dev/null)")"

    if (( ct_count == 0 )); then
        printf '# no data: crt.sh(d=%s,w=%s) certspotter=%s urlscan=%s hackertarget=%s — 0 records\n' \
            "$http_d" "$http_w" "$http_cs" "$http_us" "$http_ht" > "$DS_DIR/crtsh.txt"
    fi

    local wildcard_ip
    wildcard_ip="$(ds_wildcard_dns_ip)"
    if [[ -n "$wildcard_ip" ]]; then
        printf '  %s!%s wildcard DNS detected (%s) — will filter matching IPs\n' \
            "$C_YEL" "$C_RST" "$wildcard_ip"
    fi

    local unique_count=0 line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == "$DS_DOMAIN" || "$line" == *".$DS_DOMAIN" ]] || continue
        if [[ -n "$wildcard_ip" ]]; then
            local rip
            rip="$(dig +short A "$line" 2>/dev/null | head -n1)"
            [[ "$rip" == "$wildcard_ip" ]] && continue
        fi
        printf '%s\n' "$line" >> "$DS_DIR/subdomains.txt"
        unique_count=$((unique_count+1))
    done < <( { cat "$DS_DIR/subfinder.txt" "$DS_DIR/crtsh.txt"; } \
              | tr '[:upper:]' '[:lower:]' | sort -u )

    [[ ! -s "$DS_DIR/subfinder.txt" ]] && \
        printf '# no data: subfinder produced 0 records\n' > "$DS_DIR/subfinder.txt"
    [[ ! -s "$DS_DIR/subdomains.txt" ]] && \
        printf '# no data: no unique in-scope subdomains\n' > "$DS_DIR/subdomains.txt"

    DS_STAGE_COUNT[1]="$unique_count"
    local state="completed"
    (( unique_count == 0 )) && state="no_results"
    ds_stage_done 1 "$state" "subfinder=$sf_count  crt.sh=$ct_count  unique=$unique_count"
}

# ------------------------------------------------------------------------------
# Stage 2 — Live hosts
# ------------------------------------------------------------------------------
ds_stage2_live_hosts() {
    ds_stage_header 2 "Live host discovery"
    : > "$DS_DIR/live_hosts.txt"
    : > "$DS_DIR/live_hosts.jsonl"

    local real_sub_count
    real_sub_count="$(ds_num "$(grep -vc '^#' "$DS_DIR/subdomains.txt" 2>/dev/null)")"
    if (( real_sub_count == 0 )); then
        printf '# no data: no subdomains to probe\n' > "$DS_DIR/live_hosts.txt"
        ds_stage_done 2 "no_results" "no subdomains to probe"
        return 0
    fi

    local used_httpx=0
    if [[ "${DS_DEP_STATUS[httpx]:-failed}" == "ok" ]]; then
        local pd_httpx; pd_httpx="$(ds_find_pd_httpx || true)"
        if [[ -n "$pd_httpx" ]]; then
            used_httpx=1
            timeout $((DS_TIMEOUT_LONG * 2)) "$pd_httpx" \
                -silent -l "$DS_DIR/subdomains.txt" \
                -json -status-code -title -tech-detect -ip -cname -cdn \
                -content-length -server -location -no-color \
                -timeout 6 -retries 1 -threads 50 -rate-limit 150 \
                2>>"$DS_DIR/recon.log" \
                > "$DS_DIR/live_hosts.jsonl" || true
        fi
    fi

    if [[ ! -s "$DS_DIR/live_hosts.jsonl" ]]; then
        printf '  %s!%s httpx returned nothing — falling back to DNS liveness\n' \
            "$C_YEL" "$C_RST"
        local host ip
        while IFS= read -r host; do
            [[ -z "$host" || "$host" == \#* ]] && continue
            ip="$(dig +short A "$host" 2>/dev/null | head -n1)"
            [[ -z "$ip" ]] && continue
            printf '%s\t%s\tDNS-ONLY\n' "$host" "$ip" >> "$DS_DIR/live_hosts.txt"
            printf '{"input":"%s","host":"%s","status_code":0,"title":"","tech":[],"dns_only":true}\n' \
                "$host" "$ip" >> "$DS_DIR/live_hosts.jsonl"
        done < "$DS_DIR/subdomains.txt"
    fi

    if (( used_httpx )) && [[ -s "$DS_DIR/live_hosts.jsonl" ]]; then
        : > "$DS_DIR/live_hosts.txt"
        jq -r '[.input // .host // "?", (.status_code|tostring), (.title // ""), (.tech // [] | join(",")), (.server // ""), (.host // .ip // ""), (.content_length|tostring // "")] | @tsv' \
            "$DS_DIR/live_hosts.jsonl" 2>/dev/null \
            | awk -F'\t' '{printf "%-40s %-5s %-40s %-25s %-15s %-15s %s\n", $1, $2, substr($3,1,40), substr($4,1,25), substr($5,1,15), $6, $7}' \
            > "$DS_DIR/live_hosts.txt" || true
    fi

    local count
    count="$(ds_num "$(wc -l < "$DS_DIR/live_hosts.jsonl" 2>/dev/null)")"
    if (( count == 0 )); then
        printf '# no data: no hosts responded to HTTP probing\n' > "$DS_DIR/live_hosts.txt"
    fi

    DS_STAGE_COUNT[2]="$count"
    local state="completed"
    (( count == 0 )) && state="no_results"
    ds_stage_done 2 "$state" "live hosts=$count"
}

# ------------------------------------------------------------------------------
# Stage 3 — Takeover
# ------------------------------------------------------------------------------
ds_stage3_takeover() {
    ds_stage_header 3 "Subdomain takeover detection"
    : > "$DS_DIR/takeover_vuln.txt"
    : > "$DS_DIR/takeover_subzy_raw.log"

    local real_sub_count
    real_sub_count="$(ds_num "$(grep -vc '^#' "$DS_DIR/subdomains.txt" 2>/dev/null)")"
    if (( real_sub_count == 0 )); then
        printf '# no data: no subdomains to test\n' > "$DS_DIR/takeover_vuln.txt"
        printf '# no data: no subdomains to test\n' > "$DS_DIR/takeover_subzy_raw.log"
        ds_stage_done 3 "no_results" "no subdomains to test"
        return 0
    fi

    if [[ "${DS_DEP_STATUS[subzy]:-failed}" != "ok" ]]; then
        printf '# dependency missing: subzy\n' > "$DS_DIR/takeover_vuln.txt"
        ds_stage_done 3 "skipped" "subzy unavailable"
        return 0
    fi

    timeout $((DS_TIMEOUT_LONG * 3)) subzy run \
        --targets "$DS_DIR/subdomains.txt" \
        --concurrency 50 \
        --hide_fails \
        > "$DS_DIR/takeover_subzy_raw.log" 2>&1 || true

    {
        grep -iE 'vulnerable|\[VULN\]|takeover|candidate|dangling' \
            "$DS_DIR/takeover_subzy_raw.log" 2>/dev/null
        grep -iE 'CNAME.*(missing|not found|unclaimed|no such)' \
            "$DS_DIR/takeover_subzy_raw.log" 2>/dev/null
        grep -iE 'S3|GitHub Pages|Heroku|Azure|Fastly|Shopify|Zendesk' \
            "$DS_DIR/takeover_subzy_raw.log" 2>/dev/null | grep -iE 'vuln|fail|miss'
    } | sed 's/\x1b\[[0-9;]*m//g' | sort -u \
        > "$DS_DIR/takeover_vuln.txt" || true

    if [[ -s "$DS_DIR/takeover_vuln.txt" ]]; then
        local tmp_rewrite; tmp_rewrite="$(mktemp)"
        printf '# confidence\thost / detail\n' > "$tmp_rewrite"
        awk '{ printf "high\t%s\n", $0 }' "$DS_DIR/takeover_vuln.txt" >> "$tmp_rewrite"
        mv "$tmp_rewrite" "$DS_DIR/takeover_vuln.txt"
    fi

    local count; count="$(ds_num "$(grep -vc '^#' "$DS_DIR/takeover_vuln.txt" 2>/dev/null)")"
    [[ ! -s "$DS_DIR/takeover_vuln.txt" ]] && \
        printf '# no data: no takeover candidates\n' > "$DS_DIR/takeover_vuln.txt"
    [[ ! -s "$DS_DIR/takeover_subzy_raw.log" ]] && \
        printf '# no data: subzy produced no output\n' > "$DS_DIR/takeover_subzy_raw.log"

    DS_STAGE_COUNT[3]="$count"
    local state="completed"
    (( count == 0 )) && state="no_results"
    ds_stage_done 3 "$state" "candidates=$count"
}

# ------------------------------------------------------------------------------
# Stage 4 — JS secrets
# ------------------------------------------------------------------------------
ds_stage4_js_secrets() {
    ds_stage_header 4 "Historical JavaScript scan"
    : > "$DS_DIR/js_files.txt"
    : > "$DS_DIR/js_scan_raw.txt"
    : > "$DS_DIR/secrets.txt"
    : > "$DS_DIR/secrets_unique.txt"

    local urls_tmp; urls_tmp="$(mktemp)"; DS_CLEANUP+=("$urls_tmp")

    if [[ "${DS_DEP_STATUS[waybackurls]:-failed}" == "ok" ]]; then
        timeout $((DS_TIMEOUT_LONG * 2)) bash -c \
            "printf '%s\n' '$DS_DOMAIN' | waybackurls" 2>>"$DS_DIR/recon.log" \
            >> "$urls_tmp" || true
    fi
    local cdx_pattern
    for cdx_pattern in "${DS_DOMAIN}/*" "*.${DS_DOMAIN}/*"; do
        curl -fsS --max-time "$DS_TIMEOUT_LONG" \
            -H "User-Agent: DomainSentinel/$DS_VERSION" \
            "http://web.archive.org/cdx/search/cdx?url=${cdx_pattern}&output=text&fl=original&collapse=urlkey&limit=50000" \
            2>/dev/null >> "$urls_tmp" || true
    done

    sort -u "$urls_tmp" -o "$urls_tmp" 2>/dev/null || true
    local total_urls; total_urls="$(ds_num "$(wc -l < "$urls_tmp" 2>/dev/null)")"

    {
        grep -iE '\.js([?#]|$)' "$urls_tmp" 2>/dev/null
        grep -iE '\.js\?' "$urls_tmp" 2>/dev/null
        grep -iE '/[a-z0-9._-]+\.js$' "$urls_tmp" 2>/dev/null
    } | sort -u > "$DS_DIR/js_files.txt" || true

    local js_count; js_count="$(ds_num "$(wc -l < "$DS_DIR/js_files.txt" 2>/dev/null)")"
    printf '  %s[%s] Historical URLs=%s  JS URLs=%s%s\n' \
        "$C_DIM" "$(ds_ts)" "$total_urls" "$js_count" "$C_RST"

    if (( js_count == 0 )); then
        printf '# no data: %d historical URLs, 0 matched JS\n' "$total_urls" > "$DS_DIR/js_files.txt"
        printf '# no data\n' > "$DS_DIR/js_scan_raw.txt"
        printf '# no data\n' > "$DS_DIR/secrets.txt"
        printf '# no data\n' > "$DS_DIR/secrets_unique.txt"
        ds_stage_done 4 "no_results" "no JS to scan"
        return 0
    fi

    local i=0 scanned=0
    local url tmp
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        i=$((i+1))
        (( i % 10 == 0 )) && printf '  %s·%s scanned %d/%s\n' "$C_DIM" "$C_RST" "$i" "$js_count"

        tmp="$(mktemp)"
        if ! curl -fsS --max-time 10 -A "DomainSentinel/$DS_VERSION" \
                "$url" -o "$tmp" 2>/dev/null || [[ ! -s "$tmp" ]]; then
            curl -fsS --max-time 10 -A "DomainSentinel/$DS_VERSION" \
                "https://web.archive.org/web/2id_/${url}" -o "$tmp" 2>/dev/null || true
        fi

        if [[ -s "$tmp" ]] && (( $(wc -c < "$tmp") <= 5242880 )); then
            scanned=$((scanned+1))
            {
                grep -aoE '(api[_-]?key|apikey)["'"'"'[:space:]]*[:=]["'"'"'[:space:]]*[A-Za-z0-9_\-]{16,}' "$tmp" 2>/dev/null
                grep -aoE '(secret|client[_-]?secret)["'"'"'[:space:]]*[:=]["'"'"'[:space:]]*[A-Za-z0-9_\-]{16,}' "$tmp" 2>/dev/null
                grep -aoE '(access[_-]?token|auth[_-]?token|bearer)["'"'"'[:space:]]*[:=]["'"'"'[:space:]]*[A-Za-z0-9_.\-]{20,}' "$tmp" 2>/dev/null
                grep -aoE '(password|passwd|pwd)["'"'"'[:space:]]*[:=]["'"'"'[:space:]]*[^"'"'"'[:space:]]{8,}' "$tmp" 2>/dev/null
                grep -aoE '(aws_access_key_id|AKIA)[A-Z0-9]{16,}' "$tmp" 2>/dev/null
                grep -aoE '(aws_secret_access_key|aws_secret)["'"'"'[:space:]]*[:=]["'"'"'[:space:]]*[A-Za-z0-9/+=]{40}' "$tmp" 2>/dev/null
                grep -aoE 'AIza[A-Za-z0-9_\-]{35}' "$tmp" 2>/dev/null
                grep -aoE 'dop_v1_[a-f0-9]{64}' "$tmp" 2>/dev/null
                grep -aoE 'sk_live_[A-Za-z0-9]{24,}' "$tmp" 2>/dev/null
                grep -aoE 'pk_live_[A-Za-z0-9]{24,}' "$tmp" 2>/dev/null
                grep -aoE 'rk_live_[A-Za-z0-9]{24,}' "$tmp" 2>/dev/null
                grep -aoE 'xox[baprs]-[A-Za-z0-9-]{10,}' "$tmp" 2>/dev/null
                grep -aoE 'https://hooks\.slack\.com/services/T[A-Za-z0-9_]{8,}/B[A-Za-z0-9_]{8,}/[A-Za-z0-9_]{24}' "$tmp" 2>/dev/null
                grep -aoE 'https://discord(app)?\.com/api/webhooks/[0-9]{18,20}/[A-Za-z0-9_\-]{60,}' "$tmp" 2>/dev/null
                grep -aoE '[0-9]{8,10}:[A-Za-z0-9_\-]{35}' "$tmp" 2>/dev/null
                grep -aoE 'SG\.[A-Za-z0-9_\-]{22}\.[A-Za-z0-9_\-]{43}' "$tmp" 2>/dev/null
                grep -aoE 'SK[0-9a-fA-F]{32}' "$tmp" 2>/dev/null
                grep -aoE 'gh[pousr]_[A-Za-z0-9]{36,}' "$tmp" 2>/dev/null
                grep -aoE 'github_pat_[A-Za-z0-9_]{82}' "$tmp" 2>/dev/null
                grep -aoE 'npm_[A-Za-z0-9]{36}' "$tmp" 2>/dev/null
                grep -aoE 'pypi-[A-Za-z0-9_\-]{50,}' "$tmp" 2>/dev/null
                grep -aoE 'dckr_pat_[A-Za-z0-9_\-]{27}' "$tmp" 2>/dev/null
                grep -aoE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$tmp" 2>/dev/null
                grep -aoE -- '-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----' "$tmp" 2>/dev/null
                grep -aoE 'mongodb(\+srv)?://[^"'"'"'[:space:]]+:[^"'"'"'[:space:]]+@' "$tmp" 2>/dev/null
                grep -aoE 'postgres(ql)?://[^"'"'"'[:space:]]+:[^"'"'"'[:space:]]+@' "$tmp" 2>/dev/null
                grep -aoE 'mysql://[^"'"'"'[:space:]]+:[^"'"'"'[:space:]]+@' "$tmp" 2>/dev/null
                grep -aoE 'redis://[^"'"'"'[:space:]]+:[^"'"'"'[:space:]]+@' "$tmp" 2>/dev/null
            } | while IFS= read -r m; do
                printf '%s\t%s\n' "$url" "$m"
            done >> "$DS_DIR/js_scan_raw.txt"
        fi
        rm -f "$tmp"
    done < "$DS_DIR/js_files.txt"

    if [[ -s "$DS_DIR/js_scan_raw.txt" ]]; then
        awk -F'\t' '{
            url=$1; hit=$2
            masked = substr(hit, 1, 12) "[REDACTED]"
            print url "\t" masked
        }' "$DS_DIR/js_scan_raw.txt" > "$DS_DIR/secrets.txt"
        awk -F'\t' '!seen[$1 FS $2]++' "$DS_DIR/secrets.txt" > "$DS_DIR/secrets_unique.txt"
    else
        printf '# no data\n' > "$DS_DIR/secrets.txt"
        printf '# no data\n' > "$DS_DIR/secrets_unique.txt"
    fi
    local findings; findings="$(ds_num "$(grep -vc '^#' "$DS_DIR/secrets_unique.txt" 2>/dev/null)")"

    DS_STAGE_COUNT[4]="$findings"
    ds_stage_done 4 "completed" \
        "js_files=$js_count  scanned=$scanned  findings=$findings"
}

# ------------------------------------------------------------------------------
# Stage 5 — WHOIS + DNS
# ------------------------------------------------------------------------------
ds_stage5_whois_dns() {
    ds_stage_header 5 "WHOIS & DNS records"
    : > "$DS_DIR/whois.txt"
    : > "$DS_DIR/whois_summary.txt"
    : > "$DS_DIR/dns_records.txt"

    if [[ "${DS_DEP_STATUS[whois]:-failed}" == "ok" ]]; then
        timeout "$DS_TIMEOUT_NET" whois "$DS_DOMAIN" > "$DS_DIR/whois.txt" 2>/dev/null || true
    fi

    extract() {
        local f="$1"
        grep -iE "^[[:space:]]*(${f})[[:space:]]*:" "$DS_DIR/whois.txt" 2>/dev/null \
            | head -n1 | sed -E 's/^[^:]+:[[:space:]]*//' || true
    }

    local registrar org street city state post country phone
    local created expires updated ns_list
    registrar="$(extract 'Registrar')"
    org="$(extract 'Registrant Organization|Registrant Org|Org')"
    street="$(extract 'Registrant Street|Street')"
    city="$(extract 'Registrant City|City')"
    state="$(extract 'Registrant State/Province|State|Province')"
    post="$(extract 'Registrant Postal Code|Postal Code|Postcode')"
    country="$(extract 'Registrant Country|Country')"
    phone="$(extract 'Registrant Phone|Phone')"
    created="$(extract 'Creation Date|Created On|Created|Registered on')"
    expires="$(extract 'Registry Expiry Date|Expiration Date|Expiry Date|Expires|Expiration Time')"
    updated="$(extract 'Updated Date|Last Updated|Last Modified|Last changed')"
    ns_list="$(grep -iE '^[[:space:]]*Name Server[[:space:]]*:' "$DS_DIR/whois.txt" 2>/dev/null \
                | sed -E 's/^[^:]+:[[:space:]]*//' | sort -u | paste -sd', ' -)"

    norm() { printf '%s' "${1:-Unknown}" | tr -d '\r\n\t' | cut -c1-256; }
    registrar="$(norm "$registrar")"
    org="$(norm "$org")"
    street="$(norm "$street")"
    city="$(norm "$city")"
    state="$(norm "$state")"
    post="$(norm "$post")"
    country="$(norm "$country")"
    phone="$(norm "$phone")"
    created="$(norm "$created")"
    expires="$(norm "$expires")"
    updated="$(norm "$updated")"
    ns_list="$(norm "$ns_list")"

    {
        printf 'WHOIS summary — %s\n' "$DS_DOMAIN"
        printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'Registrar          : %s\n' "$registrar"
        printf 'Registrant Org     : %s\n' "$org"
        printf 'Registrant Street  : %s\n' "$street"
        printf 'Registrant City    : %s\n' "$city"
        printf 'Registrant State   : %s\n' "$state"
        printf 'Registrant Postal  : %s\n' "$post"
        printf 'Registrant Country : %s\n' "$country"
        printf 'Registrant Phone   : %s\n' "$phone"
        printf 'Created            : %s\n' "$created"
        printf 'Expires            : %s\n' "$expires"
        printf 'Updated            : %s\n' "$updated"
        printf 'Name Servers       : %s\n' "$ns_list"
    } > "$DS_DIR/whois_summary.txt"

    if [[ "${DS_DEP_STATUS[dnsx]:-skip}" == "ok" ]]; then
        printf '  %s·%s resolving via dnsx\n' "$C_DIM" "$C_RST"
        {
            printf 'DNS records for %s\n' "$DS_DOMAIN"
            printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
            printf '### A\n'
            printf '%s\n' "$DS_DOMAIN" | dnsx -silent -a -resp-only 2>/dev/null || true
            printf '\n### AAAA\n'
            printf '%s\n' "$DS_DOMAIN" | dnsx -silent -aaaa -resp-only 2>/dev/null || true
            printf '\n### CNAME\n'
            printf '%s\n' "$DS_DOMAIN" | dnsx -silent -cname -resp-only 2>/dev/null || true
            printf '\n### MX\n'
            printf '%s\n' "$DS_DOMAIN" | dnsx -silent -mx -resp-only 2>/dev/null || true
            printf '\n### NS\n'
            printf '%s\n' "$DS_DOMAIN" | dnsx -silent -ns -resp-only 2>/dev/null || true
            printf '\n### TXT\n'
            printf '%s\n' "$DS_DOMAIN" | dnsx -silent -txt -resp-only 2>/dev/null || true
            printf '\n### DMARC\n'
            printf '_dmarc.%s\n' "$DS_DOMAIN" | dnsx -silent -txt -resp-only 2>/dev/null || true
            printf '\n'
        } > "$DS_DIR/dns_records.txt"
    elif [[ "${DS_DEP_STATUS[dig]:-failed}" == "ok" ]]; then
        {
            printf 'DNS records for %s\n' "$DS_DOMAIN"
            printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
            local rtype
            for rtype in A AAAA CNAME MX NS TXT SOA CAA; do
                printf '### %s\n' "$rtype"
                timeout 5 dig +short "$rtype" "$DS_DOMAIN" 2>/dev/null || true
                printf '\n'
            done
            printf '### DMARC\n'
            dig +short TXT "_dmarc.$DS_DOMAIN" 2>/dev/null || true
            printf '\n'
        } > "$DS_DIR/dns_records.txt"
    fi

    [[ ! -s "$DS_DIR/whois.txt" ]] && \
        printf '# no data: whois returned nothing\n' > "$DS_DIR/whois.txt"
    [[ ! -s "$DS_DIR/dns_records.txt" ]] && \
        printf '# no data: DNS query failed\n' > "$DS_DIR/dns_records.txt"

    DS_STAGE_COUNT[5]="$(ds_num "$(grep -c '^###' "$DS_DIR/dns_records.txt" 2>/dev/null)")"
    ds_stage_done 5 "completed" "registrar=$registrar"
}

# ------------------------------------------------------------------------------
# Stage 6 — Geolocation
# ------------------------------------------------------------------------------
ds_is_public_ip() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    case "$ip" in
        10.*|127.*|169.254.*|192.168.*|0.*|224.*|239.*) return 1 ;;
        172.1[6-9].*|172.2[0-9].*|172.3[01].*) return 1 ;;
    esac
    return 0
}

ds_cloud_from_asn() {
    local asn="$1"
    case "$asn" in
        *AMAZON*|*AWS*|*"AS16509"*|*"AS14618"*) echo "AWS" ;;
        *GOOGLE*|*"AS15169"*)                   echo "GCP" ;;
        *MICROSOFT*|*AZURE*|*"AS8075"*)          echo "Azure" ;;
        *CLOUDFLARE*|*"AS13335"*)                echo "Cloudflare" ;;
        *DIGITALOCEAN*|*"AS14061"*)              echo "DigitalOcean" ;;
        *AKAMAI*|*"AS20940"*|*"AS16625"*)        echo "Akamai" ;;
        *FASTLY*|*"AS54113"*)                    echo "Fastly" ;;
        *ORACLE*|*"AS31898"*)                    echo "Oracle Cloud" ;;
        *LINODE*|*"AS63949"*)                    echo "Linode" ;;
        *OVH*|*"AS16276"*)                       echo "OVH" ;;
        *)                                       echo "Other" ;;
    esac
}

ds_stage6_geo() {
    ds_stage_header 6 "IP geolocation"
    : > "$DS_DIR/ip_geolocation.txt"
    : > "$DS_DIR/ip_geolocation.json"

    local ips_tmp; ips_tmp="$(mktemp)"; DS_CLEANUP+=("$ips_tmp")
    local hostmap_tmp; hostmap_tmp="$(mktemp)"; DS_CLEANUP+=("$hostmap_tmp")

    if [[ "${DS_DEP_STATUS[dig]:-failed}" == "ok" ]]; then
        local main_ip
        main_ip="$(dig +short A "$DS_DOMAIN" 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)"
        if [[ -n "$main_ip" ]]; then
            printf '%s\n' "$main_ip" >> "$ips_tmp"
            printf '%s\t%s\n' "$main_ip" "$DS_DOMAIN" >> "$hostmap_tmp"
        fi
    fi

    if [[ -s "$DS_DIR/live_hosts.jsonl" ]]; then
        jq -r 'select(.host != null) | "\(.host)\t\(.input // .host)"' \
            "$DS_DIR/live_hosts.jsonl" 2>/dev/null | while IFS=$'\t' read -r ip host; do
                [[ -z "$ip" ]] && continue
                ds_is_public_ip "$ip" || continue
                printf '%s\n' "$ip" >> "$ips_tmp"
                printf '%s\t%s\n' "$ip" "$host" >> "$hostmap_tmp"
            done
    fi

    sort -u "$ips_tmp" -o "$ips_tmp" 2>/dev/null || true
    local total_ips; total_ips="$(ds_num "$(wc -l < "$ips_tmp" 2>/dev/null)")"

    if (( total_ips == 0 )); then
        printf '# no data: no public IPs resolved\n' > "$DS_DIR/ip_geolocation.txt"
        printf '{}\n' > "$DS_DIR/ip_geolocation.json"
        ds_stage_done 6 "no_results" "no public IPs"
        return 0
    fi

    local batch json batch_resp
    batch="$(head -n "$DS_GEO_BATCH_MAX" "$ips_tmp")"
    json="$(printf '%s\n' "$batch" | jq -R . | jq -s .)"
    batch_resp="$(curl -fsS --max-time "$DS_TIMEOUT_LONG" \
        -H 'Content-Type: application/json' \
        -X POST -d "$json" \
        "$DS_GEO_BATCH_URL?fields=$DS_GEO_FIELDS" 2>/dev/null)" || true

    if [[ -n "$batch_resp" ]] && printf '%s' "$batch_resp" | jq -e . >/dev/null 2>&1; then
        printf '%s' "$batch_resp" | jq -c '.[]' >> "$DS_DIR/ip_geolocation.json"
    fi

    {
        printf 'IP geolocation — %s\n' "$DS_DOMAIN"
        printf 'Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'Total unique public IPs: %s\n\n' "$total_ips"
    } > "$DS_DIR/ip_geolocation.txt"

    local ip
    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        local hosts
        hosts="$(awk -F'\t' -v i="$ip" '$1==i{print $2}' "$hostmap_tmp" | sort -u | paste -sd', ' -)"
        local row
        row="$(grep -F "\"$ip\"" "$DS_DIR/ip_geolocation.json" 2>/dev/null | head -n1)"
        local city region country isp asn status rev cloud
        if [[ -n "$row" ]]; then
            city="$(printf '%s' "$row" | jq -r '.city // "Unknown"')"
            region="$(printf '%s' "$row" | jq -r '.regionName // "Unknown"')"
            country="$(printf '%s' "$row" | jq -r '.country // "Unknown"')"
            isp="$(printf '%s' "$row" | jq -r '.isp // "Unknown"')"
            asn="$(printf '%s' "$row" | jq -r '.as // "Unknown"')"
            status="$(printf '%s' "$row" | jq -r '.status // "unknown"')"
            rev="$(printf '%s' "$row" | jq -r '.reverse // "—"')"
        else
            city="Unknown"; region="Unknown"; country="Unknown"
            isp="Unknown"; asn="Unknown"; status="unavailable"; rev="—"
        fi
        cloud="$(ds_cloud_from_asn "$asn")"
        {
            printf 'IP          : %s\n' "$ip"
            printf 'Hosts       : %s\n' "${hosts:-—}"
            printf 'Status      : %s\n' "$status"
            printf 'City        : %s\n' "$city"
            printf 'Region      : %s\n' "$region"
            printf 'Country     : %s\n' "$country"
            printf 'ISP         : %s\n' "$isp"
            printf 'ASN         : %s\n' "$asn"
            printf 'Cloud       : %s\n' "$cloud"
            printf 'Reverse DNS : %s\n' "$rev"
            printf -- '---\n'
        } >> "$DS_DIR/ip_geolocation.txt"
    done < "$ips_tmp"

    DS_STAGE_COUNT[6]="$total_ips"
    ds_stage_done 6 "completed" "unique public IPs=$total_ips"
}

# ------------------------------------------------------------------------------
# Reports
# ------------------------------------------------------------------------------
ds_write_target_info() {
    local main_ip geo_line
    main_ip="$(dig +short A "$DS_DOMAIN" 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)"
    geo_line="$(awk '/^City|^Region|^Country/{printf "%s ", $0}' "$DS_DIR/ip_geolocation.txt" 2>/dev/null | head -n1)"
    {
        printf 'Target Information — %s\n' "$DS_DOMAIN"
        printf 'Generated: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'Scan start  : %s\n' "$(date -d "@$DS_START_EPOCH" '+%Y-%m-%d %H:%M:%S')"
        printf 'Scan finish : %s\n' "$(date -d "@$DS_END_EPOCH"   '+%Y-%m-%d %H:%M:%S')"
        printf 'Duration    : %s seconds\n\n' "$((DS_END_EPOCH - DS_START_EPOCH))"
        printf 'Main IP     : %s\n' "${main_ip:-Unknown}"
        printf 'Geolocation : %s\n' "${geo_line:-Unknown}"
        printf '\n'
        cat "$DS_DIR/whois_summary.txt" 2>/dev/null
    } > "$DS_DIR/target_info.txt"
}

ds_whois_field() {
    local key="$1"
    grep -iE "^${key}[[:space:]]*:" "$DS_DIR/whois_summary.txt" 2>/dev/null \
        | head -n1 | sed -E 's/^[^:]+:[[:space:]]*//' || true
}

ds_write_summary() {
    local duration=$((DS_END_EPOCH - DS_START_EPOCH))

    local sf_count ct_count uniq_subs live_hosts
    local takeover_count js_count secrets_count ip_count

    sf_count="$(ds_num "$(wc -l < "$DS_DIR/subfinder.txt" 2>/dev/null)")"
    ct_count="$(ds_num "$(grep -vc '^#' "$DS_DIR/crtsh.txt" 2>/dev/null)")"
    uniq_subs="$(ds_num "$(grep -vc '^#' "$DS_DIR/subdomains.txt" 2>/dev/null)")"
    live_hosts="$(ds_num "$(wc -l < "$DS_DIR/live_hosts.jsonl" 2>/dev/null)")"
    takeover_count="$(ds_num "$(grep -vc '^#' "$DS_DIR/takeover_vuln.txt" 2>/dev/null)")"
    js_count="$(ds_num "$(grep -vc '^#' "$DS_DIR/js_files.txt" 2>/dev/null)")"
    secrets_count="$(ds_num "$(grep -vc '^#' "$DS_DIR/secrets_unique.txt" 2>/dev/null)")"
    ip_count="$(ds_num "$(wc -l < "$DS_DIR/ip_geolocation.json" 2>/dev/null)")"

    local registrar org address phone
    registrar="$(ds_whois_field 'Registrar')"
    org="$(ds_whois_field 'Registrant Org')"
    address="$(ds_whois_field 'Registrant Street')"
    phone="$(ds_whois_field 'Registrant Phone')"

    [[ -z "$registrar" || "$registrar" == "Unknown" ]] && registrar="Redacted/Unknown"
    [[ -z "$org"       || "$org"       == "Unknown" ]] && org="Redacted/Unknown"
    [[ -z "$address"   || "$address"   == "Unknown" ]] && address="Redacted/Unknown"
    [[ -z "$phone"     || "$phone"     == "Unknown" ]] && phone="Redacted/Unknown"

    local main_ip geo_city geo_region geo_country geo_isp geo_as
    main_ip="$(dig +short A "$DS_DOMAIN" 2>/dev/null | grep -E '^[0-9.]+$' | head -n1)"
    [[ -z "$main_ip" ]] && main_ip="Unknown"

    local first_row
    first_row="$(head -n1 "$DS_DIR/ip_geolocation.json" 2>/dev/null)"
    if [[ -n "$first_row" ]]; then
        geo_city="$(printf '%s'   "$first_row" | jq -r '.city // "Unknown"')"
        geo_region="$(printf '%s' "$first_row" | jq -r '.regionName // "Unknown"')"
        geo_country="$(printf '%s' "$first_row" | jq -r '.country // "Unknown"')"
        geo_isp="$(printf '%s' "$first_row" | jq -r '.isp // "Unknown"')"
        geo_as="$(printf '%s' "$first_row" | jq -r '.as // "Unknown"')"
    else
        geo_city="Unknown"; geo_region="Unknown"; geo_country="Unknown"
        geo_isp="Unknown"; geo_as="Unknown"
    fi

    local geo_line
    if [[ "$geo_country" != "Unknown" ]]; then
        geo_line="$geo_city, $geo_region, $geo_country"
    else
        geo_line="Unknown"
    fi

    local isp_asn_line
    if [[ "$geo_isp" != "Unknown" && "$geo_as" != "Unknown" ]]; then
        isp_asn_line="$geo_isp ($geo_as)"
    elif [[ "$geo_isp" != "Unknown" ]]; then
        isp_asn_line="$geo_isp"
    elif [[ "$geo_as" != "Unknown" ]]; then
        isp_asn_line="$geo_as"
    else
        isp_asn_line="Unknown"
    fi

    local takeover_str secrets_str
    if (( takeover_count > 0 )); then
        takeover_str="⚠ $takeover_count candidate(s) — manual validation required"
    else
        takeover_str="✓ None"
    fi
    if (( secrets_count > 0 )); then
        secrets_str="⚠ $secrets_count finding(s) — review secrets_unique.txt"
    else
        secrets_str="✓ None"
    fi

    local status_label="PASS"
    if (( secrets_count > 0 )) || (( takeover_count > 0 )); then
        status_label="REVIEW REQUIRED"
    fi

    local dur_str
    dur_str="$(printf '%02dm %02ds' $((duration/60)) $((duration%60)))"

    local RULE="══════════════════════════════════════════════════════════════════"

    {
        printf '%s\n' "$RULE"
        printf '                  Passive OSINT Recon Summary\n'
        printf '%s\n\n' "$RULE"

        printf '%-20s : %s\n' "Target"               "$DS_DOMAIN"
        printf '%-20s : %s\n' "Output Directory"     "$DS_DIR"
        printf '%-20s : %s\n\n' "Scan Duration"       "$dur_str"

        printf '%-20s : %s\n' "Registrar"             "$registrar"
        printf '%-20s : %s\n' "Registrant Org"        "$org"
        printf '%-20s : %s\n' "Registrant Address"    "$address"
        printf '%-20s : %s\n\n' "Registrant Phone"    "$phone"

        printf '%-20s : %s\n' "Main IP Address"       "$main_ip"
        printf '%-20s : %s\n' "Geolocation"           "$geo_line"
        printf '%-20s : %s\n' "ISP / ASN"             "$isp_asn_line"
        printf '%-20s : %s\n\n' "Unique Live IPs"     "$ip_count"

        printf '%-20s : %s\n' "Subfinder Results"     "$sf_count"
        printf '%-20s : %s\n' "crt.sh Results"        "$ct_count"
        printf '%-20s : %s\n' "Unique Subdomains"     "$uniq_subs"
        printf '%-20s : %s\n\n' "Live Hosts"          "$live_hosts"

        printf '%-20s : %s\n' "Takeover Candidates"   "$takeover_str"
        printf '%-20s : %s\n' "JavaScript Files"      "$js_count"
        printf '%-20s : %s\n\n' "Secrets Found"       "$secrets_str"

        printf '%-20s : %s\n' "Overall Status"        "$status_label"
        printf '%s\n' "$RULE"
    } > "$DS_DIR/summary.txt"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
    DS_START_EPOCH="$(date +%s)"

    local arg_domain="${1:-}"
    local arg_output="${2:-}"

    ds_banner

    if [[ -z "$arg_domain" ]]; then
        arg_domain="$(ds_ask_target)"
    fi

    local norm
    if ! norm="$(ds_validate_domain "$arg_domain")"; then
        ds_err "Invalid domain: $arg_domain"
        printf '   Usage: %s <domain> [output_base]\n' "$0"
        exit 2
    fi
    DS_DOMAIN="$norm"

    if [[ -n "$arg_output" ]]; then
        DS_ROOT="${arg_output%/}"
    else
        if [[ -z "${1:-}" ]]; then
            DS_ROOT="$(ds_ask_output_base)"
        else
            DS_ROOT="$DS_DEFAULT_OUT"
        fi
        DS_ROOT="${DS_ROOT%/}"
    fi

    DS_DIR="$DS_ROOT/$DS_DOMAIN"
    mkdir -p "$DS_DIR" || { ds_err "Cannot create $DS_DIR"; exit 3; }
    chmod 700 "$DS_DIR"

    DS_TMPDIR="$(mktemp -d)"
    : > "$DS_DIR/recon.log"

    printf '   %sTarget%s   %s\n' "$C_BLD" "$C_RST" "$DS_DOMAIN"
    printf '   %sOutput%s   %s\n' "$C_BLD" "$C_RST" "$DS_DIR"
    printf '   %sStart%s    %s\n' "$C_BLD" "$C_RST" "$(date '+%Y-%m-%d %H:%M:%S')"

    if [[ -z "${1:-}" ]]; then
        if ! ds_confirm "Proceed with active reconnaissance?"; then
            ds_err "Aborted."
            exit 0
        fi
    fi

    ds_check_all_deps || ds_warn "Some dependencies failed."

    ds_stage1_subdomains || true
    ds_stage2_live_hosts  || true
    ds_stage3_takeover    || true
    ds_stage4_js_secrets  || true
    ds_stage5_whois_dns   || true
    ds_stage6_geo         || true

    DS_END_EPOCH="$(date +%s)"
    ds_write_target_info
    ds_write_summary

    printf '\n   %sSCAN COMPLETE%s\n\n' "$C_GRN" "$C_RST"
}

main "$@"
