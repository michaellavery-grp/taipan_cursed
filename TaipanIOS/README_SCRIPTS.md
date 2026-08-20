# TaipanCursed Build Scripts

This directory contains helper scripts for building and debugging the TaipanCursed iOS app with Claude Code.

## Available Scripts

### 🚀 `build_and_debug.sh` - Full Build
Complete Xcode build with error reporting.

```bash
./build_and_debug.sh
```

**What it does**:
- Performs clean build of entire project
- Compiles for iOS Simulator
- Saves full output to `build_output.log`
- Shows build status with ✅/❌
- Displays error count and warnings
- Shows first 50 lines of errors if build fails

**When to use**: After making code changes, before testing in simulator.

**Output files**: `build_output.log`

---

### ⚡ `quick_check.sh` - Fast Syntax Check
Quick type-check of all Swift files (no full build).

```bash
./quick_check.sh
```

**What it does**:
- Type-checks each Swift file individually
- Much faster than full build (~5-10 seconds)
- Shows ✅/❌ status for each file
- Reports total error count

**When to use**: After editing files, before committing. Quick sanity check.

**Note**: This is syntax checking only. Won't catch linking or framework issues.

---

### 🔍 `show_errors.sh` - Extract Build Errors
Parses the most recent build log and shows errors.

```bash
./show_errors.sh
```

**What it does**:
- Reads `build_output.log` from last build
- Extracts all error messages with context
- Shows error summary and count

**When to use**: After a failed build, to review errors without rebuilding.

**Prerequisite**: Must run `build_and_debug.sh` first to generate log.

---

## Typical Workflows

### Making Code Changes
```bash
# 1. Edit Swift files in Xcode or text editor
# 2. Quick check syntax
./quick_check.sh

# 3. If OK, do full build
./build_and_debug.sh

# 4. If errors, review them
./show_errors.sh
```

### Working with Claude Code
```bash
# Tell Claude to build and fix errors:
# "Run ./build_and_debug.sh and fix any errors you find"

# Claude will:
# - Run the build
# - Read build_output.log
# - Identify errors
# - Read the relevant files
# - Apply fixes
# - Verify with another build
```

### Before Committing to Git
```bash
# Quick pre-commit check
./quick_check.sh

# If all pass, commit
git add .
git commit -m "Your commit message"
```

---

## Understanding Build Output

### Success Example
```
Building TaipanCursed Xcode project...
========================================
[... build output ...]

✅ Build succeeded!
⚠️  1 warning(s) found (see build_output.log)
```

### Failure Example
```
Building TaipanCursed Xcode project...
========================================
[... build output ...]

❌ Build failed. Errors saved to build_output.log

=== Build Errors ===
/Users/.../ContentView.swift:39:39: error: cannot find 'UIColor' in scope
```

---

## File Locations

- **Build Scripts**: `/Users/michaellavery/Desktop/TaipanCursed/*.sh`
- **Build Log**: `/Users/michaellavery/Desktop/TaipanCursed/build_output.log`
- **Swift Files**: `/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed/*.swift`
- **Xcode Project**: `/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed.xcodeproj`

---

## Troubleshooting

### Script Won't Run (Permission Denied)
```bash
chmod +x build_and_debug.sh quick_check.sh show_errors.sh
```

### "No such file or directory"
Make sure you're in the project directory:
```bash
cd /Users/michaellavery/Desktop/TaipanCursed
```

### Build Succeeds but App Won't Run
- Open project in Xcode: `open TaipanCursed.xcodeproj`
- Select a simulator device
- Check signing settings (Project → Signing & Capabilities)

### "Unable to find a device matching the provided destination specifier"
- The build script uses generic iOS Simulator destination
- If this fails, open in Xcode and build from there
- Or modify `build_and_debug.sh` to specify a specific simulator

---

## Integration with Xcode

You can run these scripts from Xcode's Run Script Phase:

1. Select project in Xcode
2. Choose your target
3. Build Phases tab
4. Click "+" → New Run Script Phase
5. Add: `"${PROJECT_DIR}/quick_check.sh"`

This will run the quick check before every build.

---

## Documentation

- **XCODE_DEBUGGING.md** - Comprehensive debugging guide for Claude Code
- **FIXES_APPLIED.md** - Log of all fixes applied to this project
- **README_SCRIPTS.md** - This file

---

## Quick Reference

| Script | Speed | Purpose | Output File |
|--------|-------|---------|-------------|
| `quick_check.sh` | ⚡ Fast (5-10s) | Syntax check | None |
| `build_and_debug.sh` | 🐢 Slow (30-60s) | Full compile | build_output.log |
| `show_errors.sh` | ⚡ Instant | Parse errors | None |

---

**Project Status**: ✅ Build passing as of 2025-11-20

All compilation errors have been fixed. The app builds successfully for iOS Simulator.
