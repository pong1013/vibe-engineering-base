# 入門教學

[English](./getting-started.md) | [繁體中文](./getting-started.zh-TW.md) | [回到 README](../README.zh-TW.md)

若要將這套系統加入既有專案，使用 user scope 的 `$vibe-engineering` Skill。若要建立新的 Git repository，使用 GitHub Template。[README](../README.zh-TW.md#選擇使用方式)提供兩種路徑可直接複製的指令。

## 環境需求

- Codex Desktop、CLI 或 IDE extension。
- Bash 3.2 以上的 macOS，或使用 Bash 的 Linux。
- 只有 Template 路徑或既有 Git repository 需要 Git。

Harness 不限制應用程式語言、package manager、framework、ticket tracker 或 domain 文件結構。

## 既有專案

以 `$skill-installer` 安裝 `skills/vibe-engineering`，接著在目標資料夾呼叫 `$vibe-engineering`。Setup 在寫入前一定會產生預覽；它會保留 `AGENTS.md` managed block 以外的內容，並把管理中的檔案與 checksum 記錄於 `.agents/vibe-engineering/manifest.json`。

Git repository 會取得理解 Git 的指引。一般資料夾同樣會取得長期指引、Contract 與 project learning Skill，但不會假設 Git、CI、branch、commit 或 pull request。Setup、status、upgrade 與 learn 行為請參考 [Skills 指南](./skills.zh-TW.md#user-scope-vibe-engineering)。

## 從 Template 建立新專案

### 1. 建立自己的 repository

開啟 [template repository](https://github.com/pong1013/vibe-engineering-base)，選擇 **Use this template**，在自己的帳號或 organization 建立 repository。Clone 後，在 Codex 開啟 repository root。

如果沒有 template 按鈕，可以一般 clone，然後解除與 source 的連結：

```bash
git clone https://github.com/pong1013/vibe-engineering-base.git my-project
cd my-project
git remote remove origin
```

交付前先建立目的 repository，再將它加入為 `origin`。不要把衍生專案 push 到 source remote。

### 2. 將設定 prompt 交給 Codex

貼上[從 Template 建立新專案](../README.zh-TW.md#從-template-建立新專案)中的完整 prompt。它會要求 Codex 先檢查 repository，只詢問會影響結果的重要缺漏，並在同一個設定任務中完成：

- 專案身分與產品 README；
- 可長期保存的 `AGENTS.md` 指引；
- specification、tracker、domain 與 ADR 入口；
- 包含真實 workspace 與 delivery 政策的 bootstrap Project Contract；
- 真正的產品 test、lint、typecheck 與 build 命令；
- 透過 `harness-feedback` 進行 repository learning。

複製的 source 檔案含有維護 `vibe-engineering-base` 使用的引用，包括 source tracker 身分。設定時必須用新專案資訊取代，或標記為 unconfigured；不得將工作發佈到 `pong1013/vibe-engineering-base`。

Global Workflow 是另一項 user scope 能力。這個 Template 不會安裝或修改它，設定專案也不以它為必要條件。

### 3. 讓 Contract 如實反映狀態

設定期間使用以下 verification 值：

```text
- Status: bootstrap
- Bootstrap verification: `make verify`
- Complete verification: unconfigured
```

當 `scripts/harness/project-checks.sh` 還沒有具實質意義的產品命令時，維持 `PROJECT_CHECKS_CONFIGURED=0`。未知的 tracker、domain、branch 與 delivery 值應維持 unconfigured，不要猜測。

接上真正的 checks 後，設定 `PROJECT_CHECKS_CONFIGURED=1`，將 Contract 改成 `Status: complete`，並把 Complete verification 設為 `make verify`。Contract 是精簡索引；架構說明應放在專案文件中。

[Harness 參考](./harness.zh-TW.md#設定-project-checks)說明如何接上產品 checks，並保留命令的失敗狀態。

### 4. 最後才驗證

Repository 已描述真正的專案，而且產品 checks 已接上後，再執行：

```bash
make verify
```

完整設定的專案最後會顯示 `Project checks: passed`、`Overall: verification passed` 與 `HARNESS_VERIFICATION_STATUS=complete`。

若尚未有具實質意義的產品 checks，Contract 應維持 bootstrap。驗證可以確認 Harness 本身，但最後回報必須列出缺少的 checks，且不得宣稱產品驗證 complete。

## 完成清單

- [ ] 已用產品 README 取代 template 首頁。
- [ ] `AGENTS.md` 描述真正的架構邊界、不變條件與標準命令。
- [ ] Source repository 與 tracker 身分已移除或取代。
- [ ] `.agents/project-contract.md` 指向實際的命令、位置與政策。
- [ ] 只有產品 checks 執行真正命令時，才設定 `PROJECT_CHECKS_CONFIGURED=1`。
- [ ] 已檢查 repository Skills；除非刻意移除，否則 `harness-feedback` 仍保持啟用。
- [ ] 最後的 `make verify` 顯示完整驗證通過，或明確列出剩餘 bootstrap 缺口。
- [ ] 若專案使用 Git CI，CI 會執行同一個 `make verify` 入口。
