# vibe-engineering-base

[English](./README.md) | [繁體中文](./README.zh-TW.md)

一個不綁定程式語言的專案範本，讓你能用 Codex 進行更可靠的 AI 輔助開發與 vibe coding。

## 快速開始

1. 開啟 [vibe-engineering-base repository](https://github.com/pong1013/vibe-engineering-base)，選擇 **Use this template**。
2. Clone 新 repository，並在 Codex 開啟它。
3. 執行共用的驗證入口：

   ```bash
   make verify
   ```

4. 告訴 Codex：`請讀取 AGENTS.md，協助我設定這個專案的規則與 project checks。`

第一次執行應成功，並顯示明確的初始狀態：

```text
Harness checks: passed
Repository Skills: passed
Project checks: not configured
Overall: bootstrap ready; project verification is incomplete
```

這代表專案範本本身可正常運作，不代表產品的測試、lint 或 build 已執行。請按照[入門教學](./docs/getting-started.zh-TW.md)接上這些命令。

## Harness 如何運作

```text
make verify
├── 檢查 Harness shell scripts
├── 執行 Harness 回歸測試
├── 驗證 repository Skills
└── 執行專案自己的 checks
```

GitHub Actions workflow 已預先設定，讓 CI 與本機開發都使用相同的 `make verify` 入口。

## `0.1.0` 內建內容

- `AGENTS.md`：保存幾乎每次修改都需要遵守的專案規則。
- Harness：提供可重複執行的自動檢查、回歸測試，以及 macOS／Linux CI。
- `harness-feedback`：可由 Codex 依任務選用，根據實際證據改善長期防護。
- `grill-with-docs`：只能明確呼叫，在實作前協助釐清重要決策。

專案自己的 checks 仍需設定。Installer、自動更新與更完整的開發 Skill 流程尚未實作。

## 文件導覽

- **第一次使用：**[入門教學](./docs/getting-started.zh-TW.md)
- **接上測試、lint 與 build：**[Harness](./docs/harness.zh-TW.md)
- **調整專案規則與結構：**[客製化參考](./docs/customization.zh-TW.md)
- **使用或修改 Skills：**[Skills](./docs/skills.zh-TW.md)

## 支援範圍與授權

支援 Bash 3.2 以上的 macOS，以及使用 Bash 的 Linux。`0.1.0` 不正式支援原生 Windows 與 WSL。

本專案採用 MIT 授權；改寫的 `grill-with-docs` Skill 保留上游 MIT 聲明。
