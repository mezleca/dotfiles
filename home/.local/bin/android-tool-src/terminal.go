package main

import (
	"os"
	"syscall"
	"unsafe"
)

const defaultTerminalWidth = 100
const minColumnWidth = 6

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
