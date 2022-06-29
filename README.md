## ハマトラSNS日記exporter

惜しまれつつ閉鎖が決まったハマトラSNSから自分の日記をテキストで抽出するプログラムです。

### Prerequisite

- Ruby
  - Windows環境化のWSL2(Ubuntu 18.04)上のRuby 3.1で動作確認

### Usage

```shell
bundle install
# -u: ハマトラSNSのユーザー名 (メールアドレス)
# -p: ハマトラSNSのログインパスワード
# -c: 付与した場合、指定したコミュニティIDのメッセージを取得
bundle exec ruby scraping.rb -u <user> -p <password> -c <community_id>
```

上記コマンドを実行すると、/outputディレクトリ内にハマトラSNS内で書いた自分の日記が出力されます。
日記・コミュニティは以下のようなフォーマットで出力されます。

```shell
output/
├── my_diary
│      └── YYYYMMDDhhmmss
│             ├── [日記に添付した画像ファイル].jpg
│             └── [日記タイトル].txt
└── communities
    └── [コミュニティID]
        └── messages.txt
```
