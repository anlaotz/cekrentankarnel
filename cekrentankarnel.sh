#!/usr/bin/env bash
# ======================================================
# cekrentankarnel.sh
# Dirty Frag Defensive Checker
# Audit, Mitigasi, Restore, dan Simulasi Aman
# ======================================================

set -o pipefail

APP_NAME="Cek Rentan Kernel"
APP_DESC="Dirty Frag Defensive Exposure Checker"
VERSION="1.1.0"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
BOLD="\033[1m"
DIM="\033[2m"
NC="\033[0m"

line() {
    echo -e "${DIM}──────────────────────────────────────────────────────${NC}"
}

banner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║              CEK RENTAN KERNEL                      ║"
    echo "║        Dirty Frag Defensive Checker                 ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BLUE}Versi:${NC} $VERSION"
    echo -e "${BLUE}Mode:${NC} Audit defensif, mitigasi, dan observasi aman"
    line
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

section() {
    echo
    echo -e "${MAGENTA}${BOLD}$1${NC}"
    line
}

need_root_hint() {
    if [ "$EUID" -ne 0 ]; then
        warn "Beberapa pemeriksaan lebih lengkap jika dijalankan dengan sudo."
        echo -e "Contoh: ${BOLD}sudo ./cekrentankarnel.sh start${NC}"
        echo
    fi
}

show_help() {
    banner
    cat <<EOF
Penggunaan:

  ./cekrentankarnel.sh start
  ./cekrentankarnel.sh mitigasi
  ./cekrentankarnel.sh restore
  ./cekrentankarnel.sh simulasi
  ./cekrentankarnel.sh status
  ./cekrentankarnel.sh help
  ./cekrentankarnel.sh -h

Perintah:

  start
      Menjalankan audit defensif:
      - cek OS dan kernel
      - cek module esp4, esp6, rxrpc
      - cek module aktif
      - cek namespace
      - cek AppArmor
      - cek log RxRPC
      - cek XFRM state
      - tampilkan ringkasan risiko

  mitigasi
      Mitigasi sementara:
      - blacklist esp4
      - blacklist esp6
      - blacklist rxrpc
      - unload module
      - drop page cache

  restore
      Menghapus blacklist mitigasi agar module bisa diload kembali.

  simulasi
      Simulasi aman:
      - compile exp.c jika ada
      - tampilkan informasi binary
      - tampilkan strings awal
      - TIDAK menjalankan privilege escalation

  status
      Ringkasan cepat module aktif dan konfigurasi utama.

  help / -h
      Menampilkan bantuan.

Catatan:
  Script ini TIDAK menjalankan exploit.
  Script ini hanya untuk audit defensif, observasi, dan mitigasi.
EOF
}

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "Command tersedia: $1"
    else
        warn "Command tidak ditemukan: $1"
    fi
}

check_module_available() {
    local mod="$1"
    if modinfo "$mod" >/dev/null 2>&1; then
        ok "Module tersedia: $mod"
        modinfo "$mod" 2>/dev/null | grep -E "^(filename|description|depends|name|vermagic):" | sed 's/^/    /'
    else
        err "Module tidak ditemukan: $mod"
    fi
}

check_module_loaded() {
    local mod="$1"
    if lsmod | awk '{print $1}' | grep -qx "$mod"; then
        warn "Module aktif: $mod"
        return 0
    else
        ok "Module tidak aktif: $mod"
        return 1
    fi
}

run_status() {
    banner
    need_root_hint

    section "[STATUS CEPAT]"

    echo -e "${BOLD}Kernel:${NC} $(uname -r)"
    echo -e "${BOLD}User:${NC} $(whoami) / UID=$EUID"
    echo

    echo -e "${BOLD}Module aktif:${NC}"
    lsmod | grep -E 'rxrpc|esp4|esp6|xfrm_algo|xfrm_user' || echo "Tidak ada module target aktif."
    echo

    echo -e "${BOLD}Namespace:${NC}"
    sysctl kernel.unprivileged_userns_clone 2>/dev/null || true

    if [ -f /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]; then
        echo -n "apparmor_restrict_unprivileged_userns = "
        cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns
    fi
}

run_start() {
    banner
    need_root_hint

    section "[1] INFORMASI SISTEM"
    uname -a
    echo
    if [ -f /etc/os-release ]; then
        cat /etc/os-release
    else
        warn "/etc/os-release tidak ditemukan"
    fi

    section "[2] CEK COMMAND PENDUKUNG"
    for cmd in uname modinfo lsmod sysctl unshare modprobe rmmod dmesg ip grep awk sed tee; do
        check_command "$cmd"
    done

    section "[3] CEK VERSI KERNEL"
    KERNEL="$(uname -r)"
    echo -e "Kernel aktif: ${BOLD}$KERNEL${NC}"

    case "$KERNEL" in
        6.*|7.*)
            warn "Kernel modern terdeteksi. Jika belum dipatch, perlu audit lebih lanjut."
            ;;
        *)
            info "Kernel tidak otomatis dikategorikan dari pola sederhana ini."
            ;;
    esac

    section "[4] CEK MODULE TERSEDIA"
    check_module_available esp4
    echo
    check_module_available esp6
    echo
    check_module_available rxrpc

    section "[5] CEK MODULE AKTIF"
    lsmod | grep -E 'rxrpc|esp4|esp6|xfrm_algo|xfrm_user|udp_tunnel|ip6_udp_tunnel' || true
    echo

    RXRPC_ACTIVE=0
    ESP4_ACTIVE=0
    ESP6_ACTIVE=0

    check_module_loaded rxrpc && RXRPC_ACTIVE=1
    check_module_loaded esp4 && ESP4_ACTIVE=1
    check_module_loaded esp6 && ESP6_ACTIVE=1

    section "[6] CEK NAMESPACE DAN APPARMOR"
    sysctl kernel.unprivileged_userns_clone 2>/dev/null || warn "Tidak bisa membaca kernel.unprivileged_userns_clone"

    if [ -f /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]; then
        echo -n "apparmor_restrict_unprivileged_userns = "
        cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns
    else
        info "File AppArmor userns restriction tidak ditemukan."
    fi

    echo
    info "Menguji user namespace dengan unshare -Ur true"
    ERRFILE="$(mktemp /tmp/cekrentankarnel_userns.XXXXXX)"

    if unshare -Ur true 2>"$ERRFILE"; then
        warn "User namespace berhasil dibuat oleh user ini."
    else
        warn "User namespace dibatasi atau gagal dibuat."
        cat "$ERRFILE"
    fi

    rm -f "$ERRFILE"

    section "[7] CEK LOG RXRPC"
    if [ "$EUID" -eq 0 ]; then
        dmesg | grep -i rxrpc | tail -12 || info "Tidak ada log rxrpc di dmesg."
    else
        warn "Tidak root. Gunakan sudo untuk membaca dmesg."
        echo "Contoh: sudo dmesg | grep -i rxrpc | tail -12"
    fi

    section "[8] CEK XFRM STATE DAN POLICY"
    if [ "$EUID" -eq 0 ]; then
        echo -e "${BOLD}XFRM state:${NC}"
        ip xfrm state 2>/dev/null || warn "Tidak bisa membaca xfrm state."
        echo
        echo -e "${BOLD}XFRM policy:${NC}"
        ip xfrm policy 2>/dev/null || warn "Tidak bisa membaca xfrm policy."
    else
        warn "Tidak root. Gunakan sudo untuk membaca XFRM state/policy."
        echo "Contoh: sudo ip xfrm state"
    fi

    section "[9] RINGKASAN RISIKO"

    if [ "$RXRPC_ACTIVE" -eq 1 ] || [ "$ESP4_ACTIVE" -eq 1 ] || [ "$ESP6_ACTIVE" -eq 1 ]; then
        warn "Attack surface Dirty Frag masih aktif."
    else
        ok "Module utama target tidak aktif."
    fi

    if [ "$RXRPC_ACTIVE" -eq 1 ]; then
        warn "rxrpc aktif"
    else
        ok "rxrpc tidak aktif"
    fi

    if [ "$ESP4_ACTIVE" -eq 1 ]; then
        warn "esp4 aktif"
    else
        ok "esp4 tidak aktif"
    fi

    if [ "$ESP6_ACTIVE" -eq 1 ]; then
        warn "esp6 aktif"
    else
        ok "esp6 tidak aktif"
    fi

    echo
    warn "Jika kernel belum dipatch vendor, sistem tetap perlu dianggap berisiko."
    info "Untuk mitigasi sementara: sudo ./cekrentankarnel.sh mitigasi"
}

run_mitigasi() {
    banner

    if [ "$EUID" -ne 0 ]; then
        err "Mode mitigasi harus dijalankan sebagai root."
        echo "Gunakan: sudo ./cekrentankarnel.sh mitigasi"
        exit 1
    fi

    section "[1] MEMBUAT BLACKLIST MODULE"

    tee /etc/modprobe.d/dirtyfrag.conf >/dev/null <<'EOF'
install esp4 /bin/false
install esp6 /bin/false
install rxrpc /bin/false
EOF

    ok "Blacklist dibuat: /etc/modprobe.d/dirtyfrag.conf"

    section "[2] UNLOAD MODULE"

    rmmod esp4 2>/dev/null && ok "esp4 di-unload" || warn "esp4 tidak aktif atau gagal unload"
    rmmod esp6 2>/dev/null && ok "esp6 di-unload" || warn "esp6 tidak aktif atau gagal unload"
    rmmod rxrpc 2>/dev/null && ok "rxrpc di-unload" || warn "rxrpc tidak aktif atau gagal unload"

    section "[3] DROP PAGE CACHE"

    echo 3 > /proc/sys/vm/drop_caches
    ok "Page cache dibersihkan"

    section "[4] VERIFIKASI"

    if lsmod | grep -E 'rxrpc|esp4|esp6'; then
        warn "Masih ada module target aktif."
    else
        ok "Module rxrpc, esp4, dan esp6 tidak aktif."
    fi

    echo
    info "Jalankan ulang audit:"
    echo "  sudo ./cekrentankarnel.sh start"
}

run_restore() {
    banner

    if [ "$EUID" -ne 0 ]; then
        err "Mode restore harus dijalankan sebagai root."
        echo "Gunakan: sudo ./cekrentankarnel.sh restore"
        exit 1
    fi

    section "[1] MENGHAPUS BLACKLIST"

    if [ -f /etc/modprobe.d/dirtyfrag.conf ]; then
        rm -f /etc/modprobe.d/dirtyfrag.conf
        ok "Blacklist dihapus."
    else
        warn "Blacklist tidak ditemukan."
    fi

    section "[2] STATUS"

    info "Module dapat diload kembali dengan:"
    echo "  sudo modprobe rxrpc"
    echo "  sudo modprobe esp4"
    echo "  sudo modprobe esp6"
}

run_simulasi() {
    banner

    section "[SIMULASI AMAN]"
    warn "Mode ini tidak menjalankan privilege escalation."
    warn "Mode ini hanya compile dan observasi metadata binary."
    echo

    if [ ! -f exp.c ]; then
        err "File exp.c tidak ditemukan di direktori ini."
        echo "Pastikan Anda berada di folder repo yang berisi exp.c"
        exit 1
    fi

    section "[1] COMPILE SOURCE OBSERVASI"

    if gcc -O0 -Wall -o exp exp.c -lutil; then
        ok "Compile berhasil: ./exp"
    else
        err "Compile gagal."
        exit 1
    fi

    section "[2] INFORMASI BINARY"
    file exp || true
    ls -lh exp || true

    section "[3] STRINGS AWAL"
    strings exp | head -30 || true

    section "[4] SARAN OBSERVASI DEFENSIF"
    echo "Buka terminal lain:"
    echo -e "  ${BOLD}sudo journalctl -kf${NC}"
    echo
    echo "Observasi syscall secara hati-hati:"
    echo -e "  ${BOLD}strace -f -e unshare,keyctl,splice,vmsplice ./exp${NC}"
    echo
    warn "Jangan jalankan pada sistem produksi."
    warn "Gunakan snapshot VM sebelum eksperimen apa pun."
}

case "${1:-help}" in
    start)
        run_start
        ;;
    mitigasi)
        run_mitigasi
        ;;
    restore)
        run_restore
        ;;
    simulasi)
        run_simulasi
        ;;
    status)
        run_status
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        err "Perintah tidak dikenal: $1"
        echo
        show_help
        exit 1
        ;;
esac