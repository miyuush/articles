# articles [![textlint](https://github.com/miyuush/articles/actions/workflows/textlint.yml/badge.svg)](https://github.com/miyuush/articles/actions/workflows/textlint.yml)

下記で公開する記事を管理するリポジトリ

* Hatena Blog: https://miyuush.hatenablog.com/about
* Qiita: https://qiita.com/miyuush
* Zenn: https://zenn.dev/miyuush

辞書ファイルはこちらを参考にしています。  
https://github.com/prh/rules

## textlintを使った記事の校正

　textlintの実行環境はDockerコンテナイメージにしたので、下記コマンドを実行して文章の校正が可能です。

1. Dockerコンテナイメージのビルド

```sh
make build 
```

2. `articles/`配下の記事を校正

```sh
make lint
```

3. その他ファイルを指定して校正

```sh
docker container run --rm textlint-articles:latest [ファイルのパス]
```
