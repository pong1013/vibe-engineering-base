# 客製化

[English](./customization.md) | [繁體中文](./customization.zh-TW.md) | [回到 README](../README.zh-TW.md)

這是調整專案範本各項設定的參考手冊。若要按照順序完成設定，或需要可直接使用的 project checks 範例，請先閱讀[入門教學](./getting-started.zh-TW.md)。

完成設定後，指引與 checks 應描述實際專案，而不是 `vibe-engineering-base`。Codex 每次都會讀取的內容應保持精簡。其他細節放到適用範圍最小的位置。

## Project Contract

`.agents/project-contract.md` 是 repository-aware 工作流程的穩定入口。依序保留五個區塊：Verification、Knowledge、Work artifacts、Workspace 與 Delivery。

- 指向權威命令與檔案，不要複製完整內容。
- 真正的 project checks 尚未存在時，Verification 維持 `Status: bootstrap` 與 `Complete verification: unconfigured`；設定完成後再改為 `Status: complete` 並指定完整命令。
- 專案選定 ticket backend 與 delivery mode 後再設定。
- 沒有政策時保持未設定，不要從偶然的歷史紀錄猜出規則。
- 若 Contract 與 `AGENTS.md` 或可執行工具衝突，以後兩者為準；解決衝突後再更新 Contract。
- 修改 Contract 後執行 `make verify`。

## `AGENTS.md`

只保留幾乎每次修改都需要遵守的規則：

- 標準的 setup、test 與 build 入口。
- 高層架構邊界與不變條件。
- 相容性與安全限制。
- 驗證與文件要求。

替換 `Project-specific guidance` placeholder。不要把完整架構、特定任務流程，或工具已能強制執行的規則複製進這個檔案。

## 可重複執行的 project checks

編輯 `scripts/harness/project-checks.sh`，讓 `make verify` 執行實際專案的 checks。每一類檢查盡量只使用一個標準命令，並保留非零 exit status。機器能檢查的 formatting、lint、type、test 與 build 規則應交給對應工具執行。

設定 `PROJECT_CHECKS_CONFIGURED=1` 後，將 Project Contract 改為 `Status: complete`，並把 Complete verification 設成 `make verify`。若 Contract 宣稱 complete，但預設 project-checks script 仍明確標成未設定，validator 會拒絕。

## Repository Skills

如果所有專案協作者都可能使用某個工作流程，就保留對應的 Skill。如果內建 Skill 不符合專案工作方式，就移除它。只有當流程有明確的觸發時機，而且包含無法直接從程式碼取得的重用指引時，才新增 Skill。

每個啟用中的 Skill 都應：

- 讓資料夾名稱與 `SKILL.md` 的 `name` 相同。
- 撰寫範圍精準、能區分適用時機的 `description`。
- 加入 `agents/openai.yaml` UI metadata，以及包含 `$skill-name` 的 default prompt。
- 有意識地設定 `policy.allow_implicit_invocation`；只能明確呼叫的流程使用 `false`。
- 將需要時才讀取的細節放入 references，將可重複執行的行為放入 scripts。

將 `examples/project-skill/` 當成起點，不要直接視為啟用中的 Skill。

## 專案文件

將根目錄 README 換成產品自己的首頁與設定說明，並依專案需求保留或修改 `docs/` 下的文件。

依用途安排知識：

| 知識 | 位置 |
| --- | --- |
| 幾乎每次修改都需要遵守的規則 | `AGENTS.md` |
| 工作流程使用的命令、位置與政策 | `.agents/project-contract.md` |
| 可重複使用的特定任務流程 | `.agents/skills/` |
| 機器可檢查的行為 | 測試、linters 與 verification scripts |
| 標準 domain 詞彙 | 專案使用時放在 `CONTEXT.md` |
| 長期有效、難以直接理解的架構決策 | `docs/adr/` |
| 架構說明與 runbooks | 專案文件 |
| 外部系統存取 | MCP server 或 connector |

## CI 與平台支援

內建 workflow 會在 Ubuntu 與 macOS 驗證 repository。只有專案支援的平台改變時才調整 matrix，並讓本機與 CI 維持相同入口。

Base `0.1.0` 不正式支援原生 Windows 與 WSL。

## Base 更新

`0.1.0` 沒有把專案範本安裝、自動合併或升級到既有 repository 的機制。完成設定後，衍生專案擁有自己的 `AGENTS.md`、Project Contract、Skills、scripts、測試與 workflows。後續範本變更應手動 review，不應覆蓋專案專屬檔案。

未來安全處理衝突的 installer 需求記錄在 [`TODO.md`](../TODO.md)。
