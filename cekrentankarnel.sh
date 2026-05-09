#!/usr/bin/env bash
# ======================================================
# cekrentankarnel.sh
# Dirty Frag / Kernel Exposure Checker (Defensive Only)
# ======================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_banner() {
    echo -e "${BLUE}"
    echo "======================================================"
    echo "   Dirty Frag Defensive Checker"
    echo "   Ubuntu / Linux Kernel Exposure Audit"
    echo "======================================================"
    echo -e "${NC}"
}

show_help() {
    show_banner
    cat <<EOF
Penggunaan:

  ./cekrentankarnel.sh start
  ./cekrentankarnel.sh mitigasi
  ./cekrentankarnel.sh restore
  ./cekrentankarnel.sh help
  ./cekrentankarnel.sh -h

Perintah:

  start
      Menjalankan audit defensif Dirty Frag:
      - Cek kernel
      - Cek distro
      - Cek module esp4/esp6/rxrpc
      - Cek namespace
      - Cek AppArmor
      - Cek apakah module aktif

  mitigasi
      Membuat blacklist module:
      - esp4
      - esp6
      - rxrpc

      Lalu unload module dan drop cache.

  restore
      Menghapus mitigasi blacklist.

  help / -h
      Menampilkan bantuan.

Catatan:

  Script ini TIDAK menjalankan exploit.
  Script hanya untuk audit defensif dan mitigasi.

EOF
}

status_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

status_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

status_err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_check() {
    show_banner

    echo "[1] Informasi Sistem"
    echo "------------------------------------------------------"
    uname -a
    echo
    cat /etc/os-release
    echo

    echo "[2] Kernel Version"
    echo "------------------------------------------------------"
    KERNEL=$(uname -r)
    echo "Kernel: $KERNEL"
    echo

    echo "[3] Cek Module Tersedia"
    echo "------------------------------------------------------"

    for mod in esp4 esp6 rxrpc; do
        if modinfo "$mod" >/dev/null 2>&1; then
            status_ok "Module tersedia: $mod"
        else
            status_err "Module tidak ditemukan: $mod"
        fi
    done

    echo
    echo "[4] Cek Module Aktif"
    echo "------------------------------------------------------"

    lsmod | grep -E 'esp4|esp6|rxrpc|xfrm_algo' || true
    echo

    echo "[5] Cek Namespace"
    echo "------------------------------------------------------"

    sysctl kernel.unprivileged_userns_clone || true

    if [ -f /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]; then
        cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns
    fi

    echo
    echo "[6] Test User Namespace"
    echo "------------------------------------------------------"

    if unshare -Ur true 2>/tmp/userns_test.err; then
        status_ok "User namespace berhasil dibuat"
    else
        status_warn "User namespace dibatasi"
        cat /tmp/userns_test.err
    fi

    echo
    echo "[7] Cek RxRPC Kernel Logs"
    echo "------------------------------------------------------"

    dmesg | grep -i rxrpc | tail -10 || true

    echo
    echo "[8] Cek XFRM State"
    echo "------------------------------------------------------"

    ip xfrm state || true
    echo
    ip xfrm policy || true

    echo
    echo "[9] Ringkasan"
    echo "------------------------------------------------------"

    if lsmod | grep -q rxrpc; then
        status_warn "rxrpc aktif"
    fi

    if lsmod | grep -q esp4; then
        status_warn "esp4 aktif"
    fi

    if lsmod | grep -q esp6; then
        status_warn "esp6 aktif"
    fi

    echo
    status_warn "Jika kernel belum dipatch, sistem kemungkinan memiliki attack surface Dirty Frag"
    echo
}

run_mitigasi() {
    show_banner

    echo "[+] Membuat blacklist module"

    sudo tee /etc/modprobe.d/dirtyfrag.conf >/dev/null <<EOF
install esp4 /bin/false
install esp6 /bin/false
install rxrpc /bin/false
EOF

    status_ok "Blacklist dibuat"

    echo
    echo "[+] Unload module"

    sudo rmmod esp4 2>/dev/null || true
    sudo rmmod esp6 2>/dev/null || true
    sudo rmmod rxrpc 2>/dev/null || true

    status_ok "Module di-unload"

    echo
    echo "[+] Drop page cache"

    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null

    status_ok "Page cache dibersihkan"

    echo
    echo "[+] Verifikasi"

    if lsmod | grep -E 'esp4|esp6|rxrpc'; then
        status_warn "Masih ada module aktif"
    else
        status_ok "Semua module berhasil dimatikan"
    fi
}

run_restore() {
    show_banner

    echo "[+] Menghapus mitigasi"

    sudo rm -f /etc/modprobe.d/dirtyfrag.conf

    status_ok "Blacklist dihapus"

    echo
    echo "[+] Module dapat diload kembali menggunakan modprobe"
}

case "$1" in
    start)
        run_check
        ;;

    mitigasi)
        run_mitigasi
        ;;

    restore)
        run_restore
        ;;

    help|-h|--help|"")
        show_help
        ;;

    *)
        status_err "Perintah tidak dikenal: $1"
        echo
        show_help
        exit 1
        ;;
esac
