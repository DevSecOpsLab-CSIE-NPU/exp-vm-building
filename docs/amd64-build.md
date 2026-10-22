# AMD64 VM 建置步驟（Apple Silicon 上用 QEMU/UTM 模擬）

目標：產出 `ai-coding-amd64.vdi`，給 Intel/AMD 的學生用 VirtualBox 開機。

> 建置很慢（x86_64 是軟體模擬）。建議今晚開始安裝，不要留到上課前。
> 所有命令都在你的 Mac 終端機執行，除非另有註明。

---

## 0. 需要準備的東西

| 項目 | 說明 |
|---|---|
| UTM | 從 https://getutm.app 下載，或用 `brew install --cask utm` |
| 或 QEMU | `brew install qemu`（已安裝 `qemu-img` 即可用於轉檔） |
| Debian amd64 netinst ISO | 約 700 MB，見步驟 1 |
| 磁碟空間 | 至少 20 GB 可用（建置中 + 轉檔後的 VDI） |

---

## 1. 下載並驗證 Debian amd64 ISO

```bash
cd ~/Downloads
curl -LO https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS
curl -LO https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso
shasum -a 256 debian-13.0.0-amd64-netinst.iso
grep netinst SHA256SUMS
```

> 檔名版本號請以 `SHA256SUMS` 內實際列出的為準。兩個 hash 必須一致。

---

## 2. 在 UTM 建立 x86_64 VM

UTM → **Create a New Virtual Machine** → **Emulate**

| 欄位 | 設定 |
|---|---|
| Operating System | Linux |
| Architecture | **x86_64**（務必選這個，不是 ARM64） |
| Boot ISO | 步驟 1 下載的 netinst ISO |
| Memory | 2048 MB（能裝到 4096 更好） |
| CPU Cores | 2 |
| Disk | 16 GB（貼上的 8 GB 太小，套件加上 OpenCode 容易不夠） |
| Shared Directory | 不需要 |
| Name | `ai-coding-amd64` |

在 VM 設定中：
- **Display**：不需要 GPU，選 `Console Only` 或預設即可。
- **Network**：保留預設 Shared Network（NAT），學生端的設定也是 NAT。

---

## 3. 安裝 Debian（x86_64）

開機後依序選擇：

| 畫面 | 選擇 |
|---|---|
| Language / Location | English 或 Chinese，依你偏好；時區 Asia/Taipei |
| Hostname | `ai-coding` |
| Root password | **留空**（讓 `student` 透過 sudo 取得管理權限） |
| Full name / username | `Student` / `student` |
| User password | 暫時設 `student`，之後會在映像檔打包前改成安全的值或鎖定 |
| Partitioning | Guided, use entire disk |
| Software selection | **只勾 standard system utilities**，**不要勾 desktop**，**不要勾 SSH server** |
| GRUB | 安裝到 `/dev/sda` |

> 不裝 SSH server 是刻意的：這樣 image 內不會有需要重新產生的 host key。

安裝完成、重開機後以 `student` 登入。

---

## 4. 安裝課程需要的套件（VM 內執行）

```bash
sudo apt update
sudo apt install -y git gh curl sqlite3 php-cli php-sqlite3 nodejs npm
```

確認版本：

```bash
git --version
gh --version
php --version
sqlite3 --version
node --version
npm --version
```

> **待驗證**：Debian 13 內建的 `nodejs` 版本與 OpenCode 的需求是否相容。若 `opencode` 無法啟動，改用 NodeSource 或 nvm 安裝較新的 Node（LTS），並更新 `setup-course.sh` 的說明。

---

## 5. 放入 setup-course.sh（VM 內執行）

把 Mac 上的 `setup-course.sh` 放進 VM。最簡單的方式：

- **方式 A**：在 Mac 上開一個 HTTP server，VM 內用 `curl` 下載（VM 的 NAT 可以連到 Mac 的 IP，或改用 UTM 的 Shared Directory）。
- **方式 B**：直接在 VM 內用 `nano ~/setup-course.sh` 貼上內容。

```bash
chmod +x ~/setup-course.sh
```

先確認語法（不執行）：

```bash
bash -n ~/setup-course.sh && echo OK
```

> 這一步先不要執行完整腳本，要等到 `COURSE_REPO` 設定好，並確認 OpenCode 安裝方式後再測試。

---

## 6. 打包前清理（VM 內執行）

**先關閉 `setup-course.sh` 的測試產物，再清理。**

```bash
# 清除套件快取
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*

# 清除 shell 歷史與本機設定
history -c
rm -f ~/.bash_history
rm -rf ~/.config/ai-coding ~/ai-coding-lab

# 重設 machine-id（每台開機會重新產生）
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id

# 把 student 密碼改成學生第一次登入時再設定，或保持課堂統一值（見 open items）
# 這裡先不動

# 把可用空間寫成 0，讓 qcow2 壓縮後較小（寫滿會報錯，屬正常）
sudo dd if=/dev/zero of=/zero.fill bs=1M status=none || true
sudo rm -f /zero.fill
sync
```

> 確認 `~/.bashrc` 內沒有任何 token、API key 或 `gh` 登入資訊：
> ```bash
> grep -iE 'token|key|secret|password' ~/.bashrc || echo "clean"
> ```

關機：

```bash
sudo poweroff
```

---

## 7. 取出磁碟並轉成 VDI（Mac 上執行）

UTM 的 VM 資料夾通常位於 `~/Library/Containers/com.utmapp.UTM/Data/Documents/ai-coding-amd64.utm/Data/`，裡面的磁碟檔名類似 `xxxx.qcow2`。

```bash
# 找出磁碟檔
find ~/Library/Containers/com.utmapp.UTM/Data/Documents/ai-coding-amd64.utm -name '*.qcow2'
```

把找到的檔案複製到專案資料夾（不要直接在 UTM 資料夾內轉檔）：

```bash
mkdir -p /Users/fychao/VM_IMG/build
cp "<上一步找到的 .qcow2 完整路徑>" /Users/fychao/VM_IMG/build/ai-coding-amd64.qcow2
```

檢查來源檔案：

```bash
qemu-img info /Users/fychao/VM_IMG/build/ai-coding-amd64.qcow2
```

轉成 VDI：

```bash
qemu-img convert -p \
  -f qcow2 \
  -O vdi \
  /Users/fychao/VM_IMG/build/ai-coding-amd64.qcow2 \
  /Users/fychao/VM_IMG/build/ai-coding-amd64.vdi
```

檢查結果：

```bash
qemu-img info /Users/fychao/VM_IMG/build/ai-coding-amd64.vdi
VBoxManage showmediuminfo /Users/fychao/VM_IMG/build/ai-coding-amd64.vdi
shasum -a 256 /Users/fychao/VM_IMG/build/ai-coding-amd64.vdi
```

> `VBoxManage showmediuminfo` 在 ARM 版 VirtualBox 上可能只讀出 metadata，不代表能開機。真正的開機驗證要在 Intel/AMD 機器上做（見步驟 8）。

---

## 8. 驗證

### 8a. Mac 上以 QEMU 驗證 Linux 本身（可選）

```bash
qemu-system-x86_64 \
  -m 2048 -smp 2 \
  -drive file=/Users/fychao/VM_IMG/build/ai-coding-amd64.qcow2,format=qcow2 \
  -nographic
```

登入後確認 `setup-course.sh` 可以執行（見 `setup-course.sh` 草稿的測試說明）。

### 8b. Intel/AMD Windows 或 Linux 機器（必要）

1. 安裝 VirtualBox（建議版本與學生一致，註明在說明文件中）。
2. New VM → Type: Linux → Version: Debian (64-bit) → 使用現有 VDI `ai-coding-amd64.vdi`。
3. 開機，確認：
   - 能登入 `student`。
   - 網路可用（`ping -c 3 github.com` 或 `curl -I https://openrouter.ai`）。
   - 執行 `~/setup-course.sh`，能完成安裝與 clone。

---

## 9. 交付物清單

- `ai-coding-amd64.vdi`
- `ai-coding-amd64.vdi.sha256`（由步驟 7 產生）
- 學生說明（VirtualBox 版本、匯入方式、執行 `setup-course.sh` 的步驟）

## 注意事項

- 不要把 `OPENROUTER_API_KEY`、GitHub 登入狀態放進映像檔。
- 不要在 UTM 裡直接改磁碟後再轉檔：先關機、再取出磁碟。
- 若模擬速度太慢，可改在 Intel 機器或雲端 x86 Linux 主機上依照同樣步驟建置，之後的轉檔與驗證流程不變。
