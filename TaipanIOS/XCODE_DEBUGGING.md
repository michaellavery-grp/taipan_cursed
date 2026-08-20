# Xcode Debugging with Claude Code

This guide shows how to efficiently debug your TaipanCursed iOS app using Claude Code.

## Quick Start

### Method 1: Command Line Build (Recommended)

```bash
# Navigate to project directory
cd /Users/michaellavery/Desktop/TaipanCursed

# Run the build script
./build_and_debug.sh

# If errors occur, extract them for Claude Code
./show_errors.sh
```

Then copy/paste the error output into Claude Code.

### Method 2: Xcode Build Errors

1. **Build in Xcode** (⌘B)
2. **Open Issue Navigator** (⌘5)
3. **Click on error** to see full context
4. **Copy error message** including file path and line number
5. **Paste into Claude Code chat**

Example format to paste:
```
/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed/GameModel.swift:120:5
error: type 'GameModel' does not conform to protocol 'ObservableObject'
```

## Workflow Tips

### For Multiple Errors
When you have many errors, use the command line build:

```bash
./build_and_debug.sh 2>&1 | tee errors.txt
```

This saves all output to `errors.txt` which you can review with Claude Code.

### For Single File Type-Checking
To quickly check a single Swift file:

```bash
cd /Users/michaellavery/Desktop/TaipanCursed
swiftc -typecheck TaipanCursed/GameModel.swift 2>&1
```

### For Specific Errors
If you know which file has issues:

```bash
# Type-check specific file
swiftc -typecheck TaipanCursed/ContentView.swift 2>&1

# Or grep build log for specific file
grep "ContentView.swift" build_output.log
```

## Available Schemes

To see available build schemes:

```bash
xcodebuild -list -project TaipanCursed.xcodeproj
```

## Building for Different Targets

### iOS Simulator (fastest for testing)
```bash
xcodebuild -project TaipanCursed.xcodeproj \
    -scheme TaipanCursed \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    build
```

### iOS Device
```bash
xcodebuild -project TaipanCursed.xcodeproj \
    -scheme TaipanCursed \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    build
```

## Common Error Patterns

### ObservableObject Conformance
```
error: type 'GameModel' does not conform to protocol 'ObservableObject'
```
**Solution**: Ensure all `@Published` optional types conform to `Equatable`

### Missing Import
```
error: cannot find 'PassthroughSubject' in scope
```
**Solution**: Add `import Combine` at top of file

### Unused Variable Warning
```
warning: initialization of immutable value 'x' was never used
```
**Solution**: Remove the unused variable or prefix with `_` if intentionally unused

## Automation with Claude Code

You can tell Claude Code to run builds automatically:

```
"Run ./build_and_debug.sh and fix any errors you find"
```

Claude Code has access to:
- Read Swift files
- Edit Swift files
- Run build scripts
- Parse error messages
- Apply fixes

## File Locations

- **Project**: `/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed.xcodeproj`
- **Swift Files**: `/Users/michaellavery/Desktop/TaipanCursed/TaipanCursed/*.swift`
- **Build Logs**: `/Users/michaellavery/Desktop/TaipanCursed/build_output.log`
- **Build Script**: `/Users/michaellavery/Desktop/TaipanCursed/build_and_debug.sh`
- **Error Extractor**: `/Users/michaellavery/Desktop/TaipanCursed/show_errors.sh`

## Example Claude Code Session

```
User: Run ./build_and_debug.sh and show me any errors

Claude: [runs script, finds errors, shows them]

User: Fix the ObservableObject conformance error in GameModel.swift

Claude: [reads file, makes changes, verifies with swiftc -typecheck]

User: Run the build again

Claude: [runs script, confirms errors are fixed]
```

## Tips

1. **Always verify fixes**: After Claude makes changes, run `swiftc -typecheck` on the file
2. **Build incrementally**: Fix one file at a time and verify before moving on
3. **Use Xcode for runtime debugging**: Command line is for compilation; use Xcode's debugger for runtime issues
4. **Check git status**: Before major changes, commit your working code
5. **Keep build logs**: The `build_output.log` file helps track progress

## Getting Help

If Claude Code doesn't understand an error:
1. Include the **full error message** with file path and line number
2. Show the **surrounding code context** (5-10 lines before/after)
3. Mention what you were trying to do when the error occurred
