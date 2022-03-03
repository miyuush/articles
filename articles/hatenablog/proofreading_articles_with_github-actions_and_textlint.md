　はてなブログなどで記事を公開する際には、公開前に軽く誤字や脱字の確認をしていました。ただ、人の目での確認だと不備の見逃しがあったり、何より手間がかかります。この問題の解決するために、今回はGitHub Actionsとtextlintを使って校正作業を楽にしました。

## はじめに

　GitHub Actionsとtextlintについては、それぞれ下記のドキュメントが参考になると思います。  

GitHub Actionsは、GitHub上でさまざまな操作に応じて任意の処理を実行できる機能です。

* [GitHub Actionsのドキュメント - GitHub Docs](https://docs.github.com/ja/actions)
* [GitHubの新機能「GitHub Actions」で試すCI/CD](https://knowledge.sakura.ad.jp/23478/)

textlintは、テキストファイルに書かれた文章を校正するJavaScript製のツールです。

* [textlint](https://textlint.github.io/) 
* [textlint のインストールと基本的な使い方](https://maku.blog/p/3veuap5/)

textlintにはデフォルトでルールが設定されていないため、下記に記載されているルールのうち、必要なものをインストールする必要があります。

https://github.com/textlint/textlint/wiki/Collection-of-textlint-rule

## textlintの設定 

　今回は私の文章に馴染みそうなSmartHR用ルールプリセットをベースにします。

* [よりよい文書を書くための校正ツール「textlint」のSmartHR用ルールプリセットを公開しました！｜SmartHRオープン社内報](https://shanaiho.smarthr.co.jp/n/n881866630eda)
* [textlint-rule-preset-smarthr](https://github.com/kufu/textlint-rule-preset-smarthr)

さらに、単語の表記ゆれをチェックする[textlint-rule-prh](https://github.com/textlint-rule/textlint-rule-prh)と特定の文字列や文章をチェックしないようにする[textlint-filter-rule-allowlist](https://github.com/textlint/textlint-filter-rule-allowlist)を使います。

textlintの設定ファイル`.textlintrc`は下記のように作成しました。

```json
{
    "rules": {
        "preset-smarthr": {
            "sentence-length": {
                max: 150
            }
        },
        "prh": {
            "rulePaths": [
                "dict/prh.yml",
                "dict/WEB+DB_PRESS.yml"
            ]
        },
   },
    "filters": {
        "allowlist": {
            "allow": [
                "/http(.+):embed:cite/",    (1)
                "/.+👀/",                   (2)
                "/.+🐱/"                    (3)
            ]
        }
    }
}
```

　`preset-smarthr`にはデフォルトで多くのルールが含まれており、一文の最大文字数は120文字までとされています。私の感覚だと150文字くらいまで許容してほしいので、変更しています。他のルールはデフォルト値のままです。  
　`prh`には表記ゆれをチェックする単語の辞書ファイルを指定しています。`preset-smarthr`でもデフォルトで一部の単語をチェックしてくれますが、物足りないと感じたので[WEB+DB PRESS用語統一ルール](https://gist.github.com/inao/f55e8232e150aee918b9)をprh形式にした[WEB+DB_PRESS.yml](https://github.com/prh/rules/blob/master/media/WEB%2BDB_PRESS.yml)を少し改良して使っています。公開されている辞書ファイルでカバーできない場合は、辞書ファイルを自分で作成できます。[こちら](https://github.com/prh/prh/blob/master/misc/prh.yml)を参考に作成すると良いでしょう。
　`allowlist`にはtextlintでチェックしてほしくない文章のパターンを正規表現で指定しています。(1)では、はてなブログでURLの埋め込みをした場合になぜか`[`が閉じられていないというエラーが出てしまうので無視するようにしています。(2)と(3)は、文末が絵文字で終わっている場合に句点で終わっていないというエラーが出てしまうので無視するようにしています。絵文字については、この方法だと絵文字ごとに許可ルールを追加しないといけないため、正規表現で書けるなら書きたいな～という気持ちです。

## GitHub Actionsの設定

　GitHub Actionsの設定ファイルは、`textlint.yml`として作成しました。このファイルを`.github/workflows/`配下に保存してリポジトリにpushすることで、それ以降はmainブランチへのpush時にジョブが実行されます。

```yaml
name: textlint

on:
  push:
    branches: [ main ]

jobs:
  textlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - uses: actions/setup-node@v2

      - name: Install textlint
        run: >
          npm install --save-dev
          textlint
          textlint-rule-preset-smarthr
          textlint-rule-prh 
          textlint-filter-rule-allowlist
      
      - name: Install dependent module
        run: npm install
      
      - name: Execute textlint
        run: npx textlint "articles/**/*.md"
```

`textlint`ジョブの中で行っているのは下記です。

1. リポジトリのファイルをチェックアウト
2. Node.js環境のセットアップ
3. textlintとプリセットルールなどのインストール
4. その他、依存パッケージのインストール
5. `articles`ディレクトリ配下のMarkdown形式のファイルにtextlintを実行

## 実行

　本記事の初稿をリポジトリにpushしたときのtextlint実行結果は下記になります。



指摘箇所の行番号と指摘内容が表示されるので、指摘に従って修正する感じです。  
`smarthr/prh-rules`と`prh`の二重に指摘されていたりするので、今後改善できればと思っています。

## おわりに

　今回のGitHub Actionsとtextlintを使った校正作業の効率化は、下記の記事を参考に実施しました。また、textlintによる指摘事項をGitHubのPull Requestにコメントしてくれる[reviewdog](https://github.com/reviewdog/reviewdog)というツールもあるみたいですが、わざわざブランチを切ってPull Requestを作成するのは面倒だと感じたので導入しませんでした。

* https://zenn.dev/yuta28/articles/blog-lint-ci-reviewdog
* https://zenn.dev/serima/articles/4dac7baf0b9377b0b58b
* https://www.forcia.com/blog/002374.html
