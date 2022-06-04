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
bundle exec ruby scraping.rb -u <user> -p <password>
```

上記コマンドを実行すると、/outputディレクトリ内にハマトラSNS内で書いた自分の日記が出力されます。
日記は以下のようなフォーマットで出力されます。

```shell
output/
└── YYYYMMDDhhmmss
    ├── [日記に添付した画像ファイル].jpg
    └── [日記タイトル].txt
```