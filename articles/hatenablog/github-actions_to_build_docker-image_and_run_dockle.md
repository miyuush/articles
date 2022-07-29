　GitHub ActionsでDockerイメージをビルドして、コンテナイメージのセキュリティ診断ツール[Dockle](https://qiita.com/tomoyamachi/items/bb6ac5788bb734c91282)を実行するようにしました。
　GitHub Actionsの設定ファイルは下記になります（Docker BuildとDockleの実行部分のみ抜粋）。

```yaml
env:
  TEST_TAG: textlint-articles:1.0.0

jobs:
  dockle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: docker/setup-buildx-action@v2

      - name: Cache Docker layers
        uses: actions/cache@v3
        with:
          path: /tmp/.buildx-cache
          key: ${{ runner.os }}-buildx-${{ github.sha }}
          restore-keys: |
            ${{ runner.os }}-buildx-
            
      - name: Only docker build
        uses: docker/build-push-action@v3
        with:
          context: .
          load: true
          tags: ${{ env.TEST_TAG }}
          cache-from: type=local,src=/tmp/.buildx-cache
          cache-to: type=local,dest=/tmp/.buildx-cache-new,mode=max

      - name: Move cache
        run: |
          rm -rf /tmp/.buildx-cache
          mv /tmp/.buildx-cache-new /tmp/.buildx-cache

      - uses: hands-lab/dockle-action@v1
        with:
          image: ${{ env.TEST_TAG }}
          exit-code: '1'
          exit-level: WARN
```

　ちなみに設定ファイル全体は下記の通りで、Dockerfile自体のLintツールである[hadolint](https://github.com/hadolint/hadolint)も実行するようにしています（記事管理用のリポジトリなので[textlint](https://github.com/textlint/textlint)も）。

[https://github.com/miyuush/articles/blob/1768256f77e24a1386f368f1cb809d733a5b6c0e/.github/workflows/textlint.yml:embed:cite]

　Dockleを実行するうえでの工夫点は2つあります。
　1つ目は、`docker/build-push-action@v3`を使ってイメージをビルドしたあとに`load`オプションでDockerイメージとして出力するようにしている点です。  

https://github.com/docker/build-push-action/blob/master/docs/advanced/export-docker.md  

　2つ目は、`hands-lab/dockle-action@v1`の`exit-code`オプションに`1`を設定している点です。これにより、DockleのチェックでWARNレベル以上の項目に引っかかればCIが失敗します。

## 参考

- [https://github.com/marketplace/actions/runs-dockle:title]
- [https://dev.classmethod.jp/articles/github-actions-docker-layer-cache-enable/:title]

