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
| VERSION         | The version of the Minecraft server to install first. Used only when no server jar is installed yet (`make init` or the first start); after that, change the version with `make update`.<br/>最初にインストールするマインクラフトサーバーのバージョン。サーバーの jar がまだない場合（ `make init` や初回の起動）だけ使われます。その後のバージョンの変更は `make update` で行います。 |
| TZ              | Timezone ID. Used for log timestamps and backup file names.<br/>タイムゾーンID。ログの時刻やバックアップのファイル名に使われます。<br/>https://www.hulft.com/help/ja-jp/WebFT-V3/COM-ADM/Content/WEBFT_ADM_COM/TimeZone/timezonelist.htm                                                                                                                                   |
| JAVA_MEMORY_MAX | The maximum memory size the Minecraft server can use. Make sure it does not exceed the server machine's memory size. Deducting about 4GB for system usage is recommended.<br/>マイクラサーバーが使用していいメモリサイズの最大値。マイクラサーバーが実行されているサーバーマシンのメモリサイズを超えないように注意。サーバーマシン自体もメモリ使えるように、搭載メモリ-4GBくらいがいいんじゃないかな。 |
| JAVA_MEMORY_MIN | The minimum memory size reserved for the Minecraft server. At least 2GB is recommended. It is generally advised to set the same value as `JAVA_MEMORY_MAX`. <br/>マイクラサーバーのために確保するメモリサイズの最小値。最低でも2GBは必要だと思う。一般的に JAVA_MEMORY_MAX と同じにすると良いと言われている。                                            |
| EULA            | Agreement to the Minecraft server's usage terms. If you cannot agree, the server cannot be used.<br/> To agree, change it to `true`.<br/>マイクラサーバーの利用規約へ同意するかどうか。同意できないなら使用できない。<br/>同意する場合は `true` に書き換える。<br/> https://www.minecraft.net/ja-jp/eula                                         |
| WEBHOOK_URL     | Discord webhook URL. `log_watcher` posts server start/stop and player join/leave to it. Optional: if empty, messages are only printed to the `log_watcher` log.<br/>Discord の Webhook URL。 `log_watcher` がサーバーの起動・停止とプレイヤーの参加・退出を通知します。省略可能で、空の場合は `log_watcher` のログに出力するだけです。 |

3. If you want to start the containers automatically when the server machine starts up, copy `docker-compose.override.yml.sample` to `docker-compose.override.yml`. It sets `restart: always` on both `purpur` and `log_watcher`.
   - サーバーマシンの起動時にコンテナを自動で起動したい場合は、 `docker-compose.override.yml.sample` を `docker-compose.override.yml` にコピーしてください。 `purpur` と `log_watcher` の両方に `restart: always` が設定されます。
   - Use `always`, not `unless-stopped`. With `unless-stopped`, containers stopped by `docker compose stop` will not start again when the machine boots.
     - `unless-stopped` ではなく `always` を使ってください。 `unless-stopped` だと、 `docker compose stop` で止めたコンテナはマシンの起動時に起動しません。
   - Put other environment-specific settings in `docker-compose.override.yml` as well, instead of editing `docker-compose.yml`. This file is ignored by git, so `git pull` will not conflict.
     - その他の環境ごとの設定も、 `docker-compose.yml` を直接編集せず `docker-compose.override.yml` に書いてください。このファイルは git の管理対象外なので、 `git pull` で衝突しません。

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
$ docker-compose run --rm --no-deps purpur init
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

- Stopping waits until the server has finished saving the world (up to 120 seconds). It usually takes a few seconds, but can take longer on a large world.
  - 停止時は、サーバーがワールドの保存を終えるまで待ちます（最大120秒）。通常は数秒ですが、ワールドが大きいと時間がかかることがあります。
- Always stop the server with `make stop` (or `docker compose stop`). If you run `stop` from the in-game or server console, the container exits, and with `restart: always` it starts again automatically.
  - サーバーは必ず `make stop` （または `docker compose stop` ）で止めてください。ゲーム内やサーバーのコンソールで `stop` を実行するとコンテナが終了し、 `restart: always` を設定している場合は自動で再起動します。
- The container also exits when the server process crashes, so `restart: always` restarts it automatically.
  - サーバーのプロセスがクラッシュした場合もコンテナが終了するので、 `restart: always` によって自動で再起動します。

## Backup / バックアップ
```bash
$ make backup
```

- Works whether the server is running or stopped. While the server is running, auto-save is turned off (`save-off`), the world is flushed to disk (`save-all flush`), and auto-save is turned back on (`save-on`) after the archive is created, so the backup is consistent.
  - サーバーが稼働中でも停止中でも実行できます。稼働中の場合は、自動保存を止め（`save-off`）、ワールドをディスクに書き出し（`save-all flush`）、アーカイブを作ったあとで自動保存を再開（`save-on`）するので、整合性のとれたバックアップになります。
- Without `make`:
  - `make` を使わない場合:

```bash
# If the server is running / サーバーが稼働中の場合
$ docker-compose exec purpur /entrypoint.sh backup
# If the server is stopped / サーバーが停止している場合
$ docker-compose run --rm --no-deps purpur backup
```

- Backups are saved as `./backup/worlds_backup_YYYYmmdd_HHMMSS.tar.zst` (zstd-compressed tar). The 5 newest are kept.
  - バックアップは `./backup/worlds_backup_YYYYmmdd_HHMMSS.tar.zst` （zstd で圧縮した tar）として保存され、新しいものから5つが残ります。
- To extract on your machine / 手元のマシンで展開するには:
  - Linux / macOS: `tar --zstd -xf worlds_backup_xxx.tar.zst` (requires `zstd` / `zstd` が必要)
  - Windows: [7-Zip ZS](https://github.com/mcmilk/7-Zip-zstd) or `tar` in WSL / [7-Zip ZS](https://github.com/mcmilk/7-Zip-zstd) または WSL の `tar`
- A backup contains `world` (all dimensions, player data) and `plugins` (plugin data and settings). Server configuration files are kept in `./setup`.
  - バックアップには `world` （全ディメンションとプレイヤーデータ）と `plugins` （プラグインのデータと設定）が含まれます。サーバーの設定ファイルは `./setup` に保存されています。

## Restore / 復元
1. Copy the backup file you want to restore to a safe place first. `make backup` keeps only the 5 newest files, so making another backup may delete it.
   - 復元したいバックアップファイルを、先に別の場所へコピーしておいてください。 `make backup` は新しいものから5つしか残さないので、バックアップを取り直すと消えることがあります。
2. Stop the server, replace `world` and `plugins` with the ones in the backup, and start the server.
   - サーバーを止めて、 `world` と `plugins` をバックアップの中身に置き換えてから起動します。

```bash
$ make stop
$ docker-compose run --rm --no-deps purpur bash -c \
    'rm -rf world plugins && tar -xf /opt/backup/worlds_backup_YYYYmmdd_HHMMSS.tar.zst'
$ make start
```

- `tar -xf` detects the compression automatically, so it also works with old `.tar.gz` backups. Old `.tar.gz` backups contain only `world`; in that case, remove only `world` (`rm -rf world`).
  - `tar -xf` は圧縮形式を自動で判別するので、古い `.tar.gz` のバックアップも同じ手順で復元できます。古い `.tar.gz` には `world` しか入っていないので、その場合は `world` だけを削除してください（ `rm -rf world` ）。

## Update / アップデート
```bash
$ make update
```

- Stops the server, asks for the game version and build to install, and starts the server again. Press Enter at each prompt to update to the latest build of the current game version.
  - サーバーを止めて、インストールするゲームバージョンとビルドを選び、もう一度起動します。各項目で Enter を押すと、今のゲームバージョンの最新ビルドに更新します。

```
Current: 26.3 build 2648
Newest game version: 26.3
Available versions (newest 10): ... 26.1.2 26.2 26.3
Select version [26.3]:
Available builds of 26.3 (newest 10): ... 2650 2651 2652
Select build [2652 (latest)]:
Update 26.3 build 2648 -> 26.3 build 2652? [Y/n]:
```

- Run it from a terminal. It is interactive and fails without one.
  - 対話式なので、端末から実行してください。端末がない環境（cron など）では失敗します。
- A backup is created before updating. The downloaded jar is verified with the checksum from the Purpur API, and the update is cancelled if this image's Java cannot run it.
  - 更新の前にバックアップを作成します。ダウンロードした jar は Purpur の API のチェックサムで検証し、このイメージの Java で動かない場合は更新を中止します。
- Choosing an older game version asks you to type `downgrade`. A world opened by a newer version may be broken by an older one, so restore a backup instead if possible. Older builds of the same game version can be chosen freely.
  - 今より古いゲームバージョンを選ぶと、 `downgrade` の入力を求めます。新しいバージョンで開いたワールドは、古いバージョンで開くと壊れることがあるので、できればバックアップから復元してください。同じゲームバージョンの古いビルドは、確認なしで選べます。
- When updating to a new game version, check that your plugins support it.
  - 新しいゲームバージョンに上げるときは、プラグインが対応しているか確認してください。
- The jar in use and the previous one are kept in the volume as `purpur-<version>-<build>.jar`. `purpur.jar` points to the one in use.
  - 使用中の jar と1つ前の jar は、ボリュームに `purpur-<バージョン>-<ビルド>.jar` として残ります。 `purpur.jar` は使用中の jar を指します。

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
$ docker-compose run --rm --no-deps purpur /bin/bash
```
もしくは
```bash
$ make bash-run
```

## Notes / 注意点
- After changing the server configuration files, a restart is required.
  - サーバーの設定ファイルを変更した後、再起動が必要です。
- Configuration files are synced between `./setup` and the server in both directions: from `./setup` on start, and back to `./setup` on stop. In both directions, a file is only overwritten when the copy source is newer, so edits made in `./setup` while the server is running are kept and applied on the next start.
  - 設定ファイルは `./setup` とサーバーの間で双方向に同期されます（起動時は `./setup` から、停止時は `./setup` へ）。どちらの方向も、コピー元のほうが新しい場合だけ上書きするので、稼働中に `./setup` で編集した内容は消えず、次の起動時に反映されます。
  - If you want to restore an older file into `./setup`, run `touch` on it so that it is treated as the newest.
    - 古いファイルを `./setup` に戻したい場合は、 `touch` で更新日時を新しくしてください。
- It is recommended to keep Docker and Docker Compose updated to the latest versions.
  - DockerとDocker Composeのバージョンを最新に保つことをお勧めします。

---
- That's it! Enjoy your Minecraft gameplay!
  - 以上でセットアップは完了です。快適なMinecraftプレイをお楽しみください！