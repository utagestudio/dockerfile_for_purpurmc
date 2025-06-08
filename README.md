# Minecraft MOD Server Setup Guide
- This repository provides a guide to easily set up a Minecraft MOD server (Purpur server) using Docker and Docker Compose.
  - このリポジトリでは、DockerとDocker Composeを使用して簡単にMinecraft MODサーバー（Purpurサーバー）を立ち上げる方法を説明します。

## Limitations / 制限事項
- The use of this Docker image and related components is at your own risk.
  - この Docker Image 等の使用は自己責任です
 

## Requirements / 必要条件
- Docker
- Docker compose

## Setup Instructions / セットアップ手順
### 0. Fill in Environment Information / 環境情報を記入
1. Change the file name of `.env.sample` to `.env`.
   - `.env.sample` のファイル名を `.env` に変更する
2. Open the `.env` file and modify each item.
   - `.env` を開き、各項目を書き換えてください。

| Item Name / 項目名 | Description / 内容                                                                                                                                                                                                                                                                             |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| VERSION         | The version of the Minecraft server to install.<br/>インストールするマインクラフトサーバーのバージョン                                                                                                                                                                                                                |
| TZ              | Timezone ID. Probably unused.<br/>タイムゾーンID。未使用な気がする。<br/>https://www.hulft.com/help/ja-jp/WebFT-V3/COM-ADM/Content/WEBFT_ADM_COM/TimeZone/timezonelist.htm                                                                                                                                   |
| JAVA_MEMORY_MAX | The maximum memory size the Minecraft server can use. Make sure it does not exceed the server machine's memory size. Deducting about 4GB for system usage is recommended.<br/>マイクラサーバーが使用していいメモリサイズの最大値。マイクラサーバーが実行されているサーバーマシンのメモリサイズを超えないように注意。サーバーマシン自体もメモリ使えるように、搭載メモリ-4GBくらいがいいんじゃないかな。 |
| JAVA_MEMORY_MIN | The minimum memory size reserved for the Minecraft server. At least 2GB is recommended. It is generally advised to set the same value as `JAVA_MEMORY_MAX`. <br/>マイクラサーバーのために確保するメモリサイズの最小値。最低でも2GBは必要だと思う。一般的に JAVA_MEMORY_MAX と同じにすると良いと言われている。                                            |
| EULA            | Agreement to the Minecraft server's usage terms. If you cannot agree, the server cannot be used.<br/> To agree, change it to `true`.<br/>マイクラサーバーの利用規約へ同意するかどうか。同意できないなら使用できない。<br/>同意する場合は `true` に書き換える。<br/> https://www.minecraft.net/ja-jp/eula                                         |

3.　If you want to automatically start this Docker Image when the server starts up, please set `restart:always` to the `purpur` instance in `docker-compose.yml`. 
  - もしサーバー起動したら自動でこの Docker Image を起動したい場合は、 `docker-compose.yml` の `purpur` インスタンスに `restart:always` を設定してください。

### 1. Build the Docker Image / イメージをビルド

```bash
$ docker-compose build
```
もしくは
```bash
$ make build
```

### 2. Obtain Configuration Files / 設定ファイルを取得
- Run the following command to get the configuration files in the ./setup directory:
  - 次のコマンドで./setupディレクトリに設定ファイルを取得します。

```bash
$ docker-compose run --rm purpur init
```
もしくは
```bash
$ make init
```

### 3. Edit Configuration Files / 設定ファイルを編集
- Edit the obtained configuration files (server.properties, spigot.yml, etc.) as needed.
  - 取得した設定ファイル（server.properties, spigot.ymlなど）を編集します。

### 4. Start the Purpur Server / サーバーを起動
- Start the Purpur server in detached mode:
  - 以下のコマンドでPurpurサーバーをデタッチモードで起動します。

```bash
$ docker-compose up -d
```
もしくは
```bash
$ make start
```

## Stop the Server / サーバーの停止

```bash
$ docker-compose stop
```
もしくは
```bash
$ make stop
```

- Please wait a few seconds for the server to stop completely.
  - 停止には数秒かかることがあります。

## Backup / バックアップ
### If the server is running / サーバーが稼働中の場合
```bash
$ docker-compose exec -it purpur /entrypoint.sh backup
```

### If the server is stopped / サーバーが停止している場合
```bash
$ docker-compose run --rm purpur backup
```
もしくは
```bash
$ make backup
```

## Update / アップデート
- First, change the value of `VERSION` specified in the `.env` file.
  - まず、.env に記載の `VERSION` の値を変更してください。
### If the server is running / サーバーが稼働中の場合
```bash
$ docker-compose exec -it purpur /entrypoint.sh update
```

### If the server is stopped / サーバーが停止している場合
```bash
$ docker-compose run --rm purpur update
```
もしくは
```bash
$ make update
```


## Remove Containers and Network / コンテナとネットワークの削除

```bash
$ docker-compose down
```
もしくは
```bash
$ make remove
```

- `make remove-all` を実行すると、保存されているデータも削除されます。

## Shell Access / Shell アクセス
### If the server is running / サーバーが稼働中の場合

```bash
$ docker-compose exec -it purpur /bin/bash
```
もしくは
```bash
$ make bash
```

### If the server is stopped / サーバーが停止している場合

```bash
$ docker-compose run --rm purpur /bin/bash
```
もしくは
```bash
$ make bash-run
```

## Notes / 注意点
- After changing the server configuration files, a restart is required.
  - サーバーの設定ファイルを変更した後、再起動が必要です。
- It is recommended to keep Docker and Docker Compose updated to the latest versions.
  - DockerとDocker Composeのバージョンを最新に保つことをお勧めします。

---
- That's it! Enjoy your Minecraft gameplay!
  - 以上でセットアップは完了です。快適なMinecraftプレイをお楽しみください！