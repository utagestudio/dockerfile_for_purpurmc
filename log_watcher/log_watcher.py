# related: https://qiita.com/somakai_sumasi/items/6dc76c5eaabe53c8118e
#
# Watch the Minecraft server log and send notifications to Discord.
# Uses only the Python standard library.

import json
import os
import re
import signal
import sys
import time
import urllib.error
import urllib.request

WEBHOOK_URL = os.environ.get('WEBHOOK_URL', '')
LOG_FILE = "/opt/minecraft/logs/latest.log"  # 監視対象のファイル
POLL_INTERVAL = 1  # seconds

# Only match lines written by the server itself ([Server thread/INFO]), so that
# chat messages cannot trigger notifications. Join/leave messages are logged
# with a "System chat: " prefix. Player names are limited to valid Minecraft
# names (a leading "." is used by Bedrock players via Floodgate).
SERVER_LINE = r"\[Server thread/INFO\]: (?:System chat: )?"
PLAYER_NAME = r"(\.?[A-Za-z0-9_]{1,16})"
MESSAGE_PATTERNS = [
    (SERVER_LINE + PLAYER_NAME + r" joined the game$", "{0} が参加しました"),
    (SERVER_LINE + PLAYER_NAME + r" left the game$", "{0} が退出しました"),
    (SERVER_LINE + r"Done \(.*\)! For help, type \"help\"$", "サーバーが起動しました"),
    (SERVER_LINE + r"All RegionFile I/O tasks to complete$", "サーバーが停止しました"),
    # イベントを追加したい場合はここに追加する
]


def log(message: str) -> None:
    print(message, flush=True)


# Discordに送るメッセージを生成する
def message_creation(text: str):
    for pattern, message_format in MESSAGE_PATTERNS:
        match = re.search(pattern, text)
        if match:
            return message_format.format(*match.groups())
    return None


def send_message(message: str) -> None:
    if not WEBHOOK_URL:
        log(f"WEBHOOK_URL is not set. Skipped: {message}")
        return

    request = urllib.request.Request(
        WEBHOOK_URL,
        data=json.dumps({"content": message}).encode(),
        headers={
            "Content-Type": "application/json",
            # Discord rejects the default Python-urllib User-Agent.
            "User-Agent": "minecraft-log-watcher",
        },
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=10):
                log(f"Sent: {message}")
                return
        except urllib.error.HTTPError as e:
            if e.code == 429:  # rate limited
                retry_after = float(e.headers.get("Retry-After", "1"))
                time.sleep(retry_after)
                continue
            log(f"Failed to send ({e.code}): {message}")
            return
        except (urllib.error.URLError, TimeoutError) as e:
            log(f"Failed to send ({e}): {message}")
            time.sleep(2)
    log(f"Gave up sending: {message}")


class LogFollower:
    """Follow a log file like `tail -F`, handling rotation and truncation."""

    def __init__(self, path: str):
        self.path = path
        self.inode = None
        self.position = 0

    def start_at_end(self) -> None:
        # Skip what was logged before this process started, so that past
        # joins/leaves are not sent again after a restart.
        try:
            stat = os.stat(self.path)
            self.inode = stat.st_ino
            self.position = stat.st_size
        except FileNotFoundError:
            pass

    def read_new_lines(self) -> list:
        try:
            stat = os.stat(self.path)
        except FileNotFoundError:
            return []

        # The server creates a new latest.log on each start. Read the new file
        # from the beginning so that the startup message is not missed.
        if stat.st_ino != self.inode or stat.st_size < self.position:
            self.inode = stat.st_ino
            self.position = 0

        if stat.st_size == self.position:
            return []

        with open(self.path, "rb") as f:
            f.seek(self.position)
            data = f.read()
        # Leave an incomplete last line for the next read.
        end = data.rfind(b"\n")
        if end == -1:
            return []
        self.position += end + 1
        return [line.decode(errors="ignore").rstrip("\r")
                for line in data[:end].split(b"\n")]


stopping = False


def handle_signal(signum, frame):
    # Do not exit right away: `docker compose stop` stops this container just
    # after the server, so read the log once more to send the stop message.
    global stopping
    stopping = True


def main():
    # As PID 1 in the container, SIGTERM is ignored unless handled.
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    if not WEBHOOK_URL:
        log("WEBHOOK_URL is not set. Notifications are only printed.")

    follower = LogFollower(LOG_FILE)
    follower.start_at_end()
    log(f"Watching {LOG_FILE}")

    while True:
        for line in follower.read_new_lines():
            text = message_creation(line)
            if text:
                send_message(text)
        if stopping:
            log("log_watcher stopped")
            sys.exit(0)
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
