package main

import (
	"fmt"
	"os"
)

var debugMode = false

const usageText = `usage: android-tools [flags]

starts an interactive shell for managing android devices over adb.
inside the shell, type 'help' for the list of commands.

flags:
  --debug     print timing info for the adb dump/pull/parse steps
  -h, --help  show this message
`

func parseFlags(args []string) (debug bool, help bool, err error) {
	for _, token := range args {
		switch token {
		case "--debug":
			debug = true
		case "-h", "--help":
			help = true
		default:
			return false, false, fmt.Errorf("unknown argument: %s", token)
		}
	}

	return debug, help, nil
}

func run() int {
	debug, help, err := parseFlags(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}

	if help {
		fmt.Print(usageText)
		return 0
	}

	debugMode = debug

	return runShell()
}

func main() {
	os.Exit(run())
}
