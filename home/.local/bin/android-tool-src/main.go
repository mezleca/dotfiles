package main

import (
	"bufio"
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

// adb / device hardcoded stuff
const ipDefault = "192.168.1.105:40801"
const storageRoot = "/sdcard/Download"

// scrcpy config
const scrcpyVideoCodec = "h265"
const scrcpyMaxSize = 1920
const scrcpyMaxFPS = 60

// navigation config
const uiDumpRemotePath = "/sdcard/window_dump.xml"
const uiDumpLocalPath = "/tmp/window_dump.xml"
const longpressDurationMs = 800
const swipeDurationMs = 300
const screenWidthFallback = 1080
const screenHeightFallback = 2195

const navigateHelp = `
available commands:
  dump              list interactable elements on screen (tap/longpress targets)
  raw               print the raw uiautomator dump xml (indented)
  tap <n>           tap element number n from last dump
  longpress <n>     long press element number n from last dump
  type <text>       type text into the currently focused field
  home              press home button
  back              press back button
  open <package>    launch an app by package name
  swipe up|down     scroll the screen
  help              show this message
  exit              leave the shell
`

var boundsPattern = regexp.MustCompile(`\[(\d+),(\d+)\]\[(\d+),(\d+)\]`)
var debugMode = false

const defaultTerminalWidth = 100
const minColumnWidth = 6

type uiNode struct {
	Attrs []xml.Attr `xml:",any,attr"`
	Nodes []uiNode   `xml:"node"`
}

func (n uiNode) attr(key string) string {
	for _, a := range n.Attrs {
		if a.Name.Local == key {
			return a.Value
		}
	}

	return ""
}

type element struct {
	label         string
	x             int
	y             int
	clickable     bool
	longClickable bool
}

type sessionState struct {
	elements []element
}

func terminalWidth() int {
	var ws struct {
		Row, Col, Xpixel, Ypixel uint16
	}

	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, os.Stdout.Fd(), syscall.TIOCGWINSZ, uintptr(unsafe.Pointer(&ws)))
	if errno != 0 || ws.Col == 0 {
		return defaultTerminalWidth
	}

	return int(ws.Col)
}

func truncate(s string, width int) string {
	runes := []rune(s)

	if len(runes) <= width {
		return s
	}

	if width <= 1 {
		return string(runes[:width])
	}

	return string(runes[:width-1]) + "…"
}

// adb device

func adbConnectIP(ip string) bool {
	fmt.Fprintf(os.Stderr, "attempting to connect to %s...\n", ip)
	exec.Command("adb", "connect", ip).Run()

	out, _ := exec.Command("adb", "devices").Output()
	return strings.Contains(string(out), ip)
}

func adbDisconnectIP(ip string) {
	exec.Command("adb", "disconnect", ip).Run()
}

func adbGetUSBSerial() string {
	out, _ := exec.Command("adb", "devices").Output()

	for _, line := range strings.Split(string(out), "\n") {
		parts := strings.Fields(line)
		if len(parts) == 2 && parts[1] == "device" {
			return parts[0]
		}
	}

	return ""
}

func resolveTarget(useIP bool, ip string) (serial string, connectedIP string, ok bool) {
	if useIP {
		if !adbConnectIP(ip) {
			fmt.Fprintln(os.Stderr, "connection failed")
			return "", "", false
		}

		return ip, ip, true
	}

	serial = adbGetUSBSerial()
	if serial == "" {
		fmt.Fprintln(os.Stderr, "no usb device found")
		return "", "", false
	}

	return serial, "", true
}

func runAdb(serial string, args ...string) string {
	cmdArgs := append([]string{"-s", serial}, args...)
	cmd := exec.Command("adb", cmdArgs...)

	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "adb error: %s\n", strings.TrimSpace(stderr.String()))
	}

	return stdout.String()
}

// file transfer

func pickFileZenity() string {
	if _, err := exec.LookPath("zenity"); err != nil {
		fmt.Fprintln(os.Stderr, "zenity not found, pass --file instead")
		return ""
	}

	out, _ := exec.Command("zenity", "--file-selection", "--title=select file to push").Output()
	return strings.TrimSpace(string(out))
}

func runCopy(serial, filePath, dest string) int {
	if filePath == "" {
		filePath = pickFileZenity()
	}

	if filePath == "" {
		fmt.Fprintln(os.Stderr, "no file selected")
		return 1
	}

	fileArg, err := expandUser(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "could not resolve path: %s\n", err)
		return 1
	}

	if info, err := os.Stat(fileArg); err != nil || info.IsDir() {
		fmt.Fprintf(os.Stderr, "file not found: %s\n", fileArg)
		return 1
	}

	if dest == "" {
		dest = filepath.Base(fileArg)
	}

	remotePath := fmt.Sprintf("%s/%s", storageRoot, dest)
	cmd := exec.Command("adb", "-s", serial, "push", fileArg, remotePath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode()
		}

		return 1
	}

	return 0
}

func expandUser(path string) (string, error) {
	if !strings.HasPrefix(path, "~") {
		return path, nil
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	return filepath.Join(home, strings.TrimPrefix(path, "~")), nil
}

// scrcpy screen mirroring

func isScrcpyRunning(serial string) bool {
	if _, err := exec.LookPath("pgrep"); err != nil {
		return false
	}

	out, _ := exec.Command("pgrep", "-af", "scrcpy").Output()

	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, serial) {
			return true
		}
	}

	return false
}

func startScrcpy(serial string, blocking bool) {
	args := []string{
		"-s", serial,
		fmt.Sprintf("--video-codec=%s", scrcpyVideoCodec),
		fmt.Sprintf("-m%d", scrcpyMaxSize),
		"--no-audio",
		fmt.Sprintf("--max-fps=%d", scrcpyMaxFPS),
		"-K",
	}

	cmd := exec.Command("scrcpy", args...)

	if blocking {
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Run()
		return
	}

	cmd.Start()
}

func runScreen(serial string, navigate bool) {
	if isScrcpyRunning(serial) {
		fmt.Fprintln(os.Stderr, "scrcpy already running for this device, reusing it")
	} else {
		startScrcpy(serial, !navigate)
	}

	if navigate {
		runNavigateShell(serial)
	}
}

// navigation (uiautomator dump + adb input)

func buildElementLabel(node uiNode) string {
	text := strings.TrimSpace(node.attr("text"))
	desc := strings.TrimSpace(node.attr("content-desc"))
	resourceID := node.attr("resource-id")

	label := text
	if label == "" {
		label = desc
	}
	if label == "" {
		parts := strings.Split(resourceID, "/")
		label = parts[len(parts)-1]
	}
	if label == "" {
		label = "(no text)"
	}

	var tags []string

	if node.attr("password") == "true" {
		tags = append(tags, "password")
	}

	if node.attr("checkable") == "true" {
		if node.attr("checked") == "true" {
			tags = append(tags, "checked")
		} else {
			tags = append(tags, "unchecked")
		}
	}

	if node.attr("scrollable") == "true" {
		tags = append(tags, "scrollable")
	}

	if len(tags) == 0 {
		return label
	}

	return fmt.Sprintf("%s [%s]", label, strings.Join(tags, ", "))
}

func walkNodes(node uiNode, visit func(uiNode)) {
	visit(node)

	for _, child := range node.Nodes {
		walkNodes(child, visit)
	}
}

func parseUIDump(path string) (uiNode, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return uiNode{}, err
	}

	var root uiNode
	if err := xml.Unmarshal(data, &root); err != nil {
		return uiNode{}, err
	}

	return root, nil
}

func debugStep(label string, fn func()) {
	if !debugMode {
		fn()
		return
	}

	start := time.Now()
	fn()
	fmt.Printf("[debug] %s: %s\n", label, time.Since(start))
}

func fetchUIDumpFile(serial string, compressed bool) {
	dumpArgs := []string{"shell", "uiautomator", "dump"}
	if compressed {
		dumpArgs = append(dumpArgs, "--compressed")
	}
	dumpArgs = append(dumpArgs, uiDumpRemotePath)

	debugStep("uiautomator dump", func() {
		runAdb(serial, dumpArgs...)
	})

	debugStep("adb pull", func() {
		runAdb(serial, "pull", uiDumpRemotePath, uiDumpLocalPath)
	})
}

func uiDump(serial string, state *sessionState) {
	fetchUIDumpFile(serial, true)

	var root uiNode
	var err error

	debugStep("xml parse", func() {
		root, err = parseUIDump(uiDumpLocalPath)
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to parse ui dump: %s\n", err)
		return
	}

	var elements []element

	walkNodes(root, func(node uiNode) {
		isClickable := node.attr("clickable") == "true"
		isLongClickable := node.attr("long-clickable") == "true"

		if !isClickable && !isLongClickable {
			return
		}

		match := boundsPattern.FindStringSubmatch(node.attr("bounds"))
		if match == nil {
			return
		}

		x1, _ := strconv.Atoi(match[1])
		y1, _ := strconv.Atoi(match[2])
		x2, _ := strconv.Atoi(match[3])
		y2, _ := strconv.Atoi(match[4])

		elements = append(elements, element{
			label:         buildElementLabel(node),
			x:             (x1 + x2) / 2,
			y:             (y1 + y2) / 2,
			clickable:     isClickable,
			longClickable: isLongClickable,
		})
	})

	state.elements = elements

	if len(elements) == 0 {
		fmt.Println("no interactable elements found")
		return
	}

	fmt.Printf("\n%d interactable elements:\n\n", len(elements))

	// budget the label column to whatever's left after the fixed-width parts of the line
	fixedWidth := len("  [999] \"\" @ (9999, 9999) (tap/longpress)")
	labelWidth := terminalWidth() - fixedWidth

	if labelWidth < minColumnWidth {
		labelWidth = minColumnWidth
	}

	for index, el := range elements {
		var actions []string

		if el.clickable {
			actions = append(actions, "tap")
		}

		if el.longClickable {
			actions = append(actions, "longpress")
		}

		label := truncate(el.label, labelWidth)
		fmt.Printf("  [%d] %q @ (%d, %d) (%s)\n", index, label, el.x, el.y, strings.Join(actions, "/"))
	}
}

func printRawXML(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}

	decoder := xml.NewDecoder(bytes.NewReader(data))

	var out bytes.Buffer
	encoder := xml.NewEncoder(&out)
	encoder.Indent("", "  ")

	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		if err := encoder.EncodeToken(token); err != nil {
			return err
		}
	}

	if err := encoder.Flush(); err != nil {
		return err
	}

	formatted := strings.Replace(out.String(), "?><", "?>\n<", 1)
	fmt.Println(formatted)
	return nil
}

func uiRaw(serial string) {
	fetchUIDumpFile(serial, false)

	var err error

	debugStep("xml format", func() {
		err = printRawXML(uiDumpLocalPath)
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to format ui dump: %s\n", err)
	}
}

func uiTap(serial string, state *sessionState, index int) {
	if index < 0 || index >= len(state.elements) {
		fmt.Println("invalid index, run dump first")
		return
	}

	el := state.elements[index]

	if !el.clickable {
		fmt.Println("this element only supports longpress")
		return
	}

	runAdb(serial, "shell", "input", "tap", strconv.Itoa(el.x), strconv.Itoa(el.y))
}

func uiLongpress(serial string, state *sessionState, index int) {
	if index < 0 || index >= len(state.elements) {
		fmt.Println("invalid index, run dump first")
		return
	}

	el := state.elements[index]

	if !el.longClickable {
		fmt.Println("this element only supports tap")
		return
	}

	runAdb(
		serial, "shell", "input", "swipe",
		strconv.Itoa(el.x), strconv.Itoa(el.y),
		strconv.Itoa(el.x), strconv.Itoa(el.y),
		strconv.Itoa(longpressDurationMs),
	)
}

func uiHome(serial string) {
	runAdb(serial, "shell", "input", "keyevent", "KEYCODE_HOME")
}

func uiBack(serial string) {
	runAdb(serial, "shell", "input", "keyevent", "KEYCODE_BACK")
}

func uiOpen(serial, packageName string) {
	runAdb(serial, "shell", "monkey", "-p", packageName, "-c", "android.intent.category.LAUNCHER", "1")
}

func uiSwipe(serial, direction string) {
	centerX := screenWidthFallback / 2

	screenHeight := float64(screenHeightFallback)

	var startY, endY int

	switch direction {
	case "up":
		startY = int(screenHeight * 0.7)
		endY = int(screenHeight * 0.3)
	case "down":
		startY = int(screenHeight * 0.3)
		endY = int(screenHeight * 0.7)
	default:
		fmt.Println("use 'up' or 'down'")
		return
	}

	runAdb(serial, "shell", "input", "swipe", strconv.Itoa(centerX), strconv.Itoa(startY), strconv.Itoa(centerX), strconv.Itoa(endY), strconv.Itoa(swipeDurationMs))
}

func uiType(serial, text string) {
	escapedText := strings.ReplaceAll(text, " ", "%s")
	runAdb(serial, "shell", "input", "text", escapedText)
}

func runNavigateShell(serial string) {
	state := &sessionState{}
	scanner := bufio.NewScanner(os.Stdin)

	fmt.Printf("connected to %s, type 'help' for commands\n", serial)

	for {
		fmt.Print("> ")

		if !scanner.Scan() {
			fmt.Println()
			break
		}

		rawLine := strings.TrimSpace(scanner.Text())
		if rawLine == "" {
			continue
		}

		parts := strings.Fields(rawLine)
		command := strings.ToLower(parts[0])
		args := parts[1:]

		if command == "exit" || command == "quit" {
			break
		}

		dispatchNavigateCommand(serial, state, command, args)
	}
}

func dispatchNavigateCommand(serial string, state *sessionState, command string, args []string) {
	switch command {
	case "help":
		fmt.Print(navigateHelp)

	case "dump":
		uiDump(serial, state)

	case "raw":
		uiRaw(serial)

	case "tap":
		if len(args) == 0 {
			fmt.Println("usage: tap <n>")
			return
		}

		index, err := strconv.Atoi(args[0])
		if err != nil {
			fmt.Println("n must be a number")
			return
		}

		uiTap(serial, state, index)

	case "longpress":
		if len(args) == 0 {
			fmt.Println("usage: longpress <n>")
			return
		}

		index, err := strconv.Atoi(args[0])
		if err != nil {
			fmt.Println("n must be a number")
			return
		}

		uiLongpress(serial, state, index)

	case "home":
		uiHome(serial)

	case "back":
		uiBack(serial)

	case "open":
		if len(args) == 0 {
			fmt.Println("usage: open <package>")
			return
		}

		uiOpen(serial, args[0])

	case "swipe":
		direction := "up"
		if len(args) > 0 {
			direction = args[0]
		}

		uiSwipe(serial, direction)

	case "type":
		if len(args) == 0 {
			fmt.Println("usage: type <text>")
			return
		}

		uiType(serial, strings.Join(args, " "))

	default:
		fmt.Printf("unknown command: %s, type 'help' for a list\n", command)
	}
}

// cli args

type cliArgs struct {
	command  string
	ip       string
	useIP    bool
	file     string
	dest     string
	navigate bool
	debug    bool
	help     bool
}

const usageText = `usage: android-tools <command> [flags]

commands:
  screen    mirror the device screen via scrcpy
  copy      push a file to the device

flags:
  --ip [addr]     connect over tcp/ip instead of usb (default addr: ` + ipDefault + `)
  --file <path>   file to push, prompts via zenity if omitted (copy only)
  --dest <name>   destination filename under ` + storageRoot + ` (copy only)
  --navigate      open the interactive navigation shell after mirroring (screen only)
  --debug         print timing info for the adb dump/pull/parse steps (dump/raw)
  -h, --help      show this message
`

func parseArgs() (cliArgs, error) {
	args := cliArgs{}

	rest := os.Args[1:]
	if len(rest) == 0 {
		args.help = true
		return args, nil
	}

	if rest[0] == "-h" || rest[0] == "--help" {
		args.help = true
		return args, nil
	}

	args.command = rest[0]
	if args.command != "screen" && args.command != "copy" {
		return args, fmt.Errorf("invalid command %q, expected 'screen' or 'copy'", args.command)
	}

	rest = rest[1:]

	for i := 0; i < len(rest); i++ {
		token := rest[i]

		switch {
		case token == "--ip":
			args.useIP = true
			args.ip = ipDefault

			if i+1 < len(rest) && !strings.HasPrefix(rest[i+1], "--") {
				args.ip = rest[i+1]
				i++
			}

		case token == "--file":
			if i+1 >= len(rest) {
				return args, fmt.Errorf("--file requires a value")
			}

			args.file = rest[i+1]
			i++

		case token == "--dest":
			if i+1 >= len(rest) {
				return args, fmt.Errorf("--dest requires a value")
			}

			args.dest = rest[i+1]
			i++

		case token == "--navigate":
			args.navigate = true

		case token == "--debug":
			args.debug = true

		case token == "-h" || token == "--help":
			args.help = true

		default:
			return args, fmt.Errorf("unknown argument: %s", token)
		}
	}

	return args, nil
}

func run() int {
	args, err := parseArgs()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}

	if args.help {
		fmt.Print(usageText)
		return 0
	}

	debugMode = args.debug

	serial, connectedIP, ok := resolveTarget(args.useIP, args.ip)
	if !ok {
		return 1
	}

	if connectedIP != "" {
		// only ip connections need explicit disconnect on exit
		defer adbDisconnectIP(connectedIP)
	}

	if args.command == "screen" {
		runScreen(serial, args.navigate)
		return 0
	}

	return runCopy(serial, args.file, args.dest)
}

func main() {
	os.Exit(run())
}
