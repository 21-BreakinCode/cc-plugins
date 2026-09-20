---
name: simple-mandarin
description: |
  Write or rewrite technical text in controlled Traditional Chinese
  (Taiwan) in the spirit of ASD-STE100 Simplified Technical English:
  short sentences by character count, active voice, one term one
  meaning, condition before command, terms defined at first use, no
  AI slop. Use for documentation, READMEs, runbooks, procedures, error
  messages, and release notes written in Chinese. The user's own words
  can trigger this skill too: "繁體中文技術文件", "台灣用語", "受控中文",
  "精簡中文", "simple mandarin", "controlled Chinese", or a request to
  check text against these rules. The same rules govern the reply in
  Mandarin. Answer first, in continuous text only.
license: MIT
compatibility: claude-code
metadata:
  version: "0.1.0"
---

# Simple Mandarin

用受控繁體中文（台灣）撰寫技術文件，一詞一義，句句到位。文件與回覆各有規則，如下所述。

## 文件規則

撰寫或改寫技術文件時，套用下列規則：

1. 每份文件只用一種標準用語，以台灣技術文件為準。例如「軟體」不用「軟件」。
2. 每個詞只代表一個概念。全文同一元件只用同一名稱，不換用同義詞。
3. 操作步驟用祈使句。每句不超過20字，一句只寫一個動作。
4. 說明文字用簡單句。每句不超過25字，一段只講一個主題。
5. 條件放在動作之前，中間加逗號。例如：「如果建置失敗，請查看紀錄。」
6. 每句都要有明確主詞。不用被動語態，不用倒裝句。
7. 動詞只用可以、將、必須。不用應該、也許、可能、或許。
8. 刪除行銷詞與贅字。例如：極致、賦能、全方位、無縫、值得注意的是。
9. 不用破折號，不用分號。改寫成兩句話，或直接說明關係。
10. 名詞不超過三個字疊加。過長的詞組要拆開，加一個介詞說明關係。
11. 專有名詞第一次出現時要定義。定義不超過10字，且只寫一次。
12. 警告先寫指令或條件，再寫風險。例如：「請勿在正式環境執行，此指令會刪除資料。」

`references/word-swaps.md` 列出台灣標準用語對照表。

**修改前：**

> 本軟件擁有極致的效能，能夠無縫整合各種系統，並且提供強大的功能，值得注意的是安裝時應該要注意環境設定。

**修改後：**

> 本軟體能整合其他系統。安裝前，請先確認環境設定。環境設定錯誤會導致安裝失敗。

## 回覆規則

用繁體中文回覆時，套用下列規則：

1. 第一句直接給答案，不重複問題。
2. 不用破折號。改用「因為」「但是」「例如」，或分成兩句。
3. 專有名詞第一次出現時，用不超過10字定義。
4. 不用開場白（如「好的」）或結尾語（如「希望這對你有幫助」）。
5. 錯誤訊息、安全警告、破壞性操作的確認文字，照原文引用，不省略。

## 檢查模式

使用者要求檢查文字，而非改寫文字時，先開啟 `references/rule-catalog.md`。然後依序列出每一項違規：引用規則編號、違規文字、修改後版本。規則編號一律從該檔案引用，不憑記憶。

## 限制

這些規則適用於事實與指令，不適用於行銷文案或品牌文字。使用者要求行銷文案時，先說明這一點，再另外提供行銷版本。

## 參考檔案

- `references/rule-catalog.md`：12項規則的完整版本，含範例，供檢查模式引用。
- `references/word-swaps.md`：台灣標準用語對照表。
