本記事では、Twitterで「いいね！」したツイートに別ページへのリンクが含まれている場合(※)に、そのページのリンク(※)をSlackに投稿する方法を紹介します。

私自身、主に情報収集のためにTwitterを利用しているのですが、興味のある記事を見つけてもその場で読む時間がなかったり、有益な内容であれば後で何度か見返したいと思うことがあります。そこで、最近使い始めた個人Slackに情報を集約したいと思って実装しました。 ~~仕事でJavaScriptに触れたため勉強しようとしたが、特にやりたいことがなかったため互換性のあるGASを使ってみた~~

実装には以下を用いました。
- [Twitter API](https://help.twitter.com/ja/rules-and-policies/twitter-api)：Twitterの情報にアクセスするため
- [GoogleAppsScript](https://developers.google.com/gsuite/aspects/appsscript?hl=ja)(GAS)：「いいね！」したツイートの情報をSpreadsheetに取得してSlackに通知するため
- [Slack Incoming Webhook](https://api.slack.com/messaging/webhooks)：GASからSlackにメッセージを送信するため

※ツイートに別ページへのリンクが含まれていない場合にもslackに投稿されたり、別ページのリンクが含まれている場合にもそのツイート自体のリンクが投稿されることがあります。~~後述するようにAPIから取得したデータで判断しているのですが、適切な判断項目を発見できていないのでご存知の方がいたらコメントにて教えていただけると幸いです~~

# 処理の大まかな流れ
1. Twitterで「いいね！」をする
2. GASでTwitter APIを利用して「いいね！」した最近のツイート100件を取得
3. 取得したツイートの中でURLが含まれているものだけ、Spreadsheetに保存
4. 保存されたツイートに含まれている別ページへのリンクをIncoming Webhookに渡す
5. Incoming WebhookからSlackに投稿

# 準備
## GAS入門
まず、GASで書いたスクリプトを実行できる環境を準備する必要があります。
私はGASを書いたことがなかったため、以下のサイトで学習しました。
　[Google Apps Script（GAS）入門](https://excel-ubara.com/apps_script1/)

本記事の実装を再現するだけならこのサイトの[第3回](https://excel-ubara.com/apps_script1/GAS003.html)までを理解できていれば良いです。

## Twitter APIのキーを取得
次に、Twitter APIの申請を行ってAPIキーを取得する必要があります。
私は以下の記事を参考に行いました。
　[2020年度版 Twitter API利用申請の例文からAPIキーの取得まで詳しく解説](https://www.itti.jp/web-direction/how-to-apply-for-twitter-api/)

APIキー取得時にCallback URLsを設定しますが、ここには
　`https://script.google.com/macros/d/[スクリプトID]/usercallback`
と入力します。

スクリプトIDは
　GASのスクリプトエディタ→ツールバーの「ファイル」→「プロジェクトのプロパティ」→情報タブの「スクリプトID」
から参照できます。

取得したAPIキーとAPIシークレットキーは実装時に必要となるため、再度参照できるようにしておきます。

## TwitterWebServiceライブラリの導入
次に、GASからTwitter APIを利用するために必要な外部ライブラリ**[TwitterWebService](https://gist.github.com/M-Igashi/750ab08718687d11bff6322b8d6f5d90)**を導入します。
GASにおけるライブラリについてと導入方法は以下の記事が分かりやすいです。
　[Google Apps Script(GAS)入門 ライブラリとは？メリットと導入方法を解説](https://auto-worker.com/blog/?p=677)

プロジェクトキーは`1rgo8rXsxi1DxI_5Xgo_t3irTw1Y5cxl2mGSkbozKsSXf2E_KBBPC3xTF`と入力します。
バージョンは最新のものにします。（2020年5月現在の最新は2）

## SlackにIncoming Webhookを追加
最後に、GASからIncoming Webhookを介してSlackに投稿するため、SlackにIncoming Webhookを追加します。
私はカスタムインテグレーションで設定してしまいましたが、[非推奨](https://api.slack.com/legacy/custom-integrations#migrating_to_apps)のようなので、以下の記事を参考に設定します。
　[SlackのIncoming WebhookをカスタムインテグレーションではなくSlack Appから設定してみる](https://dev.classmethod.jp/articles/slack-incoming-webhook-by-slack-app/)

Webhook URLは実装時に必要となるため、再度参照できるようにしておきます。

# 実装
## ツイートをSpreadsheetに取得
まずは、GASでTwitter APIを利用して「いいね！」したツイートをSpreadsheetに取得します。
この機能を実装したのが以下のスクリプトです。
`*****API-key*****`と`*****API-secret-key*****`は自分で取得したキーに書き換えます。

```javascript:get_fav.gs

// TwitterWebServiceを利用するためのインスタンスを取得
var twitter = TwitterWebService.getInstance(
 'SrqHxo7FKJzJmBn0eB8VP6tIw',       // 作成したアプリケーションのAPIキー
 'Hksw0Sili1lwOBJw8twDDoErin5hko2D31MvjhEQbE9j3WgcS5'  // 作成したアプリケーションのAPIシークレットキー
);

// Twitterの事前認証を行う（必須）
function authorize() {
  twitter.authorize();
}

// Twitterの認証をリセット
function reset() {
  twitter.reset();
}

// Twitterの事前認証後のコールバック（必須）
function authCallback(request) {
  return twitter.authCallback(request);
}


// 「いいね！」したツイートの内、URLが含まれているものをSpreadsheetに書き込む
function getMyFavorites() {
  var service  = twitter.getService();
  // 「いいね！」した最新の100ツイートを取得（JSON形式）
  var favTweetsJson = service.fetch("https://api.twitter.com/1.1/favorites/list.json?count=100");
  // favTweetsJson（文字列）をJSONとして解析する（読み込む）
  var favTweetsArray = JSON.parse(favTweetsJson);

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var activeSheet = SpreadsheetApp.getActiveSheet();
  var lastRow = activeSheet.getLastRow() + 1;
  var IS_ALREADY_POST = 0;

  for(var i = 0; i <= favTweetsArray.length -1; i++) {

    var index = parseInt(i);
    // ツイートにURLが含まれていればURL等をJSON形式で取得
    var urls = favTweetsArray[index]['entities']['urls'];

    if (urls.length == 0){
      continue;
    }

    var id = favTweetsArray[index]["id"];
    var time = favTweetsArray[index]["created_at"];
    var text = favTweetsArray[index]["text"];

    var urlStrSliced = extractUrl(urls);

    if (lastRow > 1){
      // URLを含んだツイートが既にSpreadsheetに保存されているか
      IS_ALREADY_POST = searchUrl(lastRow, urlStrSliced, activeSheet);
    }
    // Spreadsheetに存在しなければツイートを追記
    if (IS_ALREADY_POST == 0){
      activeSheet.getRange(lastRow,1).setValue(time);
      activeSheet.getRange(lastRow,2).setValue(text);
      activeSheet.getRange(lastRow,3).setValue(urlStrSliced);
      activeSheet.getRange(lastRow,4).setValue(id);

      lastRow = lastRow + 1;
    }
   }
}

/**
 * URLを含むJSONからURLのみをStringで抽出
 * @param {object} urls URL等を含むJSONオブジェクト
 * @return {string} urlStrSliced URL
 */
function extractUrl(urls){
  // urlsStrの例（string）：[{"url":"https://..........","expanded_url":"http://..........","display_url":"...........","indices":[??,??]}]
  var urlsStr = JSON.stringify(urls);

  // urlExtractの例（object）：["expanded_url":"https://..........", a, b., /..........]
  var urlExtract = urlsStr.match(/"expanded_url":"http(s)?:\/\/([\w-]+\.)+[\w-]+(\/[\w- .\/?#%&=]*)?"/i);

  // urlExtractSlicedの例（object）： ["expanded_url":"https://.........."]
  var urlExtractSliced = urlExtract.slice(0, 1);

  // urlExtractSlicedStrの例（string）：["\"expanded_url\":\"https://..........\""]
  var urlExtractSlicedStr = JSON.stringify(urlExtractSliced);

  // urlの例（object）： [https://..........]
  var url = urlExtractSlicedStr.match(/http(s)?:\/\/([\w-]+\.)+[\w-]+(\/[\w- .\/?#%&=]*)?/i).slice(0, 1);

  // urlStrの例（string）： ["https://.........."]
  var urlStr = JSON.stringify(url);

  // urlStrSlicedの例（string）： https://..........
  var urlStrSliced = urlStr.slice(2, -2);

  return urlStrSliced;
}

/**
 * URLがSpreadsheetに保存されていれば行番号を返す
 * @param {number} lastRow Spreadsheetの最終行番号+1
 * @param {string} url URL
 * @param {object} sheet Spreadsheet内のアクティブなsheet
 * @return {number} URL_IS_THERE urlが存在すればsheet内の行番号、存在しなければ0
 */
function searchUrl(lastRow, url, sheet){
 // SpreadsheetからC列(url)を配列で取得
  var urlsArray = getArray(lastRow, sheet);
  // indexOf()：配列からurlが見つかれば行番号（0から）、見つからなければ-1を返す
  var URL_IS_THERE = urlsArray.indexOf(url) + 1;

  return URL_IS_THERE;
}

/**
 * Spreadsheetに保存されているURLを配列で取得
 * @param {number} lastRow Spreadsheetの最終行番号+1
 * @param {object} sheet Spreadsheet内のアクティブなsheet
 * @return {object} urlsArray sheet内に保存されているURLの配列
 */
function getArray(lastRow, sheet) {
  var searchRange = sheet.getRange("C1:C" + lastRow);
  var urls = searchRange.getValues();
  var urlsArray = [];
  for(var i = 0; i < urls.length -1; i++){
    url = JSON.stringify(urls[i]);
    urlsArray.push(url.slice(2, -2));
  }
  return urlsArray;
}
```

**初めてGASからTwitter APIの機能を利用する場合は、Twitterの認証を行う必要があります。**
そのため、以下の記事を参考に`authorize()`を実行して、ログに出力されているURLにアクセスして認証します。
　[Google Apps Script (GAS) でTwitterへ投稿するだけの機能を実装してみる](https://qiita.com/akkey2475/items/ad190a507b4a7b7dc17c#twitter%E3%82%A2%E3%83%97%E3%83%AA%E3%81%AE%E8%AA%8D%E8%A8%BC%E3%82%92%E8%A1%8C%E3%81%86)

※`authorize()`実行時にエラーが出力された場合、V8ランタイムが有効になっている可能性があるため、
GASスクリプトエディタ→ツールバーの「実行」→「Chrome V8を搭載した新しいApps Scriptランタイムを無効にする」で無効にしてから実行します。

上記のスクリプトを簡単に説明します。`getMyFavorites()`を実行すると「いいね！」した最新の100ツイートを取得して、各ツイートに対して別ページへのリンクが含まれているかを判断します。リンクが含まれている場合、`SearchUrl()`を呼び出して既にリンクがSpreadsheetに保存されているかを判断します。Spreadsheetに保存されていなければそのツイート情報を追記します。
~~`extractUrl()`は試行錯誤的にURLを抽出している感がすごいので、JavaScriptの学習をする気になったらきれいにしたいです。~~

```javascript

var favTweetsJson = service.fetch("https://api.twitter.com/1.1/favorites/list.json?count=100");
```
このメソッドの引数を変更することで様々なデータの取得などが可能です。
　[「いいね！」したツイートを取得するAPI](https://developer.twitter.com/en/docs/tweets/post-and-engage/api-reference/get-favorites-list)
　[API一覧](https://developer.twitter.com/en/docs/api-reference-index)

## SpreadsheetからSlackに投稿
次に、GASでSpreadsheetに追記された分のツイートに含まれるURLをSlack Incoming Webhookに渡します。
`*****Webhook-URL*****`は自分で設定したURLに書き換えます。
この機能を実装したのが以下のスクリプトです。

```javascript:articles_notification.gs

// Spreadsheetに行が追加されていれば、その行のURLをSlackに通知
function postSheetChange(){
  var notifySheet = SpreadsheetApp.getActiveSpreadsheet();
  var activeSheet = SpreadsheetApp.getActiveSheet();

  var lastRow = activeSheet.getLastRow();  // 現在のsheetの最終行番号
  var oldLastRow = activeSheet.getRange("E1").getValue(); // 前回実行時のsheetの最終行番号

  if ((lastRow > 0) && (lastRow !== oldLastRow)){
    // 複数行追加されていれば、追加分を全て通知
    for (var i = oldLastRow + 1; i <= lastRow; i++){
      var rowNum = parseInt(i);
      var url = activeSheet.getRange("C" + rowNum).getValue();
      postMessage(url);
    }
    activeSheet.getRange("E1").setValue(lastRow);
  }
}

/**
 * Slackに通知する際の設定
 * @param {string} url URL
 */
function postMessage(url){
  var options = {
    'method': 'post',
    'headers': {'Content-type': 'application/json'},
    'payload' : JSON.stringify({
      'text': url,
      'unfurl_links': true, // URL先のページを展開
    })
  };
  UrlFetchApp.fetch("https://hooks.slack.com/services/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", options);
 }
```

上記のスクリプトを簡単に説明します。`postSheetChange()`を実行すると、前回実行時の最終行番号と今回実行時の最終行番号を比較して追記されたかを判断します。追記されていれば、その分だけ`postMessage(url)`を呼び出してURLをIncoming Webhookを介してSlackに投稿します。

余談ですが、SlackではURLを投稿するとリンク先のページが展開されて閲覧性に優れていると感じていました。しかし、Incoming WebhookでURLを投稿すると展開されず困っていました。調べてみると、どうやら`'unfurl_links'`オプションを有効にする必要があるようでした。
　[SlackのIncomming WebhookでURLが展開されない問題を解決する](https://funet.work/blog/146)

# スクリプトを定期実行する
GASでは、スクリプトを自動で実行するようにトリガーを設定することが出来ます。トリガーとは、「ある条件を満たしたときに、あるスクリプトを実行する」という命令のことです。つまり、1度トリガーを設定してしまえば、その後はトリガーの条件を満たす度に対象のスクリプトを自動で実行してくれるようになります。
トリガーの概要とその設定方法は、以下の記事が分かりやすいです。
[【GAS】トリガーとは！トリガーの種類と使い方を解説](https://takakisan.com/gas-trigger-introduction/)

今回は、`getMyFavorites関数`と`postSheetChange関数`にトリガーを設定します。
私は以下のような設定にしていますが、実行間隔は自由で大丈夫です。

`getMyFavorites関数`のトリガー設定
<img src="https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/642820/c16e2476-7d8a-64ee-032f-8e3a74f7aa1e.png" width=100%>

`postSheetChange関数`のトリガー設定
<img src="https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/642820/0309ebcd-ea73-f7d0-cc01-8c828252be10.png" width=100%>
`postSheetChange関数`はSpreadsheetに行が追加された時に呼び出されるように設定したかったのですが、GASを用いてSpreadsheetに書き込んだ場合はトリガーが反応しない（？）ため時間主導型に設定しました。

# 実装結果
最後に、ここまでの手順に従って実装した場合にSpreadsheetに保存されるデータとSlackに投稿されるURLの例を示します。

まず、`getMyFavorites関数`がトリガーで呼び出されるとSpreadsheetに「いいね！」した別ページへのリンクを含むツイートの情報が保存されます。
![Spreadsheet_first.PNG](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/642820/86dbac7f-dac7-65d5-19c7-66f0b1f7dbd9.png)

次に、`postSheetChange関数`がトリガーで呼び出されるとSpreadsheetの`E1`を参照して、前回実行時の最終行と今回実行時の最終行の差分だけ`C列`の値（URL）をSlackに投稿します。
![Slack.PNG](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/642820/a30c68a1-b558-92a7-4078-374830ec94bc.png)
その後、Spreadsheetの`E1`には最終行の値が保存されます。
![Spreadsheet.PNG](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/642820/fff8676c-156d-1596-abba-2df45e538a00.png)

次のトリガー実行時には、新たに「いいね！」したリンクを含むツイートだけをSlackに投稿して最終行番号を更新します。

# 参考
本記事で紹介した手法は主に以下2つの記事から着想を得ました。

[GASで自分のツイートを取得してスプレッドシートに記録するやつ](https://crieit.net/posts/GAS)
[GASを使って、スプレッドシート更新時にSlack通知を飛ばしてくれるbotを作ってみた](https://qiita.com/matsukazu1112/items/d47e81d4c4d08d2147d3)
