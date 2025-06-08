# related: https://qiita.com/somakai_sumasi/items/6dc76c5eaabe53c8118e

import os
import re
import time
import signal
import sys
import threading


from watchdog.observers.polling import PollingObserver
from watchdog.events import FileSystemEventHandler
from pynotificator import DiscordNotification

WEBHOOK_URL = os.environ['WEBHOOK_URL']
TARGET_DIR = "/opt/minecraft/logs/" #監視対象のフォルダ
TARGET_FILE = "latest.log"

MESSAGE_PATTERNS = [
    (": (.*) joined the game", "{0} が参加しました"),
    (": (.*) left the game", "{0} が退出しました"),
    (": .* For help, type \"help\"", "サーバーが起動しました"),
    (": All RegionFile I/O tasks to complete", "サーバーが停止しました"),
    # イベントを追加したい場合はここに追加する
]

# Discordに送るメッセージを生成する
def message_creation(text: str):
    for pattern, message_format in MESSAGE_PATTERNS:
        match = re.search(pattern, text)
        if match:
            return message_format.format(*match.groups())
    return None


class MinecraftLogMonitor:
    def __init__(self, target_dir, target_file, webhook_url):
        self.target_dir = target_dir
        self.target_file = target_file
        self.webhook_url = webhook_url
        self.log_position = 0
        self.server_stopped = False

    def send_message(self, message: str) -> None:
        dn = DiscordNotification(message, self.webhook_url)
        dn.notify()

    def get_log(self, filepath: str):
        with open(filepath, "r", errors="ignore") as f:
            f.seek(self.log_position)
            logs = f.readlines()
            self.log_position = f.tell()

        for log in logs:
            text = message_creation(log)
            if text:
                self.send_message(text)
                self.check_server_stop(text)

    def check_server_stop (self, text:str):
        # サーバー停止を検知
        if "サーバーが停止しました" in text:
            self.server_stopped = True
            # 少し待ってからlog_watcherを終了
            threading.Timer(1.0, self.graceful_shutdown).start()

    @staticmethod
    def graceful_shutdown():
        """サーバー停止後の適切な終了処理"""
        print("Minecraftサーバーが停止しました。log_watcherを終了します。")
        observer.stop()
        observer.join()
        sys.exit(0)


class ChangeHandler(FileSystemEventHandler):
    def __init__(self, monitor: MinecraftLogMonitor):
        self.monitor = monitor

    def on_modified(self, event):
        filepath = event.src_path
        if (
            os.path.isfile(filepath)
            and os.path.basename(filepath) == self.monitor.target_file
        ):
            self.monitor.get_log(filepath)


def signal_handler(signum, frame):
    observer.stop()
    observer.join()
    sys.exit(0)



if __name__ == "__main__":
    monitor = MinecraftLogMonitor(TARGET_DIR, TARGET_FILE, WEBHOOK_URL)
    event_handler = ChangeHandler(monitor)

    observer = PollingObserver()
    observer.schedule(event_handler, monitor.target_dir, recursive=False)
    observer.start()

    # シグナルハンドラを設定
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    while True:
        time.sleep(1)