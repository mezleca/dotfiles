#!/usr/bin/env python3

import argparse
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

# adb / device hardcoded stuff
IP_DEFAULT = "192.168.1.105:40801"
STORAGE_ROOT = "/sdcard/Download"

# scrcpy config
SCRCPY_VIDEO_CODEC = "h265"
SCRCPY_MAX_SIZE = 1920
SCRCPY_MAX_FPS = 60

# navigation config
UI_DUMP_REMOTE_PATH = "/sdcard/window_dump.xml"
UI_DUMP_LOCAL_PATH = "/tmp/window_dump.xml"
LONGPRESS_DURATION_MS = 800
SWIPE_DURATION_MS = 300
SCREEN_WIDTH_FALLBACK = 1080
SCREEN_HEIGHT_FALLBACK = 2195

NAVIGATE_HELP = """
available commands:
  dump              list interactable elements on screen (tap/longpress targets)
  raw               list all elements, including non-interactable ones
  tap <n>           tap element number n from last dump
  longpress <n>     long press element number n from last dump
  type <text>       type text into the currently focused field
  home              press home button
  back              press back button
  open <package>    launch an app by package name
  swipe up|down     scroll the screen
  help              show this message
  exit              leave the shell
"""

# adb device

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

def run_adb(serial, *args):
    cmd = ["adb", "-s", serial] + list(args)
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"adb error: {result.stderr.strip()}", file=sys.stderr)

    return result.stdout

# file transfer

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

# scrcpy screen mirroring

def is_scrcpy_running(serial):
    if shutil.which("pgrep") is None:
        return False

    result = subprocess.run(["pgrep", "-af", "scrcpy"], capture_output=True, text=True)
    
    for line in result.stdout.splitlines():
        if serial in line:
            return True

    return False

def start_scrcpy(serial, blocking):
    args = [
        "scrcpy",
        "-s", serial,
        f"--video-codec={SCRCPY_VIDEO_CODEC}",
        f"-m{SCRCPY_MAX_SIZE}",
        "--no-audio",
        f"--max-fps={SCRCPY_MAX_FPS}",
        "-K",
    ]

    if blocking:
        subprocess.run(args)
        return

    subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def run_screen(serial, navigate):
    already_running = is_scrcpy_running(serial)

    if already_running:
        print("scrcpy already running for this device, reusing it", file=sys.stderr)
    else:
        start_scrcpy(serial, blocking=not navigate)

    if navigate:
        run_navigate_shell(serial)

# navigation (uiautomator dump + adb input)

def build_element_label(node):
    text = node.get("text", "").strip()
    desc = node.get("content-desc", "").strip()
    resource_id = node.get("resource-id", "")

    label = text or desc or resource_id.split("/")[-1] or "(no text)"
    tags = []
    
    if node.get("password") == "true":
        tags.append("password")

    if node.get("checkable") == "true":
        tags.append("checked" if node.get("checked") == "true" else "unchecked")

    if node.get("scrollable") == "true":
        tags.append("scrollable")

    if not tags:
        return label

    return f"{label} [{', '.join(tags)}]"


def ui_dump(serial, session_state):
    run_adb(serial, "shell", "uiautomator", "dump", UI_DUMP_REMOTE_PATH)
    run_adb(serial, "pull", UI_DUMP_REMOTE_PATH, UI_DUMP_LOCAL_PATH)

    tree = ET.parse(UI_DUMP_LOCAL_PATH)
    root = tree.getroot()

    elements = []
    for node in root.iter("node"):
        is_clickable = node.get("clickable") == "true"
        is_long_clickable = node.get("long-clickable") == "true"

        if not is_clickable and not is_long_clickable:
            continue

        bounds = node.get("bounds", "")
        match = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
        
        if not match:
            continue

        x1, y1, x2, y2 = map(int, match.groups())
        center_x = (x1 + x2) // 2
        center_y = (y1 + y2) // 2

        elements.append({
            "label": build_element_label(node),
            "x": center_x,
            "y": center_y,
            "clickable": is_clickable,
            "long_clickable": is_long_clickable,
        })

    session_state["elements"] = elements

    if not elements:
        print("no interactable elements found")
        return

    print(f"\n{len(elements)} interactable elements:\n")
    
    for index, element in enumerate(elements):
        actions = [] 
        
        if element["clickable"]:
            actions.append("tap")

        if element["long_clickable"]:
            actions.append("longpress")

        print(f"  [{index}] {element['label']!r} @ ({element['x']}, {element['y']}) ({'/'.join(actions)})")

def ui_raw(serial):
    run_adb(serial, "shell", "uiautomator", "dump", UI_DUMP_REMOTE_PATH)
    run_adb(serial, "pull", UI_DUMP_REMOTE_PATH, UI_DUMP_LOCAL_PATH)

    tree = ET.parse(UI_DUMP_LOCAL_PATH)
    root = tree.getroot()

    print(f"\n{'idx':<4} {'class':<28} {'resource-id':<40} {'desc':<20} {'flags':<12} bounds")
    
    for index, node in enumerate(root.iter("node")):
        class_name = node.get("class", "").split(".")[-1]
        resource_id = node.get("resource-id", "").split("/")[-1]
        desc = node.get("content-desc", "")
        bounds = node.get("bounds", "")
        flags = []
        
        if node.get("clickable") == "true":
            flags.append("tap")

        if node.get("long-clickable") == "true":
            flags.append("long")

        if node.get("password") == "true":
            flags.append("pwd")

        if node.get("scrollable") == "true":
            flags.append("scroll")

        flags_str = ",".join(flags)
        print(f"{index:<4} {class_name:<27} {resource_id:<40} {desc:<20} {flags_str:<12} {bounds}")

    print("\n(flags: tap=clickable, long=long-clickable, pwd=password field, scroll=scrollable)")

def ui_tap(serial, session_state, index):
    elements = session_state["elements"]
    
    if index < 0 or index >= len(elements):
        print("invalid index, run dump first")
        return

    element = elements[index]
    
    if not element["clickable"]:
        print("this element only supports longpress")
        return

    run_adb(serial, "shell", "input", "tap", str(element["x"]), str(element["y"]))

def ui_longpress(serial, session_state, index):
    elements = session_state["elements"]
    
    if index < 0 or index >= len(elements):
        print("invalid index, run dump first")
        return

    element = elements[index]
    
    if not element["long_clickable"]:
        print("this element only supports tap")
        return

    run_adb(
        serial, "shell", "input", "swipe",
        str(element["x"]), str(element["y"]),
        str(element["x"]), str(element["y"]),
        str(LONGPRESS_DURATION_MS),
    )

def ui_home(serial):
    run_adb(serial, "shell", "input", "keyevent", "KEYCODE_HOME")

def ui_back(serial):
    run_adb(serial, "shell", "input", "keyevent", "KEYCODE_BACK")

def ui_open(serial, package_name):
    run_adb(serial, "shell", "monkey", "-p", package_name, "-c", "android.intent.category.LAUNCHER", "1")

def ui_swipe(serial, direction):
    center_x = SCREEN_WIDTH_FALLBACK // 2

    if direction == "up":
        start_y = int(SCREEN_HEIGHT_FALLBACK * 0.7)
        end_y = int(SCREEN_HEIGHT_FALLBACK * 0.3)
    elif direction == "down":
        start_y = int(SCREEN_HEIGHT_FALLBACK * 0.3)
        end_y = int(SCREEN_HEIGHT_FALLBACK * 0.7)
    else:
        print("use 'up' or 'down'")
        return

    run_adb(serial, "shell", "input", "swipe", str(center_x), str(start_y), str(center_x), str(end_y), str(SWIPE_DURATION_MS))


def ui_type(serial, text):
    escaped_text = text.replace(" ", "%s")
    run_adb(serial, "shell", "input", "text", escaped_text)

def run_navigate_shell(serial):
    session_state = {"elements": []}

    print(f"connected to {serial}, type 'help' for commands")

    while True:
        try:
            raw_line = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break

        if not raw_line:
            continue

        parts = raw_line.split()
        command = parts[0].lower()
        args = parts[1:]

        if command in ("exit", "quit"):
            break

        if command == "help":
            print(NAVIGATE_HELP)
            continue

        if command == "dump":
            ui_dump(serial, session_state)
            continue

        if command == "raw":
            ui_raw(serial)
            continue

        if command == "tap":
            if not args:
                print("usage: tap <n>")
                continue

            try:
                index = int(args[0])
            except ValueError:
                print("n must be a number")
                continue

            ui_tap(serial, session_state, index)
            continue

        if command == "longpress":
            if not args:
                print("usage: longpress <n>")
                continue

            try:
                index = int(args[0])
            except ValueError:
                print("n must be a number")
                continue

            ui_longpress(serial, session_state, index)
            continue

        if command == "home":
            ui_home(serial)
            continue

        if command == "back":
            ui_back(serial)
            continue

        if command == "open":
            if not args:
                print("usage: open <package>")
                continue

            ui_open(serial, args[0])
            continue

        if command == "swipe":
            direction = args[0] if args else "up"
            ui_swipe(serial, direction)
            continue

        if command == "type":
            if not args:
                print("usage: type <text>")
                continue

            ui_type(serial, " ".join(args))
            continue

        print(f"unknown command: {command}, type 'help' for a list")

def parse_args():
    parser = argparse.ArgumentParser(prog="android_tools.py")
    parser.add_argument("command", choices=["screen", "copy"])
    parser.add_argument("--ip", nargs="?", const=IP_DEFAULT, default=None)
    parser.add_argument("--file")
    parser.add_argument("--dest")
    parser.add_argument("--navigate", action="store_true")
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
            run_screen(serial, args.navigate)
            return 0

        return run_copy(serial, args.file, args.dest)
    finally:
        if connected_ip:
            adb_disconnect_ip(connected_ip)

if __name__ == "__main__":
    sys.exit(main())
