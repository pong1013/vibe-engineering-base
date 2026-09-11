# 入門教學

[English](./getting-started.md) | [繁體中文](./getting-started.zh-TW.md) | [回到 README](../README.zh-TW.md)

這份教學會把 `vibe-engineering-base` 客製化成 Codex 能獨立理解並驗證的專案。

## 前置需求

- Git。
- Codex Desktop、CLI 或 IDE extension。
- Bash 3.2 以上的 macOS，或使用 Bash 的 Linux。

Base 不限制程式語言、package manager 或 framework。

## 1. 建立 repository

開啟 [template repository](https://github.com/pong1013/vibe-engineering-base)，選擇 **Use this template** 並建立新 repository。Clone 後從 repository root 在 Codex 開啟。

如果沒有 template 按鈕：

```bash
git clone https://github.com/pong1013/vibe-engineering-base.git my-project
cd my-project
git remote remove origin
```

先建立目的 repository，再加入它的 remote。

## 2. 確認 bootstrap

執行：

```bash
make verify
```

第一次會顯示 Harness、repository Skills 與 Project Contract 通過，但產品 checks 尚未設定。這證明範本可運作，不代表產品測試、lint 或 build 已執行。

輸出也會包含 `HARNESS_VERIFICATION_STATUS=bootstrap`。即使 bootstrap 自我檢查的 exit code 是成功，Workflow controller 仍必須將此狀態視為不完整。

## 3. 加入專案資訊與長期規則

用產品真正的介紹與設定方式取代根目錄 README。將 `AGENTS.md` 的 `Project-specific guidance` 換成幾乎每次修改都適用的架構邊界、標準命令、相容性需求與不變條件。

## 4. 設定 Project Contract

編輯 `.agents/project-contract.md`：

- 產品 checks 尚未接上前，保留 `Status: bootstrap`，將 Bootstrap verification 設為 `make verify`，並保留 `Complete verification: unconfigured`。
- 讓 Knowledge 指向真正的專案指引、domain 語言與 ADR 位置。
- 選擇 specification 位置，並在存在 tracker 時設定 ticket backend。
- 只有專案真的有政策時才記錄 workspace 或 branch naming。
- Delivery mode 選擇 `none`、`commit-only`、`push`、`pull-request` 或 `merge-request`。

未知值在決策完成前保持 unconfigured。Contract 是精簡索引，不是第二份架構文件。

## 5. 接上產品 checks

編輯 `scripts/harness/project-checks.sh`，用真正的命令取代停用區塊，並設定 `PROJECT_CHECKS_CONFIGURED=1`。

Node.js 範例：

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

npm run lint
npm test
npm run build
```

Python 範例：

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

python -m ruff check .
python -m pytest
```

使用 repository 原本的標準工具，並保留非零 exit status。詳情請閱讀 [Harness 參考](./harness.zh-TW.md)。

接著把 Project Contract 改成 `Status: complete`，並將 Complete verification 設成 `make verify`。只有這個狀態才能讓 controller 進入 Delivery。

## 6. 檢查 repository Skills

閱讀 [Skills 指南](./skills.zh-TW.md)。如果專案應該從具體開發證據持續學習，就保留 `harness-feedback`；不需要時則移除。只有可重複的專案特定判斷才新增 repository Skill。

重新執行 `make verify`。設定完整的專案應顯示 `Project checks: passed` 與 `Overall: verification passed`。

## 完成清單

- [ ] 已用產品 README 取代範本首頁。
- [ ] `AGENTS.md` 描述真正的專案規則。
- [ ] `.agents/project-contract.md` 指向實際的命令、位置與政策。
- [ ] 已設定 `PROJECT_CHECKS_CONFIGURED=1`，而且產品 checks 會執行真正命令。
- [ ] 已檢查 repository Skills。
- [ ] 本機 `make verify` 顯示完整驗證通過。
- [ ] CI 使用同一個 `make verify` 入口。
