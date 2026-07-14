package main

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const uiDumpRemotePath = "/sdcard/window_dump.xml"
const uiDumpLocalPath = "/tmp/window_dump.xml"
const longpressDurationMs = 800
const swipeDurationMs = 300
const screenWidthFallback = 1080
const screenHeightFallback = 2195

var boundsPattern = regexp.MustCompile(`\[(\d+),(\d+)\]\[(\d+),(\d+)\]`)

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
		fmt.Println("failed to parse ui dump:", err)
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
		fmt.Println("failed to format ui dump:", err)
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
