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
    ├── 驗證 Project Contract
    └── 執行 project-checks.sh
```

Skill checks 使用輕量的 shell 驗證。它會檢查目錄與 Skill 名稱、必要的 frontmatter 欄位、未完成的 placeholder、`agents/openai.yaml` 必要介面欄位、default prompt，以及選用 invocation policy 的格式。它不會完整解析或驗證任意 YAML。

Project Contract checks 會要求 `.agents/project-contract.md`、依序排列的五個標準區塊，而且每個已知欄位必須位於所屬區塊。預設的 `repository` profile 會驗證 repository instructions、ticket backend、必要的 default 與 feature branch policy、workspace preservation，以及 remote/target delivery 欄位。明確指定的 `folder` profile 會驗證 project instructions、task tracking、workspace preservation 與 destination，不會要求只適用於 repository 的欄位。兩種 profile 都會驗證具型別的驗證狀態、安全的相對路徑、固定為 `yes` 的 preservation 與 Delivery Gate 不變條件，以及合法的 delivery mode。Work artifacts 的位置可設為專案路徑、`unconfigured`，或以 `configured by` 指向已存在的相對設定檔。Bootstrap Contract 可以如實將 bootstrap verification、complete verification 與 project checks 保持為 `unconfigured`。欄位放錯位置、未知欄位、缺失或不安全的引用、無意義命令，或 default project checks 明確未設定但 Contract 宣稱完整驗證，都會被拒絕。

驗證一般專案資料夾時，請明確選擇 folder schema：

```bash
HARNESS_CONTRACT_PROFILE=folder \
  HARNESS_PROJECT_CONTRACT=/absolute/project/.agents/project-contract.md \
  HARNESS_CONTRACT_ROOT=/absolute/project \
  bash scripts/harness/validate-project-contract.sh
```

## 驗證狀態

Source repository 已設定用來驗證自身 Skills 與 Contract 的 checks，因此摘要結尾如下：

```text
Harness checks: passed
Repository Skills: passed
Project Contract: passed
Contract verification status: complete
Project checks: passed
Overall: verification passed
HARNESS_VERIFICATION_STATUS=complete
```

衍生專案在產品 checks 設定完成前應維持 bootstrap。成功的 bootstrap 摘要結尾如下：

```text
Harness checks: passed
Repository Skills: passed
Project Contract: passed
Contract verification status: bootstrap
Project checks: not configured
Overall: bootstrap ready; project verification is incomplete
HARNESS_VERIFICATION_STATUS=bootstrap
```

這個 bootstrap 結果代表可重用的基礎功能正常，不代表衍生專案的產品測試、lint 或 build 已執行。

設定 `PROJECT_CHECKS_CONFIGURED=1`、Contract status 為 complete 且所有命令都成功後，摘要結尾會變成：

```text
Contract verification status: complete
Project checks: passed
Overall: verification passed
HARNESS_VERIFICATION_STATUS=complete
```

只有 Contract status 與 project-check state 都是 complete，最終 machine status 才會是 complete。即使 checks override 成功，只要 Contract 仍是 bootstrap，就會輸出 `HARNESS_VERIFICATION_STATUS=bootstrap`。若 Harness、Skill 或 project check 失敗，`verify.sh` 會停止並保留原始的非零 exit status。

## 命令

```bash
make verify         # Harness 語法、測試、Skills、Project Contract 與 project checks
make test           # 只執行 Harness 回歸測試
make harness-audit  # 以唯讀 Codex audit 尋找可長期保留的 Harness 改善
```

修改程式碼、專案指引、Skills、checks 或 Harness 行為後，請執行 `make verify`。

## 設定 project checks

Source repository 使用 `PROJECT_CHECKS_CONFIGURED=1` 驗證自己的 repository Skills 與 Project Contract。因為 base 無法預先知道衍生專案的語言或 toolchain，專案 onboarding 必須先把這個值重設為 `0`，並以衍生專案標準的 test、lint、build 或其他驗證命令取代 source checks。這些命令設定完成後，才能改回 `1`。

保留 `set -euo pipefail`，也不要攔截失敗。這樣原始的非零 status 才能傳到 `make verify` 與 CI。選擇並接上 checks 的過程應讓 Contract 如實反映狀態；請參考[讓 Contract 如實反映狀態](./getting-started.zh-TW.md#3-讓-contract-如實反映狀態)。

## CI

`.github/workflows/verify.yml` 會在 push 與 pull request 時，分別於 Ubuntu 和 macOS 執行 `make verify`。本機與 CI 因此使用相同入口。Workflow 只使用 repository read permission，也不執行非決定性的 Harness audit。

衍生專案的 project checks 尚未設定時，CI 仍可能是綠燈。這個 bootstrap 狀態只代表範本的 Harness 與 Skills 通過。請查看 job output，並在把它視為產品驗證前完成專案設定。Source repository 本身已完成設定，會輸出上方的 complete status。

## Harness audit

`make harness-audit` 需要 Codex CLI。它會執行暫時且唯讀的 repository review，最多回傳三項有證據、值得長期加入 `AGENTS.md`、Skills、測試或驗證流程的改善建議。它不會修改檔案。沒有足夠證據時，也不應提出修改。

## 測試與診斷設定

以下環境變數供回歸測試與受控診斷使用：

| 變數 | 用途 |
| --- | --- |
| `HARNESS_SKILLS_DIR` | 改為驗證另一個啟用中的 Skills 目錄。 |
| `HARNESS_PROJECT_CONTRACT` | 改為驗證另一個 Project Contract 檔案。 |
| `HARNESS_CONTRACT_ROOT` | 讓診斷用 Contract 以另一個 repository root 解析。 |
| `HARNESS_CONTRACT_PROFILE` | 選擇嚴格的 `repository` profile（預設）或嚴格的 `folder` profile。 |
| `HARNESS_SKIP_TESTS=1` | 在 `verify.sh` 內略過 Harness 回歸測試。 |
| `HARNESS_PROJECT_CHECKS` | 改為執行另一個 project checks script。指定的 script 會視為已設定。 |
| `HARNESS_CODEX_BIN` | 指定 audit 使用的 Codex executable。 |

這些是整合用的介面，不會取代正常的 `make verify` 入口。
