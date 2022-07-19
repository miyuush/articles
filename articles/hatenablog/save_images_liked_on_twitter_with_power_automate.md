　Mirosoftが提供するPower AutomateというRPAツールを使ってみたかったので、試しにTwitterで「いいね」した画像をまとめて保存してくれるフローを作成しました。Power Automateについては、下記の記事が分かりやすいと思います。

[https://www.pc-koubou.jp/magazine/54261:title]

　私はUdemy for Businessが利用可能な環境なため、入門として下記の講座を受講しました。こちらの講座はエンジニアではない人を対象にしているようですので、説明が非常に丁寧で分かりやすかったです。

[https://www.udemy.com/course/masukawa_042/:title]

　この記事で使うのはデスクトップ版のPower Automate Desktopになります。

## 実現したこと

　今回実現したのは、ブラウザでTwitterアカウントのプロフィールから「いいね」のタブを開き、下にスクロールしながら画像が含まれるツイートの画像を保存することです。私の場合は約7000件の画像があったのでそれらをすべて保存しました。ブラウザはGoogle Chromeを利用しました。

[「いいね」画面の例](https://twitter.com/miyuush/likes)

　ちなみに、少なくとも今回作成したフローは、大量の画像を保存することに実行速度という面で向いていません（7000件保存するのに24時間くらいかかりました）。ノーコードでRPAを実現できるのがPower Automateの強みなのでやむなしですが、TwitterのAPIを利用してプログラムを書いたほうが大量の画像を高速に保存できると思います。

## 作成したフロー

下記が成果物のフローです（Robin言語版は記事の最後に示します）。

[f:id:miyuush:20220718210707p:plain]

### フローの解説

　まず、Google ChromeでTwitterアカウントのプロフィールから「いいね」のタブを開いて下にスクロールしていくと、Google ChromeのデベロッパーツールのElementsパネルから表示されるツイートのHTMLソースが入れ替わることが確認できます。
　下記にHTMLソースの一部を示します。`<div data-testid="cellInnerDiv"`で始まる行が各ツイートのHTMLソースで、スクロール前には1行目に表示されているツイートがスクロール後には消えていることが分かります。そして、スクロール前に2行目以降に表示されていたツイートが1行上に繰り上がっています（`transform`の部分を見ると分かりやすい）。

<figure class="figure-image figure-image-fotolife" title="スクロール前">[f:id:miyuush:20220718210902p:plain]<figcaption>スクロール前</figcaption></figure>

<figure class="figure-image figure-image-fotolife" title="スクロール後">[f:id:miyuush:20220718211006p:plain]<figcaption>スクロール後</figcaption></figure>

　作成したフローはこのしくみを利用して、HTMLソースの1行目に表示されているツイートの画像を保存したら、次のツイートが1行目に表示されるまでスクロールする流れになっています。

　各アクションについて軽く説明していきます。  
　3～5行目では初期処理として下に100回スクロールしていますが、これは最初にHTMLソースの1行目が入れ替わるまでには多くのスクロールが必要になるからです。  
　6行目以降で下スクロールしながら画像を保存するループ処理になります。ループ条件には、保存したい画像の枚数を設定します。  
　7～9行目では下に15回スクロールしていて、これより多くスクロールすると画像を保存する前にさらに次の画像に入れ替わってしまいそうでした（あんまり詳細には検証していない）。  
　10行目では同じ画像を2回保存しない条件分岐のために、直前の画像を保存しています。  
　11～16行目では画像を取得して、まだ保存していなければ保存する処理になっています。画像のファイル名にツイートに含まれている文字と投稿者のIDを含めたかったので取得しています。また、11、15行目ではツイートに画像が含まれていない場合やツイートに文字が含まれていない場合の例外処理でラベルに飛ぶようにしています。16行目では、ツイートの文字が絵文字だったりしてファイル名には使用できない場合に、20行目で別のファイル名として保存する例外処理を設定しています。

　ツイートの画像や文字を指定する方法は下記の記事を参考にしました。

[https://techlive.tokyo/archives/11993#i-4:title]

### フローの課題

　自分が使うためにお試しで作ったので多分改善しないですが一応書いておきます。

- ツイートに画像が2枚以上含まれている場合は保存できない
  - 条件を追加すれば解決しそう
- 実行に時間がかかる
  - 大量の画像保存にはプログラミングしましょう
- スクロールができないところまで読み込むと、HTMLソースの入れ替わりが起きないため最後の数枚は手動で保存する必要がある
  - 条件を追加すれば解決しそう

## 感想

　初めてPower Automateを使いましたが、ノーコードで簡単に操作を自動化できて便利だなと思いました。特に環境構築がPower Automateのインストールだけで済むのが良いですね。Windowsで定期的にどうしても単純作業をする必要がある場合は活用していきたいと思いました。

---

フローをテキスト出力したものは下記になります。フローの画面にペーストすれば（TwitterのHTMLソースの構造が変わらなければ）動くはず。

```sh
SET Count TO 0
WebAutomation.LaunchChrome.LaunchChrome Url: $'''https://twitter.com/[*****  TwitterのユーザーID  *****]/likes''' WindowState: WebAutomation.BrowserWindowState.Maximized ClearCache: False ClearCookies: False WaitForPageToLoadTimeout: 60 Timeout: 60 BrowserInstance=> Browser
LOOP LoopIndex FROM 1 TO 100 STEP 1
    MouseAndKeyboard.SendKeys.FocusAndSendKeys TextToSend: $'''{Down}''' DelayBetweenKeystrokes: 1 SendTextAsHardwareKeys: False
END
LOOP WHILE (Count) < ([*****  保存したい画像の数  *****])
    LOOP LoopIndex FROM 1 TO 15 STEP 1
        MouseAndKeyboard.SendKeys.FocusAndSendKeys TextToSend: $'''{Down}''' DelayBetweenKeystrokes: 1 SendTextAsHardwareKeys: False
    END
    SET OldImage TO image
    WebAutomation.GetDetailsOfElement BrowserInstance: Browser Control: appmask['Recording']['Image'] AttributeName: $'''src''' AttributeValue=> image
    ON ERROR
        GOTO Next_Loop
    END
    IF image <> OldImage THEN
        Variables.IncreaseVariable Value: Count IncrementValue: 1
        WebAutomation.GetDetailsOfElement BrowserInstance: Browser Control: appmask['Recording']['Span'] AttributeName: $'''innertext''' AttributeValue=> UserID
        WebAutomation.GetDetailsOfElement BrowserInstance: Browser Control: appmask['Recording']['Div'] AttributeName: $'''Own Text''' AttributeValue=> ImageName
                ON ERROR
                    GOTO Catch_Error
                END
        Web.DownloadFromWeb.DownloadToFile Url: image FilePath: $'''C:\\[*****  画像を保存するフォルダーのパス  *****]\\%ImageName%_%UserID%_%Count%.png''' ConnectionTimeout: 30 FollowRedirection: True ClearCookies: False UserAgent: $'''Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.21) Gecko/20100312 Firefox/3.6''' Encoding: Web.Encoding.AutoDetect AcceptUntrustedCertificates: False DownloadedFile=> DownloadedFile
                ON ERROR
                    GOTO Catch_Error
                END
    END
    GOTO Next_Loop
    LABEL Catch_Error
    Web.DownloadFromWeb.DownloadToFile Url: image FilePath: $'''C:\\[*****  画像を保存するフォルダーのパス  *****]\\%UserID%_%Count%.png''' ConnectionTimeout: 30 FollowRedirection: True ClearCookies: False UserAgent: $'''Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.21) Gecko/20100312 Firefox/3.6''' Encoding: Web.Encoding.AutoDetect AcceptUntrustedCertificates: False DownloadedFile=> DownloadedFile
    LABEL Next_Loop
END

# [ControlRepository][PowerAutomateDesktop]

{
  "ControlRepositorySymbols": [
    {
      "Name": "appmask",
      "ImportMetadata": {
        "DisplayName": "Computer",
        "ConnectionString": "",
        "Type": "Local"
      },
      "Repository": "{\r\n  \"Screens\": [\r\n    {\r\n      \"Controls\": [\r\n        {\r\n          \"AutomationProtocol\": null,\r\n          \"ScreenShot\":null,\r\n          \"ElementTypeName\": \"img\",\r\n          \"InstanceId\": \"e1bae100-666e-4638-a98c-f75772a74955\",\r\n          \"Name\": \"Image\",\r\n          \"SelectorCount\": 1,\r\n          \"Selectors\": [\r\n            {\r\n              \"CustomSelector\": \"html > body > div:eq(0) > div > div > div:eq(1) > main > div > div > div > div > div > div:eq(1) > div > div > section > div > div > div:eq(0) > div > div > div > article > div > div > div > div:eq(1) > div:eq(1) > div:eq(1) > div:eq(1) > div > div > div > div > div > a > div > div:eq(1) > div > img\",\r\n              \"Elements\": [],\r\n              \"Ignore\": false,\r\n              \"IsCustom\": true,\r\n              \"IsWindowsInstance\": false,\r\n              \"Order\": 0,\r\n              \"Name\": \"Selector\"\r\n            }\r\n          ],\r\n          \"Tag\": \"img\"\r\n        },\r\n        {\r\n          \"AutomationProtocol\": null,\r\n          \"ScreenShot\":null,\r\n          \"ElementTypeName\": \"span\",\r\n          \"InstanceId\": \"7f1fa613-e9da-42e9-a744-d5ceb31e81f9\",\r\n          \"Name\": \"Span\",\r\n          \"SelectorCount\": 1,\r\n          \"Selectors\": [\r\n            {\r\n              \"CustomSelector\": \"html > body > div:eq(0) > div > div > div:eq(1) > main > div > div > div > div > div > div:eq(1) > div > div > section > div > div > div:eq(0) > div > div > div > article > div > div > div > div:eq(1) > div:eq(1) > div:eq(0) > div > div > div:eq(0) > div > div > div:eq(1) > div > div:eq(0) > a > div > span\",\r\n              \"Elements\": [],\r\n              \"Ignore\": false,\r\n              \"IsCustom\": true,\r\n              \"IsWindowsInstance\": false,\r\n              \"Order\": 0,\r\n              \"Name\": \"Selector\"\r\n            }\r\n          ],\r\n          \"Tag\": \"span\"\r\n        },\r\n        {\r\n          \"AutomationProtocol\": null,\r\n          \"ScreenShot\":null,\r\n          \"ElementTypeName\": \"div\",\r\n          \"InstanceId\": \"feee3c25-5fc6-41a9-81de-2e04536235d2\",\r\n          \"Name\": \"Div\",\r\n          \"SelectorCount\": 1,\r\n          \"Selectors\": [\r\n            {\r\n              \"CustomSelector\": \"html > body > div:eq(0) > div > div > div:eq(1) > main > div > div > div > div > div > div:eq(1) > div > div > section > div > div > div:eq(0) > div > div > div > article > div > div > div > div:eq(1) > div:eq(1) > div:eq(1) > div:eq(0) > div\",\r\n              \"Elements\": [],\r\n              \"Ignore\": false,\r\n              \"IsCustom\": true,\r\n              \"IsWindowsInstance\": false,\r\n              \"Order\": 0,\r\n              \"Name\": \"Selector\"\r\n            }\r\n          ],\r\n          \"Tag\": \"div\"\r\n        }\r\n      ],\r\n      \"ScreenShot\": null,\r\n      \"ElementTypeName\": \"Web Page\",\r\n      \"InstanceId\": \"34c30439-3854-4b4a-928a-dd5583594fae\",\r\n      \"Name\": \"Recording\",\r\n      \"SelectorCount\": 1,\r\n      \"Selectors\": [\r\n        {\r\n          \"CustomSelector\": null,\r\n          \"Elements\": [\r\n            {\r\n              \"Attributes\": [],\r\n              \"CustomValue\": null,\r\n              \"Ignore\": false,\r\n              \"Name\": \"Web Page\",\r\n              \"Tag\": \"domcontainer\"\r\n            }\r\n          ],\r\n          \"Ignore\": false,\r\n          \"IsCustom\": false,\r\n          \"IsWindowsInstance\": false,\r\n          \"Order\": 0,\r\n          \"Name\": \"Selector\"\r\n        }\r\n      ],\r\n      \"Tag\": \"domcontainer\"\r\n    }\r\n  ],\r\n  \"Version\": 1\r\n}"
    }
  ],
  "ImageRepositorySymbol": {
    "Name": "imgrepo",
    "ImportMetadata": {},
    "Repository": "{\r\n  \"Folders\": [],\r\n  \"Images\": [],\r\n  \"Version\": 1\r\n}"
  }
}

```
