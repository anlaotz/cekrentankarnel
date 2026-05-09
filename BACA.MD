# Dirty Frag Defensive Research Lab

<p align="center">
  <img src="assets/tux.png" width="180" alt="Dirty Frag">
</p>

<p align="center">
  <b>Dirty Frag Defensive Checker</b><br>
  Audit, Observasi, Mitigasi, dan Hardening Linux Kernel
</p>

---

# Disclaimer

⚠️ Repository ini dibuat untuk:

* penelitian defensif
* audit keamanan kernel Linux
* observasi behavior subsystem kernel
* incident response
* hardening Linux
* pembelajaran keamanan sistem operasi

Bukan untuk penggunaan terhadap sistem tanpa izin.

Gunakan hanya pada:

* VM terisolasi
* environment lab
* sistem milik sendiri

Selalu gunakan snapshot sebelum pengujian.

---

# Fitur

## cekrentankarnel.sh

Script utama mendukung:

| Mode     | Fungsi                    |
| -------- | ------------------------- |
| start    | audit defensif kernel     |
| status   | status cepat subsystem    |
| mitigasi | blacklist & unload module |
| restore  | restore mitigasi          |
| simulasi | compile & observasi aman  |
| help     | bantuan penggunaan        |

---

## Apa Itu Dirty Frag?

Dirty Frag adalah kelas kerentanan Local Privilege Escalation (LPE) pada kernel Linux yang memungkinkan user biasa memperoleh hak akses root melalui manipulasi page cache kernel menggunakan subsystem networking Linux.

Dirty Frag merupakan turunan dari bug class yang sama dengan:

* Dirty Pipe
* Copy Fail

Kerentanan ini memanfaatkan:

* RxRPC subsystem
* XFRM/IPsec ESP subsystem
* namespace interaction
* page cache overwrite primitive

Pada beberapa distribusi Linux modern, kombinasi subsystem tersebut dapat digunakan untuk melakukan privilege escalation dari:

```text
uid=1000 → uid=0
```

---

# Masalah Utama

Masalah utama Dirty Frag adalah:

* module rentan aktif secara default
* attack surface tersedia pada banyak distro besar
* exploit bersifat deterministic
* tidak memerlukan race condition
* namespace dan networking subsystem dapat dipakai untuk memodifikasi page cache
* attacker lokal dapat memperoleh akses root

Subsystem utama yang terkait:

| Subsystem      | Fungsi                     |
| -------------- | -------------------------- |
| rxrpc          | protocol networking        |
| esp4 / esp6    | IPsec ESP transformation   |
| xfrm_algo      | crypto/XFRM framework      |
| PF_ALG         | userspace crypto interface |
| user namespace | privilege boundary         |

---

# Tujuan Lab

Lab ini dibuat untuk:

* analisis defensif Dirty Frag
* audit kernel Linux
* observasi AppArmor
* observasi RxRPC/XFRM
* incident response simulation
* detection engineering
* hardening Linux
* validasi mitigasi

Lab ini TIDAK dibuat untuk menyerang sistem lain.

---

## Deskripsi

Repository/lab ini digunakan untuk:

* Audit defensif Dirty Frag
* Validasi attack surface kernel Linux
* Observasi behavior AppArmor
* Observasi RxRPC/XFRM subsystem
* Validasi mitigasi sementara
* Monitoring kernel log
* Incident response & detection engineering

⚠️ Penting:

Lab ini ditujukan untuk:

* lingkungan VM terisolasi
* penelitian defensif
* pembelajaran keamanan kernel
* hardening Linux

Bukan untuk penggunaan terhadap sistem yang tidak memiliki izin.

---

# Environment Pengujian

## Sistem Operasi

* Ubuntu 24.04.3 LTS

## Kernel

```bash
uname -r
6.8.0-101-generic
```

## Hypervisor

* VirtualBox

---

# Struktur Repository

```text
.
├── assets/
│   ├── demo.gif
│   ├── tux.png
│   └── write-up.md
├── cekrentankarnel.sh
├── exp.c
└── README.md
```

---

# Instalasi

## Clone Repository

```bash
git clone https://github.com/anlaotz/cekrentankarnel
cd cekrentankarnel
```

## Permission Script

```bash
chmod +x cekrentankarnel.sh
```

---

# Penggunaan Cepat

## Help

```bash
./cekrentankarnel.sh -h
```

## Audit Defensif

```bash
sudo ./cekrentankarnel.sh start
```

## Status Cepat

```bash
./cekrentankarnel.sh status
```

## Mitigasi

```bash
sudo ./cekrentankarnel.sh mitigasi
```

## Restore Mitigasi

```bash
sudo ./cekrentankarnel.sh restore
```

## Simulasi Aman

```bash
./cekrentankarnel.sh simulasi
```

---

# Struktur File

```text
.
├── exp.c
├── cekrentankarnel.sh
└── README.md
```

---

# Persiapan Lab

## 1. Buat Snapshot VM

Di VirtualBox:

```text
Machine → Take Snapshot
```

Nama:

```text
dirtyfrag-clean
```

---

# Permission Script

```bash
chmod +x cekrentankarnel.sh
```

---

# Bantuan Script

```bash
./cekrentankarnel.sh -h
```

atau:

```bash
./cekrentankarnel.sh help
```

---

# Audit Defensif

## Menjalankan Audit

```bash
./cekrentankarnel.sh start
```

Script akan:

* cek versi kernel
* cek distro
* cek module:

  * esp4
  * esp6
  * rxrpc
* cek namespace
* cek AppArmor
* cek RxRPC logs
* cek XFRM state
* cek module aktif

---

# Monitoring Kernel

Buka terminal kedua:

```bash
sudo journalctl -kf
```

Perhatikan event seperti:

```text
Registered PF_RXRPC protocol family
Registered PF_ALG protocol family
operation="userns_create"
capname="sys_admin"
```

---

# Namespace Testing

## User Namespace

```bash
unshare -Ur bash
```

Pada Ubuntu + AppArmor biasanya:

```text
write failed /proc/self/uid_map: Operation not permitted
```

---

# Module Testing

## Load Module

```bash
sudo modprobe rxrpc
sudo modprobe esp4
sudo modprobe esp6
```

## Verifikasi

```bash
lsmod | grep -E 'rxrpc|esp4|esp6'
```

Contoh hasil:

```text
esp6
esp4
xfrm_algo
rxrpc
```

---

# Observasi Kernel Module

## Informasi Module

```bash
modinfo esp4
modinfo esp6
modinfo rxrpc
```

## Dependency

```bash
modinfo esp4 | grep depends
```

---

# IOC (Indicators of Compromise)

Perhatikan IOC berikut:

| IOC                 | Keterangan                    |
| ------------------- | ----------------------------- |
| PF_RXRPC            | RxRPC aktif                   |
| PF_ALG              | crypto subsystem aktif        |
| userns_create       | namespace creation            |
| capname="sys_admin" | capability escalation attempt |
| rxrpc registered    | RxRPC keyring aktif           |

---

# Mitigasi Sementara

## Menggunakan Script

```bash
./cekrentankarnel.sh mitigasi
```

Script akan:

* blacklist esp4
* blacklist esp6
* blacklist rxrpc
* unload module
* drop page cache

---

# Verifikasi Mitigasi

## Test modprobe

```bash
sudo modprobe rxrpc
```

Jika mitigasi berhasil:

```text
modprobe: ERROR
```

## Verifikasi lsmod

```bash
lsmod | grep -E 'rxrpc|esp4|esp6'
```

Harus kosong.

---

# Restore Mitigasi

```bash
./cekrentankarnel.sh restore
```

---

# Cleanup Setelah Pengujian

## Drop Cache

```bash
echo 3 | sudo tee /proc/sys/vm/drop_caches
```

## Reboot

```bash
sudo reboot
```

Atau rollback snapshot VirtualBox.

---

# Hardening Tambahan

## Disable User Namespace

Temporary:

```bash
sudo sysctl -w kernel.unprivileged_userns_clone=0
```

Permanent:

```bash
echo 'kernel.unprivileged_userns_clone=0' | sudo tee /etc/sysctl.d/99-userns.conf
```

---

# Tujuan Pembelajaran

Lab ini cocok untuk:

* Linux kernel security
* AppArmor behavior
* RxRPC subsystem
* XFRM/IPsec subsystem
* namespace security
* auditd monitoring
* eBPF tracing
* incident response
* detection engineering
* kernel hardening

---

# Catatan Penting

* Gunakan hanya di VM/lab terisolasi
* Jangan gunakan pada sistem produksi
* Selalu buat snapshot sebelum pengujian
* Selalu lakukan cleanup setelah observasi
* Selalu update kernel saat patch tersedia

---

# Workflow Analisis

## Tahap 1 — Audit Awal

```bash
sudo ./cekrentankarnel.sh start
```

Script akan memeriksa:

* versi kernel
* distro Linux
* module rentan
* AppArmor
* namespace
* RxRPC
* XFRM/IPsec
* kernel logs

---

## Tahap 2 — Monitoring Kernel

Buka terminal kedua:

```bash
sudo journalctl -kf
```

IOC yang penting:

```text
Registered PF_RXRPC protocol family
Registered PF_ALG protocol family
operation="userns_create"
capname="sys_admin"
```

---

## Tahap 3 — Observasi Namespace

```bash
unshare -Ur bash
```

Pada Ubuntu modern biasanya:

```text
write failed /proc/self/uid_map
```

karena AppArmor restriction.

---

## Tahap 4 — Load Module

```bash
sudo modprobe rxrpc
sudo modprobe esp4
sudo modprobe esp6
```

Verifikasi:

```bash
lsmod | grep -E 'rxrpc|esp4|esp6'
```

---

## Tahap 5 — Simulasi Aman

```bash
./cekrentankarnel.sh simulasi
```

Mode simulasi:

* compile source observasi
* melihat metadata binary
* observasi syscall
* TIDAK menjalankan privilege escalation

---

# Hasil Validasi Lab

## Sebelum Mitigasi

Hasil audit menunjukkan:

```text
rxrpc aktif
esp4 aktif
esp6 aktif
```

Kernel log menunjukkan:

```text
NET: Registered PF_RXRPC protocol family
Key type rxrpc registered
Key type rxrpc_s registered
```

Artinya:

* subsystem RxRPC aktif
* ESP/XFRM aktif
* attack surface tersedia
* environment cocok dengan karakteristik Dirty Frag

---

## Observasi Validasi Lab

Pada lab VM Ubuntu 24.04 kernel 6.8:

* user biasa memiliki:

```text
uid=1000(and)
```

* observasi kernel menunjukkan interaction:

```text
operation="userns_create"
Registered PF_RXRPC protocol family
Registered PF_ALG protocol family
```

* validasi laboratorium menunjukkan privilege escalation berhasil terjadi pada environment pengujian terisolasi.

Bukti observasi:

```text
uid=0(root)
```

Hal ini menunjukkan:

* attack surface benar-benar reachable
* kernel subsystem aktif
* mitigasi diperlukan

⚠️ Catatan:

README ini tidak menyertakan langkah eksploitasi rinci. Fokus dokumentasi adalah:

* audit defensif
* observasi kernel
* validasi mitigasi
* incident response
* hardening

---

## Sesudah Mitigasi

Setelah menjalankan:

```bash
./cekrentankarnel.sh mitigasi
```

hasil audit berubah menjadi:

```text
rxrpc tidak aktif
esp4 tidak aktif
esp6 tidak aktif
```

Kernel log menunjukkan:

```text
NET: Unregistered PF_RXRPC protocol family
Key type rxrpc unregistered
```

Artinya:

* subsystem RxRPC berhasil dimatikan
* attack surface dipersempit
* mitigasi berhasil diterapkan

---

# Setelah Mitigasi

Setelah:

```bash
sudo ./cekrentankarnel.sh mitigasi
```

hasil audit menunjukkan:

```text
rxrpc tidak aktif
esp4 tidak aktif
esp6 tidak aktif
```

Kernel log:

```text
NET: Unregistered PF_RXRPC protocol family
Key type rxrpc unregistered
```

Artinya:

* subsystem berhasil dimatikan
* attack surface dipersempit
* mitigasi berhasil diterapkan

---

# Hardening Tambahan

## Disable User Namespace

Temporary:

```bash
sudo sysctl -w kernel.unprivileged_userns_clone=0
```

Permanent:

```bash
echo 'kernel.unprivileged_userns_clone=0' | sudo tee /etc/sysctl.d/99-userns.conf
```

---

# IOC (Indicators of Compromise)

| IOC                 | Keterangan                    |
| ------------------- | ----------------------------- |
| PF_RXRPC            | RxRPC protocol aktif          |
| PF_ALG              | crypto subsystem aktif        |
| userns_create       | namespace creation            |
| capname="sys_admin" | capability escalation attempt |
| rxrpc registered    | RxRPC keyring aktif           |

---

# Tujuan Pembelajaran

Repository/lab ini cocok untuk:

* Linux kernel security
* AppArmor analysis
* RxRPC subsystem
* XFRM/IPsec subsystem
* namespace security
* auditd monitoring
* eBPF tracing
* incident response
* detection engineering
* kernel hardening

---

# Catatan Penting

* Gunakan hanya di VM/lab terisolasi
* Jangan gunakan pada sistem produksi
* Selalu buat snapshot sebelum pengujian
* Selalu lakukan cleanup setelah observasi
* Selalu update kernel saat patch tersedia
* Selalu reboot atau rollback snapshot setelah eksperimen

---

# Ringkasan

Environment Ubuntu 24.04 kernel 6.8 pada lab ini menunjukkan:

* attack surface tersedia
* rxrpc tersedia
* esp4/esp6 tersedia
* namespace interaction aktif
* AppArmor restriction aktif
* cocok untuk penelitian defensif Dirty Frag
