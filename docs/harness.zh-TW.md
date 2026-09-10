# Harness

[English](./harness.md) | [繁體中文](./harness.zh-TW.md) | [回到 README](../README.zh-TW.md)

這份參考文件說明驗證機制，以及每種狀態代表的意思。Harness 會將專案規則轉換成可重複執行、機器能檢查的命令。

`scripts/harness/` 只是一般的 scripts 目錄。Codex 會使用它，是因為 `AGENTS.md`、Makefile 與 CI 都指向相同入口。

## 驗證流程

```text
make verify
└── scripts/harness/verify.sh
    ├── 檢查 Harness 與測試 scripts 的 Bash 語法
    ├── 執行 Harness 回歸測試
    ├── 驗證啟用中的 repository Skills
    └── 執行 project-checks.sh
```

Skill checks 使用輕量的 shell 驗證。它會檢查目錄與 Skill 名稱、必要的 frontmatter 欄位、未完成的 placeholder、`agents/openai.yaml` 必要介面欄位、default prompt，以及選用 invocation policy 的格式。它不會完整解析或驗證任意 YAML。

## 驗證狀態

尚未客製化的專案範本會成功結束，並顯示：

```text
Harness checks: passed
Repository Skills: passed
Project checks: not configured
Overall: bootstrap ready; project verification is incomplete
```

這代表可重用的基礎功能正常，不代表產品測試、lint 或 build 已執行。

設定 `PROJECT_CHECKS_CONFIGURED=1` 且所有命令都成功後，最後兩行會變成：

```text
Project checks: passed
Overall: verification passed
```

如果 Harness、Skill 或 project check 失敗，`verify.sh` 會停止，並保留原始的非零 exit status。它不會顯示容易誤解的成功摘要。

## 命令

```bash
make verify         # Harness 語法、測試、repository Skills 與 project checks
make test           # 只執行 Harness 回歸測試
make harness-audit  # 以唯讀 Codex audit 尋找可長期保留的 Harness 改善
```

修改程式碼、專案指引、Skills、checks 或 Harness 行為後，請執行 `make verify`。

## 設定 project checks

專案範本無法預先知道衍生專案的語言或 toolchain。因此 `scripts/harness/project-checks.sh` 一開始使用 `PROJECT_CHECKS_CONFIGURED=0`，而且不包含產品命令。加入專案標準的 test、lint、build 或其他驗證命令後，才能改成 `1`。

保留 `set -euo pipefail`，也不要攔截失敗。這樣原始的非零 status 才能傳到 `make verify` 與 CI。可直接使用的 Node.js 與 Python 範例放在[入門教學](./getting-started.zh-TW.md#4-接上-project-checks)。

## CI

`.github/workflows/verify.yml` 會在 push 與 pull request 時，分別於 Ubuntu 和 macOS 執行 `make verify`。本機與 CI 因此使用相同入口。Workflow 只使用 repository read permission，也不執行非決定性的 Harness audit。

Project checks 尚未設定時，CI 仍可能是綠燈。這時只代表範本的 Harness 與 Skills 通過。請查看 job output，並在把它視為產品驗證前完成專案設定。

## Harness audit

`make harness-audit` 需要 Codex CLI。它會執行暫時且唯讀的 repository review，最多回傳三項有證據、值得長期加入 `AGENTS.md`、Skills、測試或驗證流程的改善建議。它不會修改檔案。沒有足夠證據時，也不應提出修改。

## 測試與診斷設定

以下環境變數供回歸測試與受控診斷使用：

| 變數 | 用途 |
| --- | --- |
| `HARNESS_SKILLS_DIR` | 改為驗證另一個啟用中的 Skills 目錄。 |
| `HARNESS_SKIP_TESTS=1` | 在 `verify.sh` 內略過 Harness 回歸測試。 |
| `HARNESS_PROJECT_CHECKS` | 改為執行另一個 project checks script。指定的 script 會視為已設定。 |
| `HARNESS_CODEX_BIN` | 指定 audit 使用的 Codex executable。 |

這些是整合用的介面，不會取代正常的 `make verify` 入口。
