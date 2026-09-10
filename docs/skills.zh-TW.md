# Skills

[English](./skills.md) | [繁體中文](./skills.zh-TW.md) | [回到 README](../README.zh-TW.md)

這份指南說明何時使用 repository Skills、Codex 如何載入它們，以及它們可能影響哪些檔案。Repository Skills 會把可重複使用的特定任務流程保存在專案中。它們補充每次都會載入的 `AGENTS.md`，但不取代它。

## Codex 如何發現 Skills

Codex 會從目前工作目錄一路到 repository root，掃描沿途的 `.agents/skills/`。Skill 資訊採漸進式載入：

1. Codex 可以先取得 Skill 名稱、description 與路徑。
2. 只有 Codex 選用或使用者明確指定後，才載入完整 `SKILL.md`。
3. 工作流程確實需要時，才讀取 references 或執行 scripts。

允許隱含呼叫的 Skill，只是在需求符合 `description` 時可能被選用，不代表每次修改都會執行。明確呼叫是在 prompt 中使用 `$skill-name`。呼叫政策定義於 `agents/openai.yaml`：

```yaml
policy:
  allow_implicit_invocation: false
```

設為 `false` 後，Codex 不會隱含選用該 Skill，但仍能使用 `$skill-name`。可參考官方 [Codex Skills 文件](https://learn.chatgpt.com/docs/build-skills)。

## 內建 Skills

| Skill | 呼叫方式 | 責任 |
| --- | --- | --- |
| `harness-feedback` | 可隱含選用，或使用 `$harness-feedback` | 根據已完成工作、review 與重複錯誤的證據，提出範圍明確、可長期保存的專案防護改善。 |
| `grill-with-docs` | 只能使用 `$grill-with-docs` 明確呼叫 | 在實作前深入確認重大或模糊的計畫，記錄確定的 domain 語言與長期架構決策。 |

`examples/project-skill/` 不在 `.agents/skills/`，所以不會啟用。只有當專案出現具備明確觸發條件的重複流程時，才複製並調整它。

## `harness-feedback`

當具體證據顯示某項經驗值得重用時使用。它會把機器能辨認的失敗轉成測試或驗證，把整個專案都適用的指引放入 `AGENTS.md`，並把特定任務中重複出現的判斷整理成 Skill。如果經驗只適用一次或現有防護已涵蓋，就不應修改。

依照你核准的需求，它可能更新 `AGENTS.md`、既有 Skill、測試或 Harness 驗證。一般修改不必強制把它當成結尾步驟。

## `grill-with-docs`

產品方向、domain 語言、行為、邊界或架構選擇尚未確定時，請在開始實作前使用。

```text
$grill-with-docs <想法、功能、計畫或設計>
        ↓
檢查 repository 與現有專案知識
        ↓
提出一個決策問題與推薦答案
        ↓
等待使用者確認、拒絕或修正
        ↓
記錄符合條件的語言或架構決策
        ↓
持續進行，直到重要決策分支都已確定
```

這個 Skill 不會實作討論中的產品變更，也不會產生完整規格。接著應留在同一個對話，要求整理一份可 review 的實作計畫，讓沒有寫入檔案的決策仍可使用。

### 生成檔案

只有一個 domain context 時，檔案會放在：

```text
CONTEXT.md
docs/adr/NNNN-short-slug.md
```

只有確定專案專屬的標準詞彙時，才會建立或更新 `CONTEXT.md`。只有難以逆轉、缺少理由會令人意外，而且存在真實取捨的決策才會建立 ADR。

若既有的 `CONTEXT-MAP.md` 定義多個 contexts，Skill 會更新 map 指定的 `<context>/CONTEXT.md`，並將該 context 的 ADR 放在對應的 `docs/adr/`。它不會自動建立 `CONTEXT-MAP.md`。

這些是正常的專案文件，應 review 並 commit，不會被 Git 忽略。多數回答不符合 glossary 或 ADR 條件，因此只會留在對話中。

### 對此 base repository 的影響

`vibe-engineering-base` 不會預先生成 glossary 或 ADR。在衍生專案中，生成檔案會正確描述該專案；若在尚未客製化的來源 base 生成，它們會成為未來專案繼承的 template 內容，因此 Skill 會先警告並等待確認。

本 repository 包含 Matt Pocock [`grill-with-docs`](https://github.com/mattpocock/skills/blob/main/docs/engineering/grill-with-docs.md)、`grilling` 與 `domain-modeling` 工作流程的 Codex 自含式改寫。上游 MIT 聲明存放在 Skill 目錄中。

## 新增或移除 Skill

- 將啟用中的 repository Skill 放在 `.agents/skills/<skill-name>/SKILL.md`。
- 加入相符的 `agents/openai.yaml` metadata，並有意識地選擇 invocation policy。
- Description 的範圍應足夠精準，避免無關任務被隱含選用。
- 執行 `make verify`。Harness 會檢查啟用中 Skill 的名稱、必要 metadata 欄位、invocation policy 格式與未完成的 placeholder。
- 若某個工作流程不應跟隨衍生專案，移除該 Skill directory。

可先將 `examples/project-skill/` 複製到 `.agents/skills/<skill-name>/`，再將所有通用名稱與指令換成專案的實際工作流程。
