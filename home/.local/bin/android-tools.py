#!/usr/bin/env python3

import argparse
import shutil
import subprocess
import sys

IP_DEFAULT = "192.168.1.105:35319"
STORAGE_ROOT = "/sdcard/Download"
SCRCPY_VIDEO_CODEC = "h265"
SCRCPY_MAX_SIZE = 1920
SCRCPY_MAX_FPS = 60

def adb_connect_ip(ip):
    print(f"attempting to connect to {ip}...", file=sys.stderr)
    subprocess.run(["adb", "connect", ip], capture_output=True)
    result = subprocess.run(["adb", "devices"], capture_output=True, text=True)
    return ip in result.stdout

def adb_disconnect_ip(ip):
    subprocess.run(["adb", "disconnect", ip], capture_output=True)

def adb_get_usb_serial():
    result = subprocess.run(["adb", "devices"], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == "device":
            return parts[0]

    return None

def resolve_target(use_ip, ip):
    if use_ip:
        if not adb_connect_ip(ip):
            print("connection failed", file=sys.stderr)
            return None

        return ip, ip

    serial = adb_get_usb_serial()
    if serial is None:
        print("no usb device found", file=sys.stderr)
        return None

    return serial, None

def pick_file_zenity():
    if shutil.which("zenity") is None:
        print("zenity not found, pass --file instead", file=sys.stderr)
        return None

    result = subprocess.run(
        ["zenity", "--file-selection", "--title=select file to push"],
        capture_output=True,
        text=True,
    )
    file_path = result.stdout.strip()
    if not file_path:
        return None

    return file_path

def run_screen(serial):
    subprocess.run([
        "scrcpy",
        "-s", serial,
        f"--video-codec={SCRCPY_VIDEO_CODEC}",
        f"-m{SCRCPY_MAX_SIZE}",
        "--no-audio",
        f"--max-fps={SCRCPY_MAX_FPS}",
        "-K",
    ])

def run_copy(serial, file_path, dest):
    if file_path is None:
        file_path = pick_file_zenity()

    if not file_path:
        print("no file selected", file=sys.stderr)
        return 1

    file_arg = shutil.os.path.expanduser(file_path)
    if not shutil.os.path.isfile(file_arg):
        print(f"file not found: {file_arg}", file=sys.stderr)
        return 1

    if not dest:
        dest = shutil.os.path.basename(file_arg)

    remote_path = f"{STORAGE_ROOT}/{dest}"
    result = subprocess.run(["adb", "-s", serial, "push", file_arg, remote_path])
    return result.returncode

def parse_args():
    parser = argparse.ArgumentParser(prog="android_tools.py")
    parser.add_argument("command", choices=["screen", "copy"])
    parser.add_argument("--ip", nargs="?", const=IP_DEFAULT, default=None)
    parser.add_argument("--file")
    parser.add_argument("--dest")
    return parser.parse_args()

def main():
    args = parse_args()
    use_ip = args.ip is not None
    ip = args.ip if use_ip else IP_DEFAULT

    target = resolve_target(use_ip, ip)
    if target is None:
        return 1

    serial, connected_ip = target

    try:
        if args.command == "screen":
            run_screen(serial)
            return 0

        return run_copy(serial, args.file, args.dest)
    finally:
        if connected_ip:
            adb_disconnect_ip(connected_ip)

if __name__ == "__main__":
    sys.exit(main())
