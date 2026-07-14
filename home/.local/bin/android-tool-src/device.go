package main

import (
	"fmt"
	"os/exec"
	"strings"
)

type device struct {
	id     int
	serial string
	isIP   bool
}

type deviceRegistry struct {
	devices []device
	nextID  int
}

func newDeviceRegistry() *deviceRegistry {
	return &deviceRegistry{nextID: 1}
}

func (r *deviceRegistry) add(serial string, isIP bool) *device {
	r.devices = append(r.devices, device{id: r.nextID, serial: serial, isIP: isIP})
	r.nextID++

	return &r.devices[len(r.devices)-1]
}

func (r *deviceRegistry) get(id int) (*device, bool) {
	for i := range r.devices {
		if r.devices[i].id == id {
			return &r.devices[i], true
		}
	}

	return nil, false
}

func (r *deviceRegistry) trackedSerials() map[string]bool {
	tracked := make(map[string]bool, len(r.devices))
	for _, d := range r.devices {
		tracked[d.serial] = true
	}

	return tracked
}

func (r *deviceRegistry) connectIP(ip string) (*device, error) {
	exec.Command("adb", "connect", ip).Run()

	if !strings.Contains(adbRawDevices(), ip) {
		return nil, fmt.Errorf("connection to %s failed", ip)
	}

	return r.add(ip, true), nil
}

func (r *deviceRegistry) connectUSB() (*device, error) {
	tracked := r.trackedSerials()

	for _, serial := range adbDeviceSerials() {
		if isIPSerial(serial) || tracked[serial] {
			continue
		}

		return r.add(serial, false), nil
	}

	return nil, fmt.Errorf("no untracked usb device found")
}

func (r *deviceRegistry) disconnectAll() {
	for _, d := range r.devices {
		if d.isIP {
			exec.Command("adb", "disconnect", d.serial).Run()
		}
	}
}

func adbRawDevices() string {
	out, _ := exec.Command("adb", "devices").Output()
	return string(out)
}

func adbDeviceSerials() []string {
	var serials []string

	for _, line := range strings.Split(adbRawDevices(), "\n") {
		parts := strings.Fields(line)
		if len(parts) == 2 && parts[1] == "device" {
			serials = append(serials, parts[0])
		}
	}

	return serials
}

func isIPSerial(serial string) bool {
	return strings.Contains(serial, ":")
}

func runAdb(serial string, args ...string) string {
	cmdArgs := append([]string{"-s", serial}, args...)
	cmd := exec.Command("adb", cmdArgs...)

	var stdout, stderr strings.Builder
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		fmt.Println("adb error:", strings.TrimSpace(stderr.String()))
	}

	return stdout.String()
}

func printShow(registry *deviceRegistry) {
	fmt.Println("adb devices:")
	fmt.Print(adbRawDevices())

	if len(registry.devices) == 0 {
		fmt.Println("no tracked devices, use 'connect ip [addr]' or 'connect usb'")
		return
	}

	fmt.Println("tracked devices:")

	for _, d := range registry.devices {
		kind := "usb"
		if d.isIP {
			kind = "ip"
		}

		fmt.Printf("  @%d %s (%s)\n", d.id, d.serial, kind)
	}
}
