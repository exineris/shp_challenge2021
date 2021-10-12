# shp_challenge2021

## バージョン情報
開発環境のErlangとElixirのバージョンは以下。

  * Erlang-OTP: 24.0.5
  * Elixir: 1.12.2-otp-24


## ディレクトリ構成
```
❯ tree -L 2 shp_challenge2021
shp_challenge2021
├── README.md
├── combo           # Exibee Combo用ディレクトリ
│   ├── exibee
│   └── phxexibee
├── debug           # デバッグツール用ディレクトリ
│   ├── README.md
│   ├── _build
│   ├── config
│   ├── deps
│   ├── lib
│   ├── mix.exs
│   ├── mix.lock
│   └── test
├── dio             # Exibee DIO用ディレクトリ
│   └── exibee
└── docs            # ドキュメント用ディレクトリ
    ├── fig
    └── spec.md
```

## Nerves情報

### MIX_TARGET
  * bash → `export MIX_TARGET=bbb`
  * fish → `set -x MIX_TARGET bbb`

### バージョン

```
❯ mix nerves.info
(略)
Nerves:           1.7.11
Nerves Bootstrap: 1.10.2
Elixir:           1.12.2
```