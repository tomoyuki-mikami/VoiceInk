# Add-on Local Model Integration

`Qwen3-ASR`、`Cohere Transcribe`、`Parakeet Japanese` のような fork 固有モデルは、できるだけ既存実装の内側へ混ぜ込まず、追加レイヤーとして外付けする。

狙いは次の 3 つです。

1. fork 固有ロジックを既存 core から切り離す
2. upstream sync 時に衝突しやすい既存ファイルの差分を最小限にする
3. 今後 add-on モデルが増えても、追加先をほぼ add-on 層だけに限定する

## Overview

```mermaid
flowchart LR
    subgraph Upstream["既存側（upstream に近い層）"]
        App["VoiceInk.swift"]
        Engine["VoiceInkEngine"]
        UI["ModelManagementView"]
        TM["TranscriptionModelManager<br/>既存責務"]
        SR["TranscriptionServiceRegistry<br/>既存責務"]
    end

    subgraph Addon["追加レイヤー（fork 固有の外付け層）"]
        Catalog["AddonLocalModelCatalog"]
        AModelMgr["AddonAwareTranscriptionModelManager"]
        ARegistry["AddonAwareTranscriptionServiceRegistry"]
        Prep["AddonAwareModelPreparationCoordinator"]
        Integrations["AddonLocalIntegration 群<br/>Qwen / Cohere / Parakeet"]
        AddonUI["AddonAwareModelManagementContentView"]
        QwenSvc["QwenTranscriptionService"]
        CohereSvc["CohereTranscriptionService"]
        ParaSvc["JapaneseParakeetTranscriptionService"]
    end

    subgraph Models["追加モデル実装"]
        Qwen["Qwen3-ASR"]
        Cohere["Cohere Transcribe"]
        Parakeet["Parakeet Japanese"]
    end

    App -->|"起動時に注入"| Catalog
    App -->|"起動時に注入"| AModelMgr
    App -->|"起動時に注入"| Engine

    Engine -->|"入口だけ差し替え"| ARegistry
    Engine -->|"モデル準備だけ委譲"| Prep

    UI -->|"local セクションに差し込み"| AddonUI

    AModelMgr -.->|"既存 TM を拡張"| TM
    ARegistry -.->|"既存 SR を拡張"| SR

    Catalog --> Integrations
    Integrations --> QwenSvc
    Integrations --> CohereSvc
    Integrations --> ParaSvc

    QwenSvc --> Qwen
    CohereSvc --> Cohere
    ParaSvc --> Parakeet

    Catalog -->|"どの add-on を使うか判定"| AModelMgr
    Catalog -->|"どの service を使うか判定"| ARegistry
    Catalog -->|"どの model を prepare するか判定"| Prep
```

## How To Read

- 既存側で触るのは主に `VoiceInk.swift`、`VoiceInkEngine`、`ModelManagementView` のような入口だけ
- add-on 固有の判定、モデル一覧の統合、ダウンロード済み判定、準備処理、文字起こしサービス切り替えは `AddonAware*` と `AddonLocalModelCatalog` に寄せる
- `Qwen`、`Cohere`、`Parakeet` の個別実装は `Integration` と専用 service の下に閉じ込める

## Practical Rule

- 新しい add-on モデルを足すときは、まず `AddonLocalModelCatalog` と `AddonLocalIntegration` 側で完結できないかを優先する
- 既存の `TranscriptionModelManager` や `TranscriptionServiceRegistry` を直接広げるのは、add-on 層だけでは吸収できないときに限る
- 既存 UI への変更は、入口の差し込みにとどめる

## Local Build Usage

1. `make local` を実行する
2. 出力された `.app` を `Applications` フォルダへ入れる
3. 既存の `VoiceInk` があれば、そのまま上書きする

アクセシビリティや画面共有の権限設定がうまく反映されないことがある。

その場合は、macOS の権限設定から既存の `VoiceInk` を一度削除し、そのあと新しい `VoiceInk.app` を再度追加すると改善することがある。

## Current Limitation

upstream との差分を増やしすぎないことを優先しているため、add-on モデルでは prewarm と Power Mode 用の初期ロードにはまだ対応していない。

そのため、`Qwen3-ASR`、`Cohere Transcribe`、`Parakeet Japanese` を選んだ直後の最初の 1 回は、モデル準備のぶんだけ少し待ち時間が長くなる。

`Cohere Transcribe` だけは、`MLXAudioSTT` の公開 API がカスタム cache 注入をまだ受けていないため、保存先は VoiceInk の `Application Support` 配下ではなく Hugging Face の既定 cache 配下を使う。

2 回目以降は、同じ実行中セッション内でモデルが準備済みなら、最初の 1 回ほどの遅さは出にくい。
