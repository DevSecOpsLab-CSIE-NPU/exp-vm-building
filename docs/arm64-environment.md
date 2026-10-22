# arm64 VM 環境清單（ai-coding-arm64）

記錄日期：2026-10-22。這是 Apple Silicon 上 VirtualBox 建置的 ARM64 版本，作為 Intel 版同步的對照基準。

## 作業系統與主機

| 項目 | 值 |
|---|---|
| 發行版 | Debian GNU/Linux 13 (trixie) |
| 核心 | 6.12.107+deb13-arm64 |
| 架構 | aarch64 |
| CPU | 2 |
| 記憶體 | 約 3.7 GB |
| 根分割區 | 14 GB（使用約 14%） |

## 使用者與權限

- 登入使用者：`student`（uid 1000）
- 群組：`student`、`sudo`、`users`、`docker`
- 免密碼 sudo：`/etc/sudoers.d/student-nopasswd`（`NOPASSWD: ALL`）
- 預設 shell：`/usr/bin/zsh`

## 網路

| 介面 | 位址 | 用途 |
|---|---|---|
| enp0s8 | 10.0.2.15/24（DHCP） | NAT，對外連線 |
| enp0s9 | 192.168.56.10/24（靜態） | host-only，Mac 連線用 |
| docker0 | 172.17.0.1/16 | Docker 預設橋接 |

enp0s9 的靜態設定寫在 `/etc/network/interfaces.d/enp0s9`。

## 工具與版本

| 工具 | 版本 | 狀態 |
|---|---|---|
| zsh | 5.9 | 已安裝，預設 shell |
| git | 2.47.3 | 已安裝 |
| gh | 2.46.0 | 已安裝 |
| curl | 8.14.1 | 已安裝 |
| sudo | 1.9.16p2 | 已安裝 |
| figlet | — | 已安裝（僅用於產生橫幅） |
| Docker | 26.1.5（overlay2、cgroup v2） | 已安裝，服務運行中 |
| openssh-server | — | 已安裝，服務運行中（port 22） |
| sqlite3、php、node、npm | — | 未安裝（改用 Docker 提供） |

## Docker

- 映像檔：1 個（`hello-world`，測試用，打包前應清除）
- 容器：0 個

## 套件統計

- 已安裝套件：356 個（`dpkg` 狀態為 installed）
- 手動選取套件：203 個，清單見 `manifests/arm64-manual-packages.txt`

## 登入體驗（vm-assets/）

- `vm-assets/motd`：`/etc/motd`，SSH 登入時由系統印出，彩色靜態文字。
- `vm-assets/banner.txt`：動畫橫幅的文字，安裝到 `~/.config/ai-coding/banner.txt`。
- `vm-assets/zshrc`：安裝到 `~/.zshrc`，設定 `TERM=xterm-256color`，並在互動式登入時播放一次橫幅動畫。

## 尚未包含

- OpenRouter API key：`~/.config/ai-coding/env` 尚未建立。依設計不放進映像檔，由 `setup-course.sh` 在學生端輸入。
- 打包前待處理：移除 `hello-world` 映像、確認 `student` 密碼的處理方式、決定是否保留 SSH server 與免密碼 sudo。
