package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// adb / device hardcoded stuff
const ipDefault = "192.168.1.105:40801"
const storageRoot = "/sdcard/Download"

const shellHelp = `
available commands:
  show                         list adb-visible devices and tracked devices
  connect ip [addr]            connect to a device over tcp/ip (default: ` + ipDefault + `)
  connect usb                  connect to an untracked usb device
  screen [@id]                 mirror a device via scrcpy
  dump [@id]                   list interactable elements on screen (tap/longpress targets)
  raw [@id]                    print the raw uiautomator dump xml (indented)
  tap <index> [@id]            tap element number from the last dump
  longpress <index> [@id]      long press element number from the last dump
  type <text> [@id]            type text into the currently focused field
  home [@id]                   press home button
  back [@id]                   press back button
  open <package> [@id]         launch an app by package name
  swipe up|down [@id]          scroll the screen
  push <file> [dest] [@id]     push a file to the device, prompts via zenity if file omitted
  pull <remote> [local] [@id]  pull a file from the device
  help                         show this message
  exit                         leave the shell

[@id] targets a tracked device from 'show'; omit it to use the last device referenced.
`

type shellState struct {
	registry  *deviceRegistry
	sessions  map[int]*sessionState
	currentID int
}

func (s *shellState) sessionFor(id int) *sessionState {
	if st, ok := s.sessions[id]; ok {
		return st
	}

	st := &sessionState{}
	s.sessions[id] = st

	return st
}

func tokenize(line string) []string {
	var tokens []string
	var current strings.Builder
	inQuotes := false

	for _, r := range line {
		switch {
		case r == '"':
			inQuotes = !inQuotes
		case r == ' ' && !inQuotes:
			if current.Len() > 0 {
				tokens = append(tokens, current.String())
				current.Reset()
			}
		default:
			current.WriteRune(r)
		}
	}

	if current.Len() > 0 {
		tokens = append(tokens, current.String())
	}

	return tokens
}

func extractDeviceRef(tokens []string) (remaining []string, id int, hasID bool) {
	for i, t := range tokens {
		if !strings.HasPrefix(t, "@") {
			continue
		}

		parsedID, err := strconv.Atoi(strings.TrimPrefix(t, "@"))
		if err != nil {
			continue
		}

		remaining = append(append([]string{}, tokens[:i]...), tokens[i+1:]...)
		return remaining, parsedID, true
	}

	return tokens, 0, false
}

func (s *shellState) resolveDevice(tokens []string) ([]string, *device, error) {
	remaining, id, hasID := extractDeviceRef(tokens)
	if !hasID {
		id = s.currentID
	}

	if id == 0 {
		return remaining, nil, fmt.Errorf("no device selected, connect one or pass @id")
	}

	d, ok := s.registry.get(id)
	if !ok {
		return remaining, nil, fmt.Errorf("no device @%d, run 'show' to see tracked devices", id)
	}

	return remaining, d, nil
}

func handleConnect(s *shellState, args []string) {
	if len(args) == 0 {
		fmt.Println("usage: connect ip [addr] | connect usb")
		return
	}

	switch strings.ToLower(args[0]) {
	case "ip":
		ip := ipDefault
		if len(args) > 1 {
			ip = args[1]
		}

		d, err := s.registry.connectIP(ip)
		if err != nil {
			fmt.Println(err)
			return
		}

		s.currentID = d.id
		fmt.Printf("connected @%d (%s)\n", d.id, d.serial)

	case "usb":
		d, err := s.registry.connectUSB()
		if err != nil {
			fmt.Println(err)
			return
		}

		s.currentID = d.id
		fmt.Printf("connected @%d (%s)\n", d.id, d.serial)

	default:
		fmt.Println("usage: connect ip [addr] | connect usb")
	}
}

func handleScreen(s *shellState, args []string) {
	_, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	runScreen(d)
	s.currentID = d.id
}

func handleDump(s *shellState, args []string) {
	_, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	s.currentID = d.id
	uiDump(d.serial, s.sessionFor(d.id))
}

func handleRaw(s *shellState, args []string) {
	_, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	s.currentID = d.id
	uiRaw(d.serial)
}

func handleTap(s *shellState, args []string) {
	remaining, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	if len(remaining) == 0 {
		fmt.Println("usage: tap <index> [@id]")
		return
	}

	index, err := strconv.Atoi(remaining[0])
	if err != nil {
		fmt.Println("index must be a number")
		return
	}

	s.currentID = d.id
	uiTap(d.serial, s.sessionFor(d.id), index)
}

func handleLongpress(s *shellState, args []string) {
	remaining, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	if len(remaining) == 0 {
		fmt.Println("usage: longpress <index> [@id]")
		return
	}

	index, err := strconv.Atoi(remaining[0])
	if err != nil {
		fmt.Println("index must be a number")
		return
	}

	s.currentID = d.id
	uiLongpress(d.serial, s.sessionFor(d.id), index)
}

func handleType(s *shellState, args []string) {
	remaining, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	if len(remaining) == 0 {
		fmt.Println("usage: type <text> [@id]")
		return
	}

	s.currentID = d.id
	uiType(d.serial, strings.Join(remaining, " "))
}

func handleHome(s *shellState, args []string) {
	_, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	s.currentID = d.id
	uiHome(d.serial)
}

func handleBack(s *shellState, args []string) {
	_, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	s.currentID = d.id
	uiBack(d.serial)
}

func handleOpen(s *shellState, args []string) {
	remaining, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	if len(remaining) == 0 {
		fmt.Println("usage: open <package> [@id]")
		return
	}

	s.currentID = d.id
	uiOpen(d.serial, remaining[0])
}

func handleSwipe(s *shellState, args []string) {
	remaining, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	direction := "up"
	if len(remaining) > 0 {
		direction = remaining[0]
	}

	s.currentID = d.id
	uiSwipe(d.serial, direction)
}

func handlePush(s *shellState, args []string) {
	remaining, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	filePath := ""
	if len(remaining) > 0 {
		filePath = remaining[0]
	}

	dest := ""
	if len(remaining) > 1 {
		dest = remaining[1]
	}

	s.currentID = d.id

	if err := runPush(d.serial, filePath, dest); err != nil {
		fmt.Println("push failed:", err)
	}
}

func handlePull(s *shellState, args []string) {
	remaining, d, err := s.resolveDevice(args)
	if err != nil {
		fmt.Println(err)
		return
	}

	if len(remaining) == 0 {
		fmt.Println("usage: pull <remote> [local] [@id]")
		return
	}

	remotePath := remaining[0]

	localPath := ""
	if len(remaining) > 1 {
		localPath = remaining[1]
	}

	s.currentID = d.id

	if err := runPull(d.serial, remotePath, localPath); err != nil {
		fmt.Println("pull failed:", err)
	}
}

func dispatch(s *shellState, command string, args []string) {
	switch command {
	case "help":
		fmt.Print(shellHelp)
	case "show":
		printShow(s.registry)
	case "connect":
		handleConnect(s, args)
	case "screen":
		handleScreen(s, args)
	case "dump":
		handleDump(s, args)
	case "raw":
		handleRaw(s, args)
	case "tap":
		handleTap(s, args)
	case "longpress":
		handleLongpress(s, args)
	case "type":
		handleType(s, args)
	case "home":
		handleHome(s, args)
	case "back":
		handleBack(s, args)
	case "open":
		handleOpen(s, args)
	case "swipe":
		handleSwipe(s, args)
	case "push":
		handlePush(s, args)
	case "pull":
		handlePull(s, args)
	default:
		fmt.Printf("unknown command: %s, type 'help' for a list\n", command)
	}
}

func runShell() int {
	registry := newDeviceRegistry()
	defer registry.disconnectAll()

	state := &shellState{registry: registry, sessions: make(map[int]*sessionState)}
	scanner := bufio.NewScanner(os.Stdin)

	if scanner.Err() == nil {
	    fmt.Println("the fuk")
		return 0
	}

	fmt.Println("type 'help' for commands")

	for {
		fmt.Print("> ")

		if !scanner.Scan() {
			fmt.Println()
			break
		}

		tokens := tokenize(strings.TrimSpace(scanner.Text()))
		if len(tokens) == 0 {
			continue
		}

		command := strings.ToLower(tokens[0])
		if command == "exit" || command == "quit" {
			break
		}

		dispatch(state, command, tokens[1:])
	}

	return 0
}
