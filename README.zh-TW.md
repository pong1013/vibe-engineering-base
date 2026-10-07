# vibe-engineering-base

[English](./README.md) | [繁體中文](./README.zh-TW.md)

一個不綁定程式語言的基礎，讓 Codex 擁有可長期保存的專案脈絡、可重複執行的驗證，以及從已完成工作中學習的能力。

## 選擇使用方式

### 加入既有專案

如果你已經有專案，想讓 Codex 記住專案規則、執行可重複的檢查，並把有用的經驗整理成專案指引，請選這條路。Git repository 或一般資料夾都可以使用；不用把現有專案搬進這個 template。

**跟原本有什麼差別？** 設定前，Codex 每次都得從當前對話和檔案重新摸索專案規則與檢查方式。設定後，專案會有長期保存的 `AGENTS.md` 指引、指向真實命令與知識位置的 Project Contract，以及從已完成工作學習的 `harness-feedback` Skill。User scope 的 `$vibe-engineering` Skill 之後也能查看安裝狀態、預覽升級，並根據證據提議可重複使用的 project Skill。只安裝 Skill 不會修改專案；執行 setup 時會先列出預計變更，再由你決定是否套用。

1. **安裝協助設定的 Skill。** 在 Codex 使用預先安裝的 `$skill-installer`，讓你的帳號可以呼叫 `$vibe-engineering`：

   ```text
   $skill-installer 請安裝 https://github.com/pong1013/vibe-engineering-base/tree/main/skills/vibe-engineering 的 Skill
   ```

2. **開啟想改善的專案。** 在 Codex 開啟可寫入的專案資料夾。Skill 會從下一個 turn 開始生效；開啟目標資料夾後，它才知道要替哪個專案提出設定。

3. **先請它預覽設定。** 預覽會列出檔案與修改內容，讓你看過後再決定是否套用：

   ```text
   $vibe-engineering 請為這個專案設定 Harness；套用前先預覽每一項變更。
   ```

Setup 不會取代 `AGENTS.md` managed block 以外的內容。若目標是一般資料夾，則不會加入 Git、CI、branch、commit 或 pull request 的假設。Setup、status、upgrade 與以證據為基礎的 learn 流程請參考 [Skills 指南](./docs/skills.zh-TW.md)。

### 從 Template 建立新專案

如果你正要建立**全新的 Git repository**，希望一開始就有專案指引、驗證機制與 CI，請選這條路。這適合已準備好說明要做什麼，並打算接上真正測試或其他產品檢查的人。如果產品目前還沒有檢查命令，設定流程會記錄這個缺口，並讓驗證維持 bootstrap 狀態。

1. **建立自己的 repository。** 開啟 [template repository](https://github.com/pong1013/vibe-engineering-base)，選擇 **Use this template**，在自己的帳號或組織下建立 repository。這會複製一份起始檔案給你的專案。
2. **在 Codex 開啟這份複本。** Clone 新 repository，並從 repository root 開啟，讓 Codex 能檢查需要客製化的檔案。
3. **貼上下面的設定 prompt。** 它會把起始檔案改成符合你專案的指引與檢查，遇到無法推斷的重要資訊才詢問你，並在客製化完成後執行 `make verify`。

<!-- template-setup-prompt:start -->
```text
請把目前 repository 中的 vibe-engineering template 設定成真正的專案。

請先檢查 repository，包括 source、package 或 build 設定、README、AGENTS.md、.agents/project-contract.md、scripts/harness/project-checks.sh 與既有文件。只有無法從 repository 判斷、而且會影響結果的重要資訊才詢問我；詢問時請提出具體的建議預設值。

接著完成以下工作：
1. 建立專案身分：產品名稱、目的、目標使用者、支援平台、技術堆疊與標準開發命令。以正確的專案設定與使用方式取代 template README 內容。
2. 將 AGENTS.md 中 template 專屬的長期指引改成此專案的架構邊界、不變條件、相容性限制與標準命令。保留仍適用的一般安全與驗證規則。
3. 選擇並記錄 specification、tracker 指引、domain 語言與架構決策的真實位置。移除繼承自 pong1013/vibe-engineering-base 的引用。若專案沒有 ticket tracker 或 domain 文件，誠實記為 unconfigured，不要虛構整合。
4. 設定期間先把 .agents/project-contract.md 改成 Status: bootstrap。讓它指向實際的 repository 指引與知識位置，記錄真正的 workspace 與 delivery 政策；產品 checks 完成前，complete verification 保持 unconfigured。
5. 找出專案真正且可重複執行的 test、lint、typecheck 與 build 命令。安全更新 scripts/harness/project-checks.sh，執行適用的命令並保留失敗 exit code。只有這些命令確實檢查產品時才設定 PROJECT_CHECKS_CONFIGURED=1。若目前沒有具實質意義的產品 check，維持 0 並說明缺口。
6. 除非我明確拒絕專案學習，否則保留 repository scope 的 harness-feedback Skill。不要安裝或修改任何 Global Workflow 設定。
7. 完成客製化並接上產品 checks 後，只有 Contract 的宣告都正確時，才將它更新成 Status: complete，然後執行 make verify。請在最後執行，不要把它當成第一個設定步驟。修正因設定造成的失敗，並回報最後驗證結果、所有修改檔案，以及仍未完成的 bootstrap 項目。
```
<!-- template-setup-prompt:end -->

備用 clone 方式、預期結果與完成清單請參考[入門教學](./docs/getting-started.zh-TW.md)。

## Harness 如何運作

```text
make verify
├── 檢查 Harness shell scripts
├── 執行 Harness 回歸測試
├── 驗證 repository Skills 與 Project Contract
└── 執行專案自己的 checks
```

GitHub Actions workflow 與本機開發使用相同的 `make verify` 入口。只有接上真正的產品 checks 後，專案才能回報 complete。在那之前，Contract 維持 `Status: bootstrap`，驗證會指出缺口，不會宣稱產品行為已通過。

## `0.1.0` 內建內容

- `AGENTS.md`：保存 Codex 在幾乎每次修改都應遵守的專案規則。
- Harness：提供可重複執行的回歸測試，以及適用於 Git repository 的 macOS／Linux CI。
- `harness-feedback`：可由 Codex 依任務選用，根據證據改善長期防護的 repository Skill。
- User scope `$vibe-engineering` Skill source：可安全地為其他專案執行 setup、status、upgrade 與以證據為基礎的 learning。

## 文件導覽

- **第一次使用：**[入門教學](./docs/getting-started.zh-TW.md)
- **接上測試、lint 與 build：**[Harness](./docs/harness.zh-TW.md)
- **調整專案規則與結構：**[客製化參考](./docs/customization.zh-TW.md)
- **安裝與使用 Skills：**[Skills 指南](./docs/skills.zh-TW.md)

## 支援範圍與授權

支援 Bash 3.2 以上的 macOS，以及使用 Bash 的 Linux。`0.1.0` 不正式支援原生 Windows 與 WSL。

本專案採用 MIT 授權。
