# Skills

[English](./skills.md) | [繁體中文](./skills.zh-TW.md) | [回到 README](../README.zh-TW.md)

這個專案使用兩種 Codex Skill：

- 安裝一次、用來設定或維護指定專案資料夾的 user scope `$vibe-engineering` Skill；
- 位於 `.agents/skills/`、會隨專案移動並保存可重複流程的 repository Skills。

Skills 會補充每次都載入的 `AGENTS.md`，但不取代可長期保存的 repository 指引。

## User scope `$vibe-engineering`

使用預先安裝的 `$skill-installer` 安裝 `skills/vibe-engineering` 中的 source：

```text
$skill-installer 請安裝 https://github.com/pong1013/vibe-engineering-base/tree/main/skills/vibe-engineering 的 Skill
```

安裝後會從下一個 turn 開始生效。它可接受目前或明確指定的絕對專案路徑，並支援四種 intent：

| Intent | 行為 |
| --- | --- |
| setup | 先預覽，再把選定的 Harness 能力安裝到 Git repository 或一般資料夾。 |
| status | 不寫入檔案，將 managed paths 回報為 current、modified 或 missing。 |
| upgrade | 預覽版本差異；使用者檢查並決定 replacement 前，修改過的 managed file 會保持 conflict。 |
| learn | 將具體證據轉成指引、check proposal，或在達到重用門檻後建立 project Skill。 |

Setup 與 upgrade 使用 plan token，把核准內容綁定到目標與目前檔案狀態。寫入是 atomic。`.agents/vibe-engineering/manifest.json` 會記錄 source version、選定能力、managed paths 與 checksums，不會儲存 secrets。

這個 Skill 只管理 `AGENTS.md` 中有界線的 block。既有專案內容與專案建立的 Skills 仍由專案擁有。一般資料夾不會取得 Git、CI、branch、commit 或 pull request 的假設。

## Repository Skill discovery

Codex 會從目前工作目錄一路到 repository root，掃描沿途的 `.agents/skills/`。Skill 資訊採漸進式載入：

1. Codex 先取得 Skill 名稱、description 與路徑。
2. 只有 Codex 選用或使用者明確指定後，才載入完整 `SKILL.md`。
3. 工作流程確實需要時，才讀取 references 或執行 scripts。

允許隱含呼叫的 Skill，只是在需求符合 description 時可能被選用，不代表每次修改都會執行。明確呼叫使用 `$skill-name`。呼叫政策定義於 `agents/openai.yaml`。可參考官方 [Codex Skills 文件](https://learn.chatgpt.com/docs/build-skills)。

## 內建 repository Skill

| Skill | 呼叫方式 | 責任 |
| --- | --- | --- |
| `harness-feedback` | 可隱含選用，或使用 `$harness-feedback` | 根據已完成工作、review 與重複錯誤的證據，提出範圍明確、可長期保存的 repository 防護改善。 |

當具體證據顯示某項經驗值得重用時使用 `harness-feedback`。它會把機器能辨認的失敗轉成測試或驗證，把整個專案都適用的指引放入 `AGENTS.md`，並把特定任務中重複出現的判斷整理成 Skill。如果經驗只適用一次或現有防護已涵蓋，就不應修改。

依照核准的需求，它可能更新 `AGENTS.md`、既有 Skill、測試或 Harness 驗證。一般修改不必強制把它當成結尾步驟。

`examples/project-skill/` 不在 `.agents/skills/`，所以不會啟用。只有當專案出現具備明確觸發條件的重複流程時，才複製並調整它。

## 新增或移除 repository Skill

- 將啟用中的 repository Skill 放在 `.agents/skills/<skill-name>/SKILL.md`。
- 加入相符的 `agents/openai.yaml` metadata，並有意識地選擇 invocation policy。
- Description 的範圍應足夠精準，避免無關任務被隱含選用。
- 執行 `make verify`，讓 Harness 檢查 Skill 名稱、必要 metadata、invocation policy 與未完成的 placeholder。
- 若某個工作流程不應再跟隨專案，移除該 Skill directory。

可先將 `examples/project-skill/` 複製到 `.agents/skills/<skill-name>/`，再將所有通用名稱與指令換成專案的實際工作流程。
