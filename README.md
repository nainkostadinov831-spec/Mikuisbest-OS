# Mikoisbest OS v1 — Build Specification

A reproducible, Debian-based Live ISO for privacy practice and defensive
network-security learning, built with `live-build`.

**Verified as of this writing (2026-09-01):** Debian stable = **13 (trixie)**,
currently at point release 13.6. Debian testing is currently codenamed
**forky**. Verify this hasn't changed before you build:
`https://www.debian.org/releases/` — package versions and even codenames
drift over a multi-year distro lifecycle, so re-check this page every time
you rebuild from scratch after a gap of months.

---

## A. Architecture Overview

Mikoisbest OS is not a new distribution in the technical sense — it is a
**live-build recipe** that assembles an ordinary Debian 13 (trixie) chroot,
installs XFCE plus a curated package list, applies a small number of
configuration hooks, and packages the result as a hybrid ISO (BIOS + UEFI)
using `live-boot`/`live-config` for the live-session logic and SquashFS for
the compressed filesystem.

Layers, bottom to top:

1. **Base layer** — Debian 13 `bootstrap` (debootstrap), `main` + `contrib`
   + `non-free-firmware` archive areas (firmware is required for real Wi-Fi/
   graphics hardware on a live USB).
2. **Desktop layer** — `task-xfce-desktop` plus NetworkManager, a terminal,
   file manager, browser, archive tools, basic dev utilities.
3. **Privacy layer** — `tor`, `torbrowser-launcher`, `torsocks`,
   `proxychains-ng`, `macchanger`, DNS-leak-aware resolver config.
4. **Analysis layer** — `wireshark`, `tshark`, `nmap`, supporting diagnostics.
5. **Wireless-audit layer** — `aircrack-ng`, `kismet`, `hostapd`,
   monitor-mode tooling, restricted to authorized/lab use.
6. **Password-audit layer** — `john`, `hashcat`, `hydra` (all Debian-packaged,
   for use against test hashes/lab accounts only).
7. **Live-session layer** — `live-boot`, `live-config`, `live-tools`,
   `grub-efi`/`grub-pc` + `isolinux` for hybrid boot.

Nothing here is a novel kernel, init system, or package manager — it's
stock Debian + curation + a few hooks. This keeps it inside Debian's
security-update pipeline, which is the most important property for a
"privacy and security learning" distro to have.

### Why Stable over Testing

Debian **Stable (trixie)** is used, not Testing (forky), because:

- Stable receives coordinated security advisories via `security.debian.org`;
  Testing does not have a dedicated, timely security team — fixes land only
  when they migrate from unstable, which can take days to weeks.
- `live-build` itself is far more predictably reproducible against a frozen
  archive; Testing's package set shifts under you between builds.
- A security-education ISO should not itself be the least-audited part of
  your toolkit. The mild version lag on tools like Wireshark/Nmap in Stable
  is a reasonable trade for a security-patched base.
- Backports (`trixie-backports`) is available if you specifically need a
  newer version of one tool later — safer than switching the whole base to
  Testing.

The only reason to prefer Testing here would be needing hardware support
(newer kernel/firmware) not yet in Stable. If your build machine's Wi-Fi or
GPU isn't recognized by trixie's kernel, that's the trigger to reconsider —
otherwise stay on Stable.

---

## B. Tool Selection Table

Verify package names against `https://packages.debian.org/trixie/<pkg>`
before every build — do not trust this table blindly on a future rebuild.

| Tool | Purpose | Debian Package? | Source | Maintenance Risk |
|---|---|---|---|---|
| XFCE | Lightweight desktop | Yes (`task-xfce-desktop`) | Debian main | Low |
| NetworkManager | Network config | Yes (`network-manager`) | Debian main | Low |
| Tor | Anonymizing overlay network daemon | Yes (`tor`) | Debian main | Low |
| Tor Browser | Hardened, torified browser | Yes, *launcher only* (`torbrowser-launcher`, in `contrib`) | Debian contrib; actual browser binary is fetched + GPG-verified from torproject.org **at first run**, not baked into the ISO | Low (launcher), Medium (requires network at first boot) |
| torsocks | Force a single app through Tor | Yes (`torsocks`) | Debian main | Low |
| proxychains-ng | Chain app traffic through proxies | Yes (`proxychains-ng`) | Debian main | Low |
| macchanger | MAC address randomization | Yes (`macchanger`) | Debian main | Low |
| Wireshark | GUI packet capture/analysis | Yes (`wireshark`) | Debian main | Low |
| TShark | CLI packet capture/analysis | Yes (`tshark`) | Debian main | Low |
| Nmap | Host/service discovery, port scanning | Yes (`nmap`) | Debian main | Low |
| Aircrack-ng | Wi-Fi frame capture/analysis suite | Yes (`aircrack-ng`) | Debian main | Low–Medium (needs monitor-mode-capable adapter) |
| Kismet | Passive Wi-Fi/Bluetooth spectrum monitor | Yes (`kismet`) | Debian main | Low |
| hostapd | Build a controlled lab access point | Yes (`hostapd`) | Debian main | Low |
| John the Ripper | Offline password-hash auditing | Yes (`john`) | Debian main | Low |
| hashcat | GPU-accelerated hash auditing | Yes (`hashcat`) | Debian main | Low |
| THC-Hydra | Online credential-testing (lab use only) | Yes (`hydra`) | Debian main | Low |
| AnonSurf | "Torify the whole OS" wrapper | **No** | Third-party (ParrotOS project), install via unverified script | **High — excluded, see below** |

### On AnonSurf (excluded by design)

AnonSurf is a ParrotOS-specific shell wrapper around `iptables` + `tor`,
distributed as a script users are told to clone and run as root from GitHub.
Per your own instructions and general good practice: **never blindly execute
an unverified remote script as root**, and this project doesn't. Concretely:

- It is not an official Debian package, so it gets no Debian security
  coverage and no `apt` upgrade path.
- It is tuned for Parrot's specific network stack; behavior on a customized
  trixie system isn't guaranteed.
- Its actual function — route all system traffic through Tor via iptables
  rules plus DNS redirection — is fully reproducible using stock Debian
  tools (`tor`, `iptables`/`nftables`, `resolvconf`) without importing
  unaudited third-party root scripts.

Instead, `hooks/live/0300-torify-toggle.hook.chroot` installs a small,
readable, native script (`/usr/local/sbin/mikoisbest-torify`) that does the
same iptables-transparent-proxy job using only packaged components, so you
can read every line of it before running it.

**Important — what "torifying the OS" does and does not do:**

- Tor protects the network path of *torified* traffic between you and the
  Tor exit relay (or the destination, for onion services) — it hides your
  IP from the destination and hides the destination from your ISP.
- Tor does **not** anonymize applications that leak identity another way:
  browser fingerprinting, logged-in accounts, JavaScript/WebRTC leaks,
  timestamps, file metadata, or anything you type that identifies you.
- System-wide iptables torification stops *IP-layer* leaks for TCP; it does
  **not** by itself stop DNS leaks (you need the resolver forced through
  Tor's DNS or a local `unbound`/`dnscrypt` config that never queries your
  normal DNS), and UDP-based apps generally break or leak outside Tor
  entirely, since Tor is TCP-only.
- Browser fingerprinting (screen size, fonts, canvas, timezone) is *not*
  solved by Tor at the network layer — that's what Tor Browser's uniform
  fingerprint surface is for, which is why Tor Browser is the recommended
  browser here, not "any browser plus Tor for the network."
- None of this replaces full-disk encryption, safe browsing habits, or
  understanding what metadata your own files carry.

---

## C. Build Method Decision

| Criterion | live-build | Cubic | Linux Live Kit |
|---|---|---|---|
| Reproducibility | High — declarative config directory, scriptable, diffable | Low — GUI/manual session, hard to version | Medium — script-driven but distro-agnostic, less Debian-aware |
| Debian compatibility | Native, maintained by Debian Live team | Ubuntu-focused, works on Debian with friction | Not Debian-specific |
| Maintainability | Config lives in plain text/git | GUI state doesn't diff/version well | Shell-script based, workable but no package-list abstraction |
| Automation (CI, headless) | Fully scriptable, no GUI required | Needs interactive GUI session | Scriptable |
| UEFI/BIOS support | Both, via `--bootloaders` | Both (inherited from base ISO) | Manual setup required |
| Live ISO support | Purpose-built for this | Purpose-built for this | Purpose-built for this |
| Package management | Native `apt`/`debootstrap` integration | Native (uses installed system) | Distro-agnostic, less integrated |
| Future updates | `lb clean && lb build` reproduces from config | Re-run the whole manual GUI flow | Re-run scripts, less structured |

**Decision: `live-build`.** It's the Debian Live team's own tool, purpose-
built for exactly this (Debian-based, hybrid-boot, live/installable ISOs),
fully scriptable/reproducible from a plain-text `config/` tree, and it's
what this spec uses throughout.

---

## D. Project Directory Tree

```
mikoisbest-os/
├── README.md                          # this document
├── build.sh                           # top-level orchestrator (checks + lb build)
├── scripts/
│   ├── 00-prepare-host.sh             # install build deps on a clean Debian host
│   ├── 01-init-config.sh              # runs `lb config` with pinned options
│   ├── 02-checksum-and-verify.sh      # sha256sum + verification
│   └── 03-test-qemu.sh                # boot the ISO in QEMU
├── config-src/
│   ├── package-lists/
│   │   └── mikoisbest.list.chroot     # explicit package list installed into the ISO
│   └── hooks/
│       └── live/
│           ├── 0100-disable-tor-autostart.hook.chroot
│           ├── 0200-motd-branding.hook.chroot
│           └── 0300-torify-toggle.hook.chroot
└── (generated at build time by `lb config`, not stored in git as-is)
    config/                            # full live-build config tree
    .build/                            # live-build state
    *.iso, *.img, *.log                # build output
```

`config-src/` holds the *source of truth* files this project maintains by
hand. `scripts/01-init-config.sh` runs `lb config` to generate the full
`config/` tree that `live-build` actually reads, then copies the
`config-src/` files into their proper place inside it — this keeps a clean
git diff instead of committing live-build's large generated tree.

- `package-lists/*.list.chroot` — package lists live-build installs with
  `apt` inside the chroot during build.
- `hooks/live/*.hook.chroot` — shell scripts run *inside* the chroot at
  build time, in filename order, for post-install configuration.
- `includes.chroot/` (created under `config/`) — files copied verbatim into
  the target filesystem (e.g. `/etc/motd`, wallpaper, default configs).

---

## E. Build Files

See the files delivered alongside this README:
`build.sh`, `scripts/00-prepare-host.sh`, `scripts/01-init-config.sh`,
`scripts/02-checksum-and-verify.sh`, `scripts/03-test-qemu.sh`,
`config-src/package-lists/mikoisbest.list.chroot`, and the three hooks
under `config-src/hooks/live/`.

---

## F. Complete Build Procedure

Run these **in order**, on a clean Debian 13 (trixie) machine. Each is a
separate command/block; do not skip any.

**1. Confirm you're on Debian 13 (trixie) and have a non-root sudo user**

```bash
cat /etc/os-release
```

**2. Update the base system**

```bash
sudo apt update && sudo apt full-upgrade -y
```

**3. Clone/copy this project onto the build machine, then enter it**

```bash
cd ~/mikoisbest-os
```

**4. Run the host-preparation script (installs live-build + deps, checks arch/release)**

```bash
sudo bash scripts/00-prepare-host.sh
```

**5. Initialize the live-build config tree (pinned options, hybrid boot)**

```bash
bash scripts/01-init-config.sh
```

**6. Review the generated package list before building**

```bash
cat config/package-lists/mikoisbest.list.chroot
```

**7. Review the hooks that will run inside the chroot**

```bash
ls -la config/hooks/live/
```

**8. Run the build (must be root; this is the long step)**

```bash
sudo bash build.sh
```

**9. Locate the resulting ISO**

```bash
ls -la live-image-amd64.hybrid.iso
```

**10. Rename it to the required final name**

```bash
mv live-image-amd64.hybrid.iso Mikoisbest_OS_v1.iso
```

**11. Generate the SHA-256 checksum**

```bash
sha256sum Mikoisbest_OS_v1.iso | tee Mikoisbest_OS_v1.iso.sha256
```

**12. Verify the checksum matches**

```bash
sha256sum -c Mikoisbest_OS_v1.iso.sha256
```

**13. Test-boot the ISO in QEMU before touching real hardware**

```bash
bash scripts/03-test-qemu.sh Mikoisbest_OS_v1.iso
```

**14. Only after QEMU boot succeeds — write to a USB drive for physical testing**
*(destructive step; not part of any script in this project — you must run
it deliberately, and double/triple-check `/dev/sdX` is the USB drive and
not your build machine's disk before running it)*

```bash
sudo dd if=Mikoisbest_OS_v1.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

---

## F.1 Alternative: Building in GitHub Actions (cloud, no local Debian host needed)

`.github/workflows/build-iso.yml` runs the same `scripts/00` → `01` →
`build.sh` sequence on a GitHub-hosted `ubuntu-latest` runner instead of
your own machine.

1. Push this project to a GitHub repo (private is fine).
2. Repo → **Actions** tab → select the workflow → **Run workflow**.
3. When it finishes, download `Mikoisbest_OS_v1` from the **Artifacts**
   section of that run.

Known limitations of this path:

- Free-tier runners have ~14GB free disk by default; the workflow's
  "Free up disk space" step removes preinstalled Android SDK/.NET/etc. to
  make room, but a much larger package list could still run out.
- Nested virtualization/KVM generally isn't available on GitHub-hosted
  runners, so `scripts/03-test-qemu.sh` is skipped in CI — always run it
  yourself locally on the downloaded ISO before writing it to a USB drive.
- Private repos have a monthly free minutes quota, then billed; public
  repos run Actions for free.
- `scripts/00-prepare-host.sh`'s Debian-release check is a warning, not a
  hard stop, when there's no TTY (CI) — the *target* OS built by
  `live-build` is still Debian trixie regardless of the Ubuntu host running
  the build.

---

## G. ISO Validation Checklist

- [ ] `Mikoisbest_OS_v1.iso` exists and is >0 bytes
- [ ] `file Mikoisbest_OS_v1.iso` reports a valid ISO 9660/hybrid boot sector
- [ ] `Mikoisbest_OS_v1.iso.sha256` generated and `sha256sum -c` passes
- [ ] Boots to a graphical XFCE session in QEMU (BIOS mode)
- [ ] Boots via UEFI in QEMU using OVMF firmware (see `scripts/03-test-qemu.sh -u`)
- [ ] NetworkManager brings up a network interface in the live session
- [ ] `apt update` works inside the live session (confirms archive access + package manager health)
- [ ] Wireshark, TShark, Nmap, Aircrack-ng, Kismet, John, Hashcat, Hydra all launch/run `--version` without error
- [ ] `tor` service starts manually (`sudo systemctl start tor`) and `curl --socks5 127.0.0.1:9050 https://check.torproject.org` confirms Tor connectivity — confirming Tor works without silently auto-enabling it by default (see hook 0100)
- [ ] Tor Browser Launcher downloads and GPG-verifies successfully (requires network)
- [ ] `uname -m` reports `x86_64` (or your target arch) as expected
- [ ] No package reported "unable to locate" or failed post-install script during build (grep the build log — see troubleshooting)

### Testing with QEMU first

`scripts/03-test-qemu.sh` boots the ISO with KVM acceleration if available.
Add `-u` to test UEFI (requires `ovmf` installed on the host: `sudo apt
install ovmf`). QEMU testing catches most boot, bootloader, and driver
problems in seconds instead of the minutes-per-attempt cost of physical USB
testing, and it's non-destructive — always test here first.

---

## H. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `lb: command not found` | `live-build` package not installed, or not in `$PATH` | `sudo apt install live-build`; re-run `scripts/00-prepare-host.sh` |
| `E: Unable to locate package X` during `lb build` | Package name wrong, or archive area (`contrib`/`non-free-firmware`) not enabled | Check `https://packages.debian.org/trixie/X`; confirm `--archive-areas` in `scripts/01-init-config.sh` includes the right area |
| Repository fetch failures mid-build | Transient mirror issue or stale `apt` cache in chroot | Re-run `sudo lb clean --purge && sudo bash build.sh` |
| GPG/signature verification failure | Corrupted archive keyring, clock skew, or MITM'd mirror | Check `date`; `sudo apt install --reinstall debian-archive-keyring`; retry on a different mirror |
| Build fails referencing a GitHub source | This project deliberately doesn't pull unverified GitHub scripts — if you've added one, remove it or pin+verify a specific signed release | N/A by design |
| `lb build` finishes but no ISO appears | Build aborted partway (check the log); or wrong output filename expected | `grep -i error build.log`; re-run with `sudo bash build.sh 2>&1 | tee build.log` |
| ISO boots to a black screen / no bootloader menu | ISO wasn't hybrid-built, or `dd` was interrupted/wrong device | Re-verify `sha256sum`; rebuild with `--bootloaders` unset (defaults to hybrid) confirmed in `01-init-config.sh` |
| UEFI boot fails but BIOS boot works | Missing `grub-efi-amd64-bin` in build deps, or Secure Boot blocking unsigned bootloader | `apt install grub-efi-amd64-bin` on build host before `lb build`; disable Secure Boot for testing or use `shim-signed` path |
| No network in the live session | Missing firmware for your NIC, or NetworkManager not enabled | Confirm `non-free-firmware` archive area + relevant `firmware-*` package is in the package list; `systemctl status NetworkManager` inside live session |
| Desktop doesn't start (drops to console/TTY) | `task-xfce-desktop` failed to install, or display manager not enabled | Check build log for XFCE package failures; confirm `lightdm` (or chosen display manager) is enabled |
| `lb build` fails late with `Errors were encountered while processing: firmware-b43-installer / firmware-b43legacy-installer` | These packages try to fetch proprietary firmware from the internet during postinst inside the chroot, and that fetch fails (no network path, dead link, or no TTY for a prompt) | Pinned out via `config-src/archives/exclude-b43.pref.chroot` (Pin-Priority -1) and `--apt-recommends false` in `01-init-config.sh` — run `sudo lb clean --purge`, re-run `01-init-config.sh`, then `sudo bash build.sh` again |
| An expected application is missing from the ISO | Package name typo in `mikoisbest.list.chroot`, or it silently failed and build didn't fail | Grep build log for the package name; this project sets `set -euo pipefail` and checks `lb build`'s exit code specifically so this should hard-fail instead — if it didn't, file that as a bug in `build.sh` |

---

## I. Security Notes

- All network-analysis, wireless-audit, and password-auditing tools in this
  build are for use **only against systems, networks, and accounts you own
  or are explicitly authorized in writing to test.** Nothing in this project
  or its documentation is intended to enable unauthorized scanning,
  credential attacks, Wi-Fi disruption, or access to systems you don't
  control.
- Tor provides network-layer protection for torified traffic only — read
  section B's "what Tor does and does not do" before relying on it for
  anything sensitive.
- This spec deliberately never pipes a remote script into a shell as root.
  If you extend this project, keep that discipline: pin a specific,
  signed/checksummed release of anything you add from outside Debian's
  archive.
- `set -euo pipefail` is used throughout so any unexpected failure stops
  the build rather than producing a silently broken ISO.

---

## Reproducibility Notes

To rebuild identically later:

- Debian release is pinned to `trixie` in `scripts/01-init-config.sh` —
  don't let it silently track "stable" forever, since "stable" will
  eventually mean a different release. Re-pin deliberately when you choose
  to move to the next release.
- `config-src/package-lists/mikoisbest.list.chroot` is the single source of
  truth for installed packages — no packages should be added via ad hoc
  hook-script `apt install` calls outside this list.
- Record the build date and the output of `sha256sum Mikoisbest_OS_v1.iso`
  alongside the ISO for every build you keep.
- What changes safely over time: point-release package versions (13.x),
  mirror selection. What requires a deliberate decision, not an automatic
  update: moving to Debian 14 ("forky" → future stable), adding any
  non-Debian-packaged tool.
