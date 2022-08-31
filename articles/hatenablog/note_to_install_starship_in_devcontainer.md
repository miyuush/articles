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

ならばと思い、以下のようにDockerfileに記載してdevcontainerを起動したのですがエラーになりました。

```dockerfile
RUN curl -sS https://starship.rs/install.sh | sh --yes
```

todo: エラーを再現してみる

このあとの構成
- gistのコードを参考にしたら上手くいった
  - https://gist.github.com/jarrodldavis/928c90036273a557848f4c73d5d4e701#file-vscode-devcontainer-sh-L35
- `-s`オプションと`--`の説明
- ちなみにpostcreatecommandでの実行でもインストールは上手くいった（初回起動時にyを入力する必要あり）
