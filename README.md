# Nature Remo AC Menu Bar for macOS

macOSのメニューバーからNature Remo登録済みエアコンを操作する小さな常駐アプリです。ON/OFF、設定温度、冷房・ドライ・暖房の切り替え、選択したNature Remo本体の室温表示ができます。

GitHubのDescriptionには次のような文言がおすすめです。

```text
macOS menu bar app for controlling Nature Remo air conditioners
```

日本語寄りにするならこちらです。

```text
macOSメニューバーからNature Remoのエアコンを操作するアプリ
```

## できること

- エアコンのON/OFF
- メニューバーでエアコンの設定温度とON/OFF状態を表示
- 温度変更
- 冷房・ドライ・暖房の切り替え
- 選択したNature Remo本体の室温表示
- 複数エアコンがある場合の選択
- 複数Nature Remoがある場合の室温表示対象の選択
- ログイン時の自動起動
- Nature Remo Cloud APIトークンのKeychain保存

## 使い方

1. Nature Remoのアクセストークンを `https://home.nature.global/` で発行します。
2. アプリをビルドします。

```bash
Scripts/package_app.sh
```

3. 出力された `.build/NatureRemoMenuBar.app` を起動します。
4. メニューバーの `Remo` から `設定...` を開き、Cloud APIトークンを保存します。
5. 複数のNature Remoがある場合は、メニューの `Nature Remo` から室温表示に使う本体を選びます。
6. メニューから対象エアコンを選び、ON/OFF・温度・運転モードを操作します。
7. 自動起動したい場合は、メニューの `ログイン時に起動` をONにします。

## API

Nature Remo公式のCloud APIを使います。

- `GET /1/appliances`
- `GET /1/devices`
- `POST /1/appliances/{applianceid}/aircon_settings`

OFFは `button=power-off`、ONや温度・モード変更は `button=` と `operation_mode` / `temperature` を送ります。

## 公開時の注意

Nature Remo Cloud APIトークンはKeychainに保存されるため、リポジトリには含まれません。`.build/` 以下に生成されるビルド成果物もGit管理対象にしないでください。

## License

MIT
