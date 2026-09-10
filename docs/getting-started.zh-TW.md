# 入門教學

[English](./getting-started.md) | [繁體中文](./getting-started.zh-TW.md) | [回到 README](../README.zh-TW.md)

這份逐步教學會帶你把 `vibe-engineering-base` 改成專案專屬的 repository，並開始使用推薦的開發流程。

## 前置需求

- Git。
- Codex Desktop、CLI 或 IDE extension。
- Bash 3.2 以上的 macOS，或使用 Bash 的 Linux。

這個專案範本不限制程式語言、package manager 或 framework。

## 1. 建立 repository

推薦做法是開啟 [template repository](https://github.com/pong1013/vibe-engineering-base)，選擇 **Use this template**，再建立新的 repository。Clone 或在本機開啟新 repository，並從根目錄啟動 Codex，讓 Codex 能發現 `AGENTS.md` 與 `.agents/skills/`。

如果沒有看到 template 按鈕，可以使用以下替代流程：

```bash
git clone https://github.com/pong1013/vibe-engineering-base.git my-project
cd my-project
git remote remove origin
```

先建立新專案的目的 repository，再加入它的 remote。

## 2. 確認初始狀態

執行：

```bash
make verify
```

第一次執行會顯示 Harness 與 repository Skills 已通過，但 project checks 尚未設定。這是一個刻意保留的成功狀態。它證明專案範本能正常運作，不代表產品測試、lint 或 build 已執行。

## 3. 加入專案資訊與規則

將根目錄的 README 換成產品真正的介紹與設定方式。接著替換 `AGENTS.md` 的 `Project-specific guidance`，寫入幾乎每次修改都需要遵守的架構邊界、標準命令、相容性需求與不變條件。

每項設定的完整說明與適合的位置，請查閱[客製化參考](./customization.zh-TW.md)。

## 4. 接上 project checks

初始的 `scripts/harness/project-checks.sh` 使用以下停用狀態：

```bash
PROJECT_CHECKS_CONFIGURED=0

if [[ "${PROJECT_CHECKS_CONFIGURED}" != "1" ]]; then
  echo "WARNING: project checks are not configured. Edit scripts/harness/project-checks.sh." >&2
  exit 0
fi
```

將 placeholder 換成專案真正使用的命令，並把設定值改成 `1`。Node.js 專案可以使用這個精簡版本：

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

npm run lint
npm test
npm run build
```

Python 專案可以使用：

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

python -m ruff check .
python -m pytest
```

請使用專案原本的標準命令，不要直接複製專案沒有採用的工具。保留 `set -euo pipefail`。第一個失敗的命令會保留非零結果，讓 `make verify` 與 CI 明確失敗。

[Harness 參考](./harness.zh-TW.md)說明每種驗證狀態、CI 行為與診斷設定。

## 5. 檢查 Skills 並完成設定

閱讀 [Skills 指南](./skills.zh-TW.md)，再依專案需求保留、修改或移除內建 Skills。重新執行 `make verify`，確認摘要顯示 `Project checks: passed` 與 `Overall: verification passed`。

Commit 客製化後的基礎設定前，完成以下清單：

- [ ] 已用產品 README 取代範本首頁。
- [ ] `AGENTS.md` 已描述實際的專案規則與標準命令。
- [ ] 已設定 `PROJECT_CHECKS_CONFIGURED=1`，而且 project checks 會執行真正的命令。
- [ ] 已確認內建 Skills 是否符合專案工作流程。
- [ ] 本機執行 `make verify` 會顯示完整驗證通過。
- [ ] CI 使用相同的 `make verify` 入口。

## 推薦開發流程

依照變更的不確定性與風險，選擇足夠且最輕量的流程。

```text
需求是否明確且風險低？
├── 是 → 請 Codex 實作並驗證結果。
└── 否，或變更影響重大
    └── 呼叫 $grill-with-docs
        ├── Codex 先檢查 repository 中可查明的事實
        ├── Codex 每次提出一個決策問題與建議答案
        ├── 你確認或修正決策
        ├── 記錄需要長期保存的術語與 ADR
        └── 持續進行，直到重要分支都已確定
```

新產品方向、大型功能、domain 語言不清或重要架構選擇適合使用 `$grill-with-docs`。小型 bug 或結果已經明確的例行修改通常不需要使用。

討論完成後留在同一個對話，讓尚未寫入檔案的決策仍可使用。接著要求 Codex：

```text
根據剛才確定的決策，整理一份可 review 的實作計畫，先不要實作。
```

確認計畫後，再要求開始實作。`0.1.0` 尚未內建 `to-spec`、`to-tickets` 或完整的開發 Skill 流程。

## 常見問題

### 為什麼第一次執行 `make verify` 會警告，卻仍成功結束？

這個警告代表專案仍在初始設定階段。範本可以先驗證自己的 Harness 與 Skills，但還不知道衍生專案使用什麼語言與命令。

### 為什麼沒有執行產品測試，CI 仍是綠燈？

CI 已設定執行 `make verify`，但初始的 project checks 沒有產品命令。完成 `project-checks.sh` 前，綠燈只代表範本本身正常；完成設定後，才包含你加入的產品檢查。

### 第一個功能需要使用 `$grill-with-docs` 嗎？

如果重要行為、術語或取捨還沒確定，就適合使用。例如：

```text
$grill-with-docs 我想新增團隊邀請功能。請先檢查 repository，再協助我確定使用者流程、術語、授權邊界與重要失敗情境，暫時不要實作。
```
