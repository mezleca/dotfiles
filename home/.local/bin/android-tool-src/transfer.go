package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

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

func pickFileZenity() string {
	if _, err := exec.LookPath("zenity"); err != nil {
		fmt.Println("zenity not found, pass a file path instead")
		return ""
	}

	out, _ := exec.Command("zenity", "--file-selection", "--title=select file to push").Output()
	return strings.TrimSpace(string(out))
}

func runPush(serial, filePath, dest string) error {
	if filePath == "" {
		filePath = pickFileZenity()
	}

	if filePath == "" {
		return fmt.Errorf("no file selected")
	}

	fileArg, err := expandUser(filePath)
	if err != nil {
		return fmt.Errorf("resolving path: %w", err)
	}

	info, err := os.Stat(fileArg)
	if err != nil || info.IsDir() {
		return fmt.Errorf("file not found: %s", fileArg)
	}

	if dest == "" {
		dest = filepath.Base(fileArg)
	}

	remotePath := fmt.Sprintf("%s/%s", storageRoot, dest)

	cmd := exec.Command("adb", "-s", serial, "push", fileArg, remotePath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

func runPull(serial, remotePath, localPath string) error {
	if remotePath == "" {
		return fmt.Errorf("remote path required")
	}

	if !strings.HasPrefix(remotePath, "/") {
		remotePath = fmt.Sprintf("%s/%s", storageRoot, remotePath)
	}

	if localPath == "" {
		localPath = filepath.Base(remotePath)
	}

	resolvedLocal, err := expandUser(localPath)
	if err != nil {
		return fmt.Errorf("resolving local path: %w", err)
	}

	cmd := exec.Command("adb", "-s", serial, "pull", remotePath, resolvedLocal)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}
