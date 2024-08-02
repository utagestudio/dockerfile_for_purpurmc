# Minecraft MOD Server Setup Guide
- This repository provides a guide to easily set up a Minecraft MOD server (Purpur server) using Docker and Docker Compose.
  - このリポジトリでは、DockerとDocker Composeを使用して簡単にMinecraft MODサーバー（Purpurサーバー）を立ち上げる方法を説明します。

## Requirements / 必要条件
- Docker
- Docker compose

## Setup Instructions / セットアップ手順
### 1. Build the Docker Image / イメージをビルド

```bash
$ docker-compose build
```

### 2. Obtain Configuration Files / 設定ファイルを取得
- Run the following command to get the configuration files in the ./setup directory:
  - 次のコマンドで./setupディレクトリに設定ファイルを取得します。

```bash
$ docker-compose run --rm purpur init
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

## Stop the Server / サーバーの停止

```bash
$ docker-compose stop
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


## Remove Containers and Network / コンテナとネットワークの削除

```bash
$ docker-compose down
```

## Shell Access / Shell アクセス
### If the server is running / サーバーが稼働中の場合

```bash
$ docker-compose exec -it purpur /bin/bash
```

### If the server is stopped / サーバーが停止している場合

```bash
$ docker-compose run --rm purpur /bin/bash
```

## Notes / 注意点
- After changing the server configuration files, a restart is required.
  - サーバーの設定ファイルを変更した後、再起動が必要です。
- It is recommended to keep Docker and Docker Compose updated to the latest versions.
  - DockerとDocker Composeのバージョンを最新に保つことをお勧めします。

---
- That's it! Enjoy your Minecraft gameplay!
  - 以上でセットアップは完了です。快適なMinecraftプレイをお楽しみください！