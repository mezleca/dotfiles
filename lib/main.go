package main

import (
	"bufio"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/user"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

const (
	DotHomeFolder = "home"
	DotRootFolder = "root"
	DotsFile      = "dots.txt"
	DirPerm       = 0o755
)

type Scope string

const (
	ScopeHome Scope = "home"
	ScopeRoot Scope = "root"
)

type Mode string

const (
	ModeLiteral   Mode = "literal"
	ModeOne       Mode = "one"
	ModeRecursive Mode = "recursive"
)

type Entry struct {
	Scope Scope
	Spec  string
	Mode  Mode
	Base  string
}

type OwnerContext struct {
	UserHome   string
	OwnerUser  string
	OwnerGroup string
	OwnerUID   int
	OwnerGID   int
}

type SyncCounters struct {
	New     int
	Synced  int
	Skipped int
	Removed int
}

type InstallCounters struct {
	Installed int
	Skipped   int
}

func loadOwnerContext() (OwnerContext, error) {
	ctx := OwnerContext{UserHome: os.Getenv("HOME")}

	if os.Geteuid() != 0 {
		return ctx, nil
	}

	sudoUser := os.Getenv("SUDO_USER")

	if sudoUser == "" {
		return ctx, nil
	}

	u, err := user.Lookup(sudoUser)

	if err != nil {
		return ctx, fmt.Errorf("lookup sudo user %s: %w", sudoUser, err)
	}

	group, err := user.LookupGroupId(u.Gid)

	if err != nil {
		return ctx, fmt.Errorf("lookup group for %s: %w", sudoUser, err)
	}

	uid, err := strconv.Atoi(u.Uid)

	if err != nil {
		return ctx, fmt.Errorf("parse uid %s: %w", u.Uid, err)
	}

	gid, err := strconv.Atoi(u.Gid)

	if err != nil {
		return ctx, fmt.Errorf("parse gid %s: %w", u.Gid, err)
	}

	ctx.UserHome = u.HomeDir
	ctx.OwnerUser = sudoUser
	ctx.OwnerGroup = group.Name
	ctx.OwnerUID = uid
	ctx.OwnerGID = gid

	return ctx, nil
}

func fixHomeOwnership(targetPath string, scope Scope, ctx OwnerContext) {
	if scope != ScopeHome || ctx.OwnerUser == "" {
		return
	}

	currentPath := targetPath

	for strings.HasPrefix(currentPath, ctx.UserHome) && currentPath != ctx.UserHome {
		_ = os.Chown(currentPath, ctx.OwnerUID, ctx.OwnerGID)
		currentPath = filepath.Dir(currentPath)
	}
}

func fixRepoHomeOwnership(repoPath string, scope Scope, ctx OwnerContext) {
	if scope != ScopeHome || ctx.OwnerUser == "" {
		return
	}

	_ = filepath.WalkDir(repoPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		_ = os.Chown(path, ctx.OwnerUID, ctx.OwnerGID)
		return nil
	})
}

func normalizeEntryLine(line string) string {
	if idx := strings.Index(line, "#"); idx >= 0 {
		line = line[:idx]
	}

	line = strings.TrimSuffix(line, "\r")
	line = strings.TrimSuffix(line, "/")
	return line
}

func parseEntry(raw string) Entry {
	scope := ScopeHome

	if strings.HasPrefix(raw, "/") {
		scope = ScopeRoot
	}

	spec := raw

	switch {
	case strings.HasPrefix(raw, "$HOME/"):
		spec = strings.TrimPrefix(raw, "$HOME/")
	case strings.HasPrefix(raw, "/"):
		spec = strings.TrimPrefix(raw, "/")
	}

	mode := ModeLiteral
	base := spec

	switch {
	case strings.HasSuffix(spec, "/**"):
		mode = ModeRecursive
		base = strings.TrimSuffix(spec, "/**")
	case strings.HasSuffix(spec, "/*"):
		mode = ModeOne
		base = strings.TrimSuffix(spec, "/*")
	}

	return Entry{Scope: scope, Spec: spec, Mode: mode, Base: base}
}

func loadEntries(path string) ([]Entry, error) {
	file, err := os.Open(path)

	if err != nil {
		return nil, fmt.Errorf("open %s: %w", path, err)
	}

	defer file.Close()

	var entries []Entry
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := normalizeEntryLine(scanner.Text())
		if line == "" {
			continue
		}
		entries = append(entries, parseEntry(line))
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}

	return entries, nil
}

func anyRootScope(entries []Entry) bool {
	for _, entry := range entries {
		if entry.Scope == ScopeRoot {
			return true
		}
	}
	return false
}

func entryRepoBase(scope Scope, rel string) string {
	if scope == ScopeHome {
		return filepath.Join(DotHomeFolder, rel)
	}
	return filepath.Join(DotRootFolder, rel)
}

func entrySourcePath(scope Scope, rel string, userHome string) string {
	if scope == ScopeHome {
		return filepath.Join(userHome, rel)
	}
	return "/" + rel
}

func iterModeFiles(basePath string, mode Mode) ([]string, error) {
	info, err := os.Stat(basePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("stat %s: %w", basePath, err)
	}

	switch mode {
	case ModeLiteral:
		if !info.IsDir() {
			return []string{basePath}, nil
		}
		return walkFilesRecursive(basePath)
	case ModeOne:
		if !info.IsDir() {
			return nil, nil
		}
		return listFilesDepth1(basePath)
	case ModeRecursive:
		if !info.IsDir() {
			return nil, nil
		}
		return walkFilesRecursive(basePath)
	default:
		return nil, fmt.Errorf("unknown mode: %s", mode)
	}
}

func walkFilesRecursive(root string) ([]string, error) {
	var files []string
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type().IsRegular() {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("walk %s: %w", root, err)
	}
	return files, nil
}

func listFilesDepth1(dir string) ([]string, error) {
	dirEntries, err := os.ReadDir(dir)

	if err != nil {
		return nil, fmt.Errorf("read dir %s: %w", dir, err)
	}

	var files []string
	for _, dirEntry := range dirEntries {
		info, err := dirEntry.Info()
		if err != nil {
			continue
		}
		if info.Mode().IsRegular() {
			files = append(files, filepath.Join(dir, dirEntry.Name()))
		}
	}
	return files, nil
}

func copyFile(src, dst string) error {
	srcInfo, err := os.Stat(src)

	if err != nil {
		return fmt.Errorf("stat source %s: %w", src, err)
	}

	_ = os.Remove(dst)

	in, err := os.Open(src)

	if err != nil {
		return fmt.Errorf("open source %s: %w", src, err)
	}

	defer in.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, srcInfo.Mode().Perm())

	if err != nil {
		return fmt.Errorf("create dest %s: %w", dst, err)
	}

	defer out.Close()

	if _, err := io.Copy(out, in); err != nil {
		return fmt.Errorf("copy %s to %s: %w", src, dst, err)
	}

	return nil
}

func checkWritable(dir string) bool {
	tmpFile, err := os.CreateTemp(dir, ".write-test-*")
	if err != nil {
		return false
	}
	name := tmpFile.Name()
	tmpFile.Close()
	os.Remove(name)
	return true
}

func copyWithOwnership(src, dst string, scope Scope, ctx OwnerContext, fixOwnership func(string, Scope, OwnerContext)) error {
	dstDir := filepath.Dir(dst)

	if err := os.MkdirAll(dstDir, DirPerm); err != nil {
		return fmt.Errorf("mkdir %s: %w", dstDir, err)
	}

	fixOwnership(dstDir, scope, ctx)

	if err := copyFile(src, dst); err != nil {
		return err
	}

	fixOwnership(dst, scope, ctx)
	return nil
}

func listRegularFilesRel(root string) ([]string, error) {
	info, err := os.Stat(root)

	if err != nil || !info.IsDir() {
		return nil, nil
	}

	var rels []string

	err = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type().IsRegular() {
			rels = append(rels, strings.TrimPrefix(path, root+string(os.PathSeparator)))
		}
		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("walk %s: %w", root, err)
	}

	return rels, nil
}

func listDirsDeepestFirst(root string) []string {
	var dirs []string

	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil || path == root {
			return nil
		}
		if d.IsDir() {
			dirs = append(dirs, path)
		}
		return nil
	})

	// deepest first, so a child directory is gone before its parent is checked
	sort.Slice(dirs, func(i, j int) bool { return len(dirs[i]) > len(dirs[j]) })
	return dirs
}

func dirIsEmpty(dir string) bool {
	entries, err := os.ReadDir(dir)
	return err == nil && len(entries) == 0
}

func runSync() error {
	ctx, err := loadOwnerContext()
	if err != nil {
		return err
	}

	entries, err := loadEntries(DotsFile)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(DotHomeFolder, DirPerm); err != nil {
		return fmt.Errorf("mkdir %s: %w", DotHomeFolder, err)
	}

	if err := os.MkdirAll(DotRootFolder, DirPerm); err != nil {
		return fmt.Errorf("mkdir %s: %w", DotRootFolder, err)
	}

	if !checkWritable(DotHomeFolder) || !checkWritable(DotRootFolder) {
		return fmt.Errorf("no write permission in repo folders (%s, %s)", DotHomeFolder, DotRootFolder)
	}

	if anyRootScope(entries) && os.Geteuid() != 0 {
		return fmt.Errorf("root entries detected in dots.txt, run with sudo")
	}

	if ctx.OwnerUser != "" {
		fixRepoHomeOwnership(DotHomeFolder, ScopeHome, ctx)
	}

	counters := &SyncCounters{}
	for _, entry := range entries {
		if err := syncEntry(entry, ctx, counters); err != nil {
			return err
		}
	}

	fmt.Println("cleaning deleted source files...")

	if err := cleanupDeletedInScope(ScopeHome, DotHomeFolder, ctx, counters); err != nil {
		return err
	}
	if err := cleanupDeletedInScope(ScopeRoot, DotRootFolder, ctx, counters); err != nil {
		return err
	}

	fmt.Println("cleaning orphaned entries...")
	coveredHome, err := buildCoveredFiles(ScopeHome, DotHomeFolder, entries)

	if err != nil {
		return err
	}
	coveredRoot, err := buildCoveredFiles(ScopeRoot, DotRootFolder, entries)

	if err != nil {
		return err
	}

	if err := cleanupOrphansInScope(DotHomeFolder, coveredHome, counters); err != nil {
		return err
	}

	if err := cleanupOrphansInScope(DotRootFolder, coveredRoot, counters); err != nil {
		return err
	}

	fmt.Printf("new: %d | synced: %d | skipped: %d | removed: %d\n",
		counters.New, counters.Synced, counters.Skipped, counters.Removed)
	return nil
}

func syncEntry(entry Entry, ctx OwnerContext, counters *SyncCounters) error {
	srcBase := entrySourcePath(entry.Scope, entry.Base, ctx.UserHome)
	repoBase := entryRepoBase(entry.Scope, entry.Base)

	if entry.Mode == ModeLiteral {
		if info, err := os.Stat(srcBase); err == nil && info.Mode().IsRegular() {
			return syncFile(srcBase, repoBase, entry.Spec, entry.Scope, ctx, counters)
		}
	}

	srcFiles, err := iterModeFiles(srcBase, entry.Mode)
	if err != nil {
		return fmt.Errorf("list files under %s: %w", srcBase, err)
	}

	for _, srcFile := range srcFiles {
		relFile := strings.TrimPrefix(srcFile, srcBase+string(os.PathSeparator))
		dstFile := filepath.Join(repoBase, relFile)
		relName := entry.Base + "/" + relFile
		if err := syncFile(srcFile, dstFile, relName, entry.Scope, ctx, counters); err != nil {
			return err
		}
	}
	return nil
}

func syncFile(src, dst, relName string, scope Scope, ctx OwnerContext, counters *SyncCounters) error {
	dstInfo, statErr := os.Stat(dst)

	if os.IsNotExist(statErr) {
		fmt.Printf("  new: %s\n", relName)

		if err := copyWithOwnership(src, dst, scope, ctx, fixRepoHomeOwnership); err != nil {
			return err
		}

		counters.New++
		return nil
	}

	if statErr != nil {
		return fmt.Errorf("stat %s: %w", dst, statErr)
	}

	srcInfo, err := os.Stat(src)

	if err != nil {
		return fmt.Errorf("stat %s: %w", src, err)
	}

	if srcInfo.ModTime().After(dstInfo.ModTime()) {
		fmt.Printf("  sync: %s\n", relName)
		if err := copyWithOwnership(src, dst, scope, ctx, fixRepoHomeOwnership); err != nil {
			return err
		}
		counters.Synced++
		return nil
	}

	counters.Skipped++
	return nil
}

func cleanupDeletedInScope(scope Scope, root string, ctx OwnerContext, counters *SyncCounters) error {
	rels, err := listRegularFilesRel(root)

	if err != nil {
		return err
	}

	for _, rel := range rels {
		src := entrySourcePath(scope, rel, ctx.UserHome)

		if info, err := os.Stat(src); err == nil && info.Mode().IsRegular() {
			continue
		}

		fmt.Printf("  remove: %s (source deleted)\n", rel)

		if err := os.Remove(filepath.Join(root, rel)); err != nil {
			return fmt.Errorf("remove %s: %w", rel, err)
		}

		counters.Removed++
	}

	for _, dir := range listDirsDeepestFirst(root) {
		if dirIsEmpty(dir) {
			os.Remove(dir)
		}
	}

	return nil
}

func buildCoveredFiles(scope Scope, root string, entries []Entry) (map[string]bool, error) {
	covered := make(map[string]bool)
	info, err := os.Stat(root)

	if err != nil || !info.IsDir() {
		return covered, nil
	}

	for _, entry := range entries {
		if entry.Scope != scope {
			continue
		}

		repoBase := entryRepoBase(scope, entry.Base)
		files, err := iterModeFiles(repoBase, entry.Mode)

		if err != nil {
			return nil, fmt.Errorf("list files under %s: %w", repoBase, err)
		}

		for _, file := range files {
			relFile := strings.TrimPrefix(file, root+string(os.PathSeparator))
			covered[relFile] = true
		}
	}

	return covered, nil
}

func cleanupOrphansInScope(root string, covered map[string]bool, counters *SyncCounters) error {
	rels, err := listRegularFilesRel(root)

	if err != nil {
		return err
	}

	for _, rel := range rels {
		if covered[rel] {
			continue
		}

		fmt.Printf("  remove: %s\n", rel)

		if err := os.Remove(filepath.Join(root, rel)); err != nil {
			return fmt.Errorf("remove %s: %w", rel, err)
		}

		counters.Removed++
	}

	for _, dir := range listDirsDeepestFirst(root) {
		rel := strings.TrimPrefix(dir, root+string(os.PathSeparator))

		if covered[rel] || !dirIsEmpty(dir) {
			continue
		}

		fmt.Printf("  remove: %s\n", rel)

		if err := os.Remove(dir); err != nil {
			continue
		}

		counters.Removed++
	}
	return nil
}

func runInstall() error {
	ctx, err := loadOwnerContext()

	if err != nil {
		return err
	}

	entries, err := loadEntries(DotsFile)

	if err != nil {
		return err
	}

	if anyRootScope(entries) && os.Geteuid() != 0 {
		return fmt.Errorf("root entries detected in dots.txt, run with sudo")
	}

	counters := &InstallCounters{}

	for _, entry := range entries {
		if err := installEntry(entry, ctx, counters); err != nil {
			return err
		}
	}

	fmt.Println()
	fmt.Printf("installed: %d | skipped: %d\n", counters.Installed, counters.Skipped)
	return nil
}

func installEntry(entry Entry, ctx OwnerContext, counters *InstallCounters) error {
	repoBase := entryRepoBase(entry.Scope, entry.Base)
	dstBase := entrySourcePath(entry.Scope, entry.Base, ctx.UserHome)

	if entry.Mode == ModeLiteral {
		if info, err := os.Stat(repoBase); err == nil && info.Mode().IsRegular() {
			return installFile(repoBase, dstBase, entry.Spec, entry.Scope, ctx, counters)
		}
	}

	repoInfo, err := os.Stat(repoBase)

	if err != nil || !repoInfo.IsDir() {
		counters.Skipped++
		return nil
	}

	repoFiles, err := iterModeFiles(repoBase, entry.Mode)

	if err != nil {
		return fmt.Errorf("list files under %s: %w", repoBase, err)
	}

	for _, repoFile := range repoFiles {
		relFile := strings.TrimPrefix(repoFile, repoBase+string(os.PathSeparator))
		dstFile := filepath.Join(dstBase, relFile)
		relName := entry.Base + "/" + relFile
		if err := installFile(repoFile, dstFile, relName, entry.Scope, ctx, counters); err != nil {
			return err
		}
	}

	return nil
}

func installFile(src, dst, relName string, scope Scope, ctx OwnerContext, counters *InstallCounters) error {
	info, err := os.Stat(src)

	if err != nil || !info.Mode().IsRegular() {
		counters.Skipped++
		return nil
	}

	fmt.Printf("  install: %s\n", relName)

	if err := copyWithOwnership(src, dst, scope, ctx, fixHomeOwnership); err != nil {
		return err
	}

	counters.Installed++
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: dots <sync|install>")
		os.Exit(1)
	}

	if _, err := os.Stat(DotsFile); err != nil {
		fmt.Fprintln(os.Stderr, "missing dots.txt...")
		os.Exit(1)
	}

	var runErr error
	switch os.Args[1] {
	case "sync":
		runErr = runSync()
	case "install":
		runErr = runInstall()
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		os.Exit(1)
	}

	if runErr != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", runErr)
		os.Exit(1)
	}
}
