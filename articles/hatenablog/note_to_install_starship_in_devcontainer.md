　devcontainer環境でも[Starship](https://starship.rs/ja-JP/)を使いたいたかったのですが、シェル・ワンライナーへの理解が乏しくてインストールに苦戦したのでメモを書き残しておきます。

## TL;DR

devcontainerのDockerfileに以下のコマンドを書くことでインストール可能です。

```dockerfile
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes
```

## なんで苦戦したか

　通常、LinuxにStarshipをインストールするには以下のワンライナーを実行するのですが、インストールの過程でインタラクティブな入力が求められます（よくパッケージのインストール時に`[y/N]`が表示されて続行するには`y`を入力する必要があるヤツ）。今回の場合、devcontainerのビルド中、つまり`docker build`の実行中にインタラクティブな入力が求められるため、自動で`y`を入力してくれるようにする必要がありました。 

https://starship.rs/ja-JP/guide/#%F0%9F%9A%80-%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB

```sh
curl -sS https://starship.rs/install.sh | sh
```

`apt`や`yum`といったパッケージマネージャーを使ったインストールの場合は、`-y`をオプションとして指定することでインタラクティブな入力を求められずに済みます。  
今回も同じようにオプションを指定したかったのですが、上記のワンライナーではStarshipのインストールスクリプトを`curl`で取得して、`sh`に標準入力として渡して実行しています。インストールスクリプトのソースを見てみると、実行時にオプションで`-f, -y, --force, --yes`のいずれかを渡すとインタラクティブな入力がスキップされると書かれています。

https://github.com/starship/starship/blob/c40f0e7722dc4cf23dac4f19061d1342e4792002/install/install.sh#L142

なるほどと思い、以下のようにDockerfileに記載してdevcontainerを起動したのですがエラーになりました。

```dockerfile
RUN curl -sS https://starship.rs/install.sh | sh --yes
```

この指定ではインストールスクリプトではなく`sh`コマンドのオプションとして`-y`が渡されてしまうためです。

```sh
sh: 0: Illegal option -y
```

## 解決

　適当に「devcontainer starship」で検索したら、以下のコードを発見しました。

https://gist.github.com/jarrodldavis/928c90036273a557848f4c73d5d4e701#file-vscode-devcontainer-sh-L35

Dockerfileではないですが、ファイル名的にdevcontainerにStarshipをインストールするスクリプトのようだったので、`bash -s -- --yes`の意味を調べてみました。`man bash`を見ると以下のことが書いてあります（一部抜粋）。

```sh
--        -- はオプションの終わりを示し、それ以降のオプション処理を行いません。 -- 以降の引き数は全て、ファイル名や引き数として扱われます。 引き数 - は -- と同じです。
-s        -s オプションが指定された場合と、 オプションを全て処理した後に引き数が残っていなかった場合には、 コマンドは標準入力から読み込まれます。 このオプションを使うと、 対話的シェルを起動するときに 位置パラメータを設定できます。
```

どうやら、`-- --yes`は`--yes`をオプションではなく引数として扱うという意味で、`-s -- --yes`とすることで引数`--yes`を標準入力として読み込むという意味だと思われます。これにより、Starshipのインストールスクリプトのオプションとして`--yes`を渡すことができているという認識です（間違っていたらコメントいただけるとうれしいです）。Starshipの公式インストールワンライナーでは`bash`ではなく`sh`で実行するようになっていたのでそこだけ変更して実行するとうまくいきました（`sh`コマンドでもオプションの意味は同じです）。

```dockerfile
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes
```

## 最後に

　今回はDockerfileにStarshipのインストールを定義して不変的なイメージにしたかったので苦戦しましたが、devcontainerにStarshipをインストールして使うだけであれば、devcontainerの起動後にStarshipのインストールスクリプトを実行すれば問題ないです。また、devcontainerの[postCreateCommand](https://code.visualstudio.com/docs/remote/devcontainerjson-reference#_lifecycle-scripts)を使うとコンテナビルド時の初回のみインストールスクリプトが実行されます。

