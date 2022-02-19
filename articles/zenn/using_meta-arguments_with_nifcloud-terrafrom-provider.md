この記事は[富士通クラウドテクノロジーズ Advent Calendar 2021](https://qiita.com/advent-calendar/2021/fjct)の18日目の記事です。

17日目は[@toyo_mura](https://qiita.com/toyo_mura)さんの[コンテナ間でlogrotateしたいpart1](https://qiita.com/toyo_mura/items/4e8b0849df2cb8208f8c)でした。この記事では、実装コストと将来的にかかる管理コストの合計を検討しており、考え方も参考になります。コンテナ化は非常に便利ですので、part2が公開されるのが待ち遠しいですね！👀

さて、今回は2020年11月30日にリリースされて1年が経過したニフクラ向けのTerraform Providerで、メタ引数を使う場合の簡単な例を紹介します。

## はじめに

ニフクラ向けのTerraform Provider（正式名称はTerraform NIFCLOUD Provider）は、Terraformからニフクラのインフラストラクチャを操作するためのプラグインです。

このプラグインの説明や使い方は、いくつか記事が公開されているのでぜひご覧ください！

- [ニフクラがTerraformに対応したので使ってみた【基礎編】](https://blog.pfs.nifcloud.com/20201201_terraform_provider_nifcloud)
- [ニフクラがTerraformに対応したので使ってみた【応用編】](https://blog.pfs.nifcloud.com/20201215_terraform_provider_nifcloud)
- [Terraformを利用してニフクラRDBのDBサーバーを作成する4つの方法](https://blog.pfs.nifcloud.com/20210830_terraform_iac_nifcloudrdb)
- [Terraform NIFCLOUD Provider の NAS/Kubernetes Service Hatoba/サーバーセパレート機能を使ってみた](https://blog.pfs.nifcloud.com/20211012_terraform_nifcloud_nas_hatoba_ss)
- [ニフクラでTerraformのtfstateファイルを管理してみた](https://zenn.dev/tunakyonn/articles/50ca92cbdd676c)

これまでいろいろな使い方が紹介されているTerraform NIFCLOUD Providerですが、[Terraform Language公式ドキュメント](https://www.terraform.io/docs/language/index.html)に記載されているメタ引数についての例がなかったため、本記事で紹介します。

## メタ引数

メタ引数は、`resource`ブロックで定義することで`resource`の動作を変更できるものです。メタ引数には下記があります。

- [depends_on](https://www.terraform.io/docs/language/meta-arguments/depends_on.html)
- [count](https://www.terraform.io/docs/language/meta-arguments/count.html)
- [for_each](https://www.terraform.io/docs/language/meta-arguments/for_each.html)
- [provider](https://www.terraform.io/docs/language/meta-arguments/resource-provider.html)
- [lifecycle](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html)

この中で`count`、`for_each`、`lifecycle`を使ってみます。
`depends_on`と`provider`は[Terraform NIFCLOUD Providerのサンプル集](https://github.com/nifcloud/terraform-provider-nifcloud/tree/main/examples)で使用されているため、そちらを参照ください。

### count

`count`を使うと、値に設定した数分だけリソースを作成できます。例えば、同じ構成のニフクラサーバーを2台作成したい場合を考えてみます。`count`を使わないと下記のように2つの`resource`ブロックを使う必要があります。

```hcl
resource "nifcloud_instance" "web1" {
  instance_id       = "web001"
  availability_zone = "east-11"
  image_id          = data.nifcloud_image.ubuntu.id
  key_name          = nifcloud_key_pair.web.key_name
  security_group    = nifcloud_security_group.web.group_name
  instance_type     = "small"
  accounting_type   = "2"

  network_interface {
    network_id = "net-COMMON_GLOBAL"
  }

  network_interface {
    network_id = "net-COMMON_PRIVATE"
  }
}

resource "nifcloud_instance" "web2" {
  instance_id       = "web002"
  availability_zone = "east-11"
  image_id          = data.nifcloud_image.ubuntu.id
  key_name          = nifcloud_key_pair.web.key_name
  security_group    = nifcloud_security_group.web.group_name
  instance_type     = "small"
  accounting_type   = "2"

  network_interface {
    network_id = "net-COMMON_GLOBAL"
  }

  network_interface {
    network_id = "net-COMMON_PRIVATE"
  }
}
```

ここで、下記のように`count`に2を指定することで1つの`resource`ブロックから上記と同じ2台のニフクラサーバーを作成できます。サーバー名を「`web001`」と「`web002`」にしたいので、`instance_id`に[countオブジェクト](https://www.terraform.io/docs/language/meta-arguments/count.html#the-count-object)を埋め込んでいます。

こちらの方が、2台のサーバーはサーバー名以外は同じ構成と簡単に読み取れますね。構成を変更したい場合も1箇所を変更すれば良いのでミスが起きにくいです。

```hcl
resource "nifcloud_instance" "web" {
  count             = 2

  instance_id       = "web00${count.index+1}"
  availability_zone = "east-11"
  image_id          = data.nifcloud_image.ubuntu.id
  key_name          = nifcloud_key_pair.web.key_name
  security_group    = nifcloud_security_group.web.group_name
  instance_type     = "small"
  accounting_type   = "2"

  network_interface {
    network_id = "net-COMMON_GLOBAL"
  }

  network_interface {
    network_id = "net-COMMON_PRIVATE"
  }
}
```

参考：[文字列への式の埋め込み](https://www.terraform.io/docs/language/expressions/strings.html#interpolation)

このように、`count`は同じ種類かつ構成がほとんど同じリソースを複数作成したい場合に有用です。
なお、`count`で作成したリソースの一部を削除したい場合には問題が発生することがあるので注意が必要です。

参考：[【Terraform】countで作成したリソースを削除するときの注意点](https://dev.classmethod.jp/articles/terraform_count_delete/)

### for_each

`for_each`の使い所は、`count`と同じでリソースを複数作成する場合なのですが、`count`よりも柔軟に使用できます。

ここでは、ステージング環境と本番環境のそれぞれで使用するニフクラNASを作成することにします。

```hcl
locals {
    spec = {
        stgnas  = 200
        prdnas  = 500
    }
}

resource "nifcloud_nas_instance" "example" {
  for_each                = local.spec

  identifier              = each.key
  availability_zone       = "east-11"
  allocated_storage       = each.value
  protocol                = "nfs"
  type                    = 0
  nas_security_group_name = nifcloud_nas_security_group.example.group_name
}
```

上記では、ステージング環境のニフクラNAS(stgnas)はディスク容量が200GB、本番環境のニフクラNAS(prdnas)はディスク容量が500GB必要ですので、`locals`で`spec`というmapを定義しています。

`resource`ブロックでは`for_each`で`spec`の要素分だけニフクラNASを作成するよう指定して、`identifier`と`allocated_storage`に[eachオブジェクト](https://www.terraform.io/docs/language/meta-arguments/for_each.html#the-each-object)でNAS名とディスク容量を指定しています。

このように、`count`の場合は複数のリソースの差分をcountオブジェクトやlistを定義して組み合わせることになると思いますが、`for_each`では、listの他にmapや文字列のsetを定義してその要素分だけリソースを作成できます。（listの場合は文字列のsetに変換する必要あり）

### lifecycle

`lifecycle`はリソースの挙動を変更するためのメタ引数で、`resource`ブロックの中にネストして定義します。`lifecycle`ブロックには、以下の3種類の引数を使用できます。

- [create_before_destroy](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html#create_before_destroy)
- [prevent_destroy](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html#prevent_destroy)
- [ignore_changes](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html#ignore_changes)

それぞれの使い方を紹介します。

#### create_before_destroy

Terraformにおいて、設定を変更できないリソースの更新時には、既存のリソースを削除してから新しい設定のリソースを作成するというのがデフォルトの挙動になっています。この場合に`create_before_destroy`を使うと、新しい設定のリソースを作成してから、既存のリソースを削除するという挙動に変更されます。
`create_before_destroy`を使う場合の注意点として、一時的に既存のリソースと新しい設定のリソースが存在することになるため、リソース名が同一ゾーンで一意な制約がある場合等はリソースの作成ができません。

Terraform NIFCLOUD Providerにおける使い所はあんまり無さそうですが、DHCPオプションで`create_before_destroy`の使用例は下記になります。

```hcl
resource "nifcloud_dhcp_option" "example" {
  default_router       = "192.168.0.1"
  domain_name          = "example.com"
  domain_name_servers  = ["192.168.0.1", "192.168.0.2"]
  ntp_servers          = ["192.168.0.1"]
  netbios_name_servers = ["192.168.0.1", "192.168.0.2"]
  netbios_node_type    = "1"
  lease_time           = "600"

  lifecycle {
    create_before_destroy = true
  }
}
```

`terraform apply`の結果を見てみると、作成→削除になっています。

```sh
nifcloud_dhcp_option.example: Creating...
nifcloud_dhcp_option.example: Creation complete after 2s [id=dopt-0ewfhvt1]
nifcloud_dhcp_option.example (deposed object b6166517): Destroying... [id=dopt-09ti7wvm]
nifcloud_dhcp_option.example: Destruction complete after 1s
```

ちなみに、`create_before_destroy`を指定しないと削除→作成になります。

```sh
nifcloud_dhcp_option.example: Destroying... [id=dopt-0ewfhvt1]
nifcloud_dhcp_option.example: Destruction complete after 1s
nifcloud_dhcp_option.example: Creating...
nifcloud_dhcp_option.example: Creation complete after 1s [id=dopt-0r16fxwz]
```

#### prevent_destroy

`prevent_destroy`を設定されたリソースは、`terraform destoroy`コマンドで削除できなくなります。
`prevent_destroy`の使い所は、ニフクラDBサーバーやKubernetes Service Hatobaのクラスターなど、復旧するのが大変なリソースに設定する場面かと思います。とはいえ本番環境のリソースは基本的にどれも削除されると困ると思うので、`terraform plan`の実行結果をよく読むことが大切です。

ここでは、Kubernetes Service Hatobaのクラスターに使った例を紹介します。

```hcl
resource "nifcloud_hatoba_cluster" "example" {
  name           = "cluster001"
  description    = "mouse"
  firewall_group = nifcloud_hatoba_firewall_group.example.name
  locations      = ["east-11"]

  addons_config {
    http_load_balancing {
      disabled = true
    }
  }

  node_pools {
    name          = "default"
    instance_type = "medium"
    node_count    = 3
  }

  lifecycle {
      prevent_destroy = true
  }
}
```

上記で作成したリソースに、`terraform destroy`を実行すると下記のエラーになります。

```sh
➜  terraform destroy
nifcloud_hatoba_cluster.example: Refreshing state... [id=cluster001]
╷
│ Error: Instance cannot be destroyed
│
│   on prevent_destroy.tf line 13:
│   13: resource "nifcloud_hatoba_cluster" "example" {
│
│ Resource nifcloud_hatoba_cluster.example has lifecycle.prevent_destroy set, but the plan calls for this resource to be
│ destroyed. To avoid this error and continue with the plan, either disable lifecycle.prevent_destroy or reduce the scope of
│ the plan using the -target flag.
```

#### ignore_changes

`ignore_changes`を使うと、指定された設定の差分を無視できます。ここでは、ニフクラDBサーバーへの適用例を紹介します。

```hcl
resource "nifcloud_db_instance" "example" {
  accounting_type                = "2"
  availability_zone              = "east-11"
  instance_class                 = "db.large8"
  db_name                        = "cat"
  username                       = "pien"
  password                       = "neip"
  engine                         = "MySQL"
  engine_version                 = "5.7.15"
  allocated_storage              = 100
  storage_type                   = 0
  identifier                     = "example"
  backup_retention_period        = 2
  binlog_retention_period        = 2
  custom_binlog_retention_period = true
  backup_window                  = "00:00-09:00"
  maintenance_window             = "sun:22:00-sun:22:30"
  multi_az                       = true
  multi_az_type                  = 1
  port                           = 3306
  publicly_accessible            = true
  final_snapshot_identifier      = "example"
  skip_final_snapshot            = false
  read_replica_identifier        = "example-read"
  apply_immediately              = true

  lifecycle {
    ignore_changes = [password]
  }
}
```

ニフクラDBサーバーを作成する場合、マスターユーザーのパスワードを設定する必要があります。tfファイルにパスワードを平文で書いておくのはよろしくないので、`ignore_changes`で`password`を指定します。こうすると、作成時には初期パスワードを書いておいて、後からパスワードを変更しても差分は無視されます。（`ignore_changes`の指定項目はカンマで区切ることで複数指定できます）

この他の適用例としては、`prevent_destroy`と似たような使い方になりますが、変更するとリソースが再作成されてしまう項目のみ`ignore_changes`にしておくことで、想定外の再作成を防ぐことも可能です。

ニフクラDBサーバーでは、下記の項目を`ignore_changes`に設定することで設定変更では再作成が行われなくなります。

```hcl
  lifecycle {
    ignore_changes = [
        db_name,
        username,
        engine,
        engine_version,
        storage_type,
        availability_zone,
        port,
        publicly_accessible,
        restore_to_point_in_time,
        replicate_source_db,
        snapshot_identifier,
        ]
  }
```

## おわりに

今回はTerraformのメタ引数をTerraform NIFCLOUD Providerで使った例を紹介しました。現在対応しているニフクラリソースでは使い所が無さそうなものもありましたが、手段の一つとして覚えておこうと思います。
また、公式ドキュメントを読むとまだまだ知らない機能があるので今後も試してみたいと思いました。

明日は[@ysaotome](https://qiita.com/ysaotome)さんが[ニフクラ上の Docker ホストへ VMware Tanzu Community Edition(TCE) のマネージドクラスタを構築してみた（V0.9.1）](https://sotm.jp/2021/12/18/vmware-tanzu-community-edition-v091-managed-clusters-on-docker-on-nifcloud/)という記事を書いてくれるようです。お楽しみに！🐱
