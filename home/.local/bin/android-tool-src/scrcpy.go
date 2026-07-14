package main

import (
	"fmt"
	"os/exec"
	"strings"
)

const scrcpyVideoCodec = "h265"
const scrcpyMaxSize = 1920
const scrcpyMaxFPS = 60

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

func startScrcpy(serial string) {
	args := []string{
		"-s", serial,
		fmt.Sprintf("--video-codec=%s", scrcpyVideoCodec),
		fmt.Sprintf("-m%d", scrcpyMaxSize),
		"--no-audio",
		fmt.Sprintf("--max-fps=%d", scrcpyMaxFPS),
		"-K",
	}

	exec.Command("scrcpy", args...).Start()
}

func runScreen(d *device) {
	if isScrcpyRunning(d.serial) {
		fmt.Printf("scrcpy already running for @%d, reusing it\n", d.id)
		return
	}

	startScrcpy(d.serial)
	fmt.Printf("mirroring @%d (%s)\n", d.id, d.serial)
}
