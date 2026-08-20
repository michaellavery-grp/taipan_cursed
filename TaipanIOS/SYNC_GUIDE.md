# TaipanIOS Sync Guide

## Quick Reference for Future Updates

This guide explains how to sync your iOS development work from Desktop to the Git repository.

## The Sync Script

The `sync_ios_version.sh` script automates copying all iOS files from your Desktop development folder to the git repository.

### Location
```
/Users/michaellavery/github/taipan_cursed/TaipanIOS/sync_ios_version.sh
```

### What It Syncs

The script automatically copies:
- ✅ All Swift source files (`*.swift`)
- ✅ Xcode project (`TaipanCursed.xcodeproj`)
- ✅ Assets folder (`Assets.xcassets`)
- ✅ Test files (`test_*.swift`)
- ✅ Documentation files (`*.md` except README/CLAUDE)
- ✅ Build scripts (`*.sh`)

### Usage

**Dry Run (Preview Only)**
```bash
cd /Users/michaellavery/github/taipan_cursed/TaipanIOS
./sync_ios_version.sh --dry-run
```

**Actual Sync**
```bash
cd /Users/michaellavery/github/taipan_cursed/TaipanIOS
./sync_ios_version.sh
```

## Full Workflow for Updates

### Step 1: Develop on Desktop
```bash
# Work in your normal development location
cd /Users/michaellavery/Desktop/TaipanCursed
# Make changes, build, test in Xcode
```

### Step 2: Run Sync Script
```bash
cd /Users/michaellavery/github/taipan_cursed/TaipanIOS
./sync_ios_version.sh
```

### Step 3: Update Documentation
```bash
# Edit CLAUDE.md to add version notes
# Example: Add to "Version History & Release Notes" section
nano CLAUDE.md

# Update README.md if user instructions changed
nano README.md
```

### Step 4: Git Commit & Push
```bash
cd /Users/michaellavery/github/taipan_cursed

# Check what changed
git status

# Stage all changes
git add TaipanIOS/

# Commit with descriptive message
git commit -m "iOS v1.0.1 - Fix warehouse spoilage bug"

# Push to GitHub
git push origin main  # or your branch name
```

## Version Numbering

Follow semantic versioning: **MAJOR.MINOR.PATCH**

**Examples:**
- `v1.0.0` - Initial release
- `v1.0.1` - Bug fix (guns count)
- `v1.1.0` - New feature (Li Yuen encounters)
- `v2.0.0` - Major changes (complete UI redesign)

**When to increment:**
- **PATCH** (1.0.X): Bug fixes, typos, small corrections
- **MINOR** (1.X.0): New features, enhancements (backward compatible)
- **MAJOR** (X.0.0): Breaking changes, major rewrites

## Updating CLAUDE.md

Add a new section under "Version History & Release Notes":

```markdown
### vX.X.X - Feature Name (Month Day, Year)
**Status**: ✅ Complete | ⏳ In Progress | 🐛 Bug Fix

#### Changes
- Feature 1 description
- Feature 2 description

#### Files Modified
- `GameModel.swift` - What changed and why
- `SomeView.swift` - What changed and why

#### Testing
- [ ] Test case 1
- [ ] Test case 2
```

## Common Scenarios

### After Fixing a Bug
```bash
# 1. Fix bug in Desktop version
# 2. Test thoroughly
# 3. Run sync
./sync_ios_version.sh

# 4. Update CLAUDE.md with bug fix notes
# 5. Commit
git add -A
git commit -m "Bug fix: [describe bug] - iOS v1.0.X"
git push
```

### After Adding a Feature
```bash
# 1. Implement feature in Desktop version
# 2. Create test file (test_feature.swift)
# 3. Run sync
./sync_ios_version.sh

# 4. Update CLAUDE.md with feature notes
# 5. Update README.md if user-facing
# 6. Commit
git add -A
git commit -m "Feature: [describe feature] - iOS v1.X.0"
git push
```

### After Major Release
```bash
# 1. Complete all features for release
# 2. Update version in all documentation
# 3. Run sync
./sync_ios_version.sh

# 4. Create comprehensive release notes in CLAUDE.md
# 5. Update README.md with new features
# 6. Tag the release
git add -A
git commit -m "Release iOS v2.0.0 - [Major changes summary]"
git tag -a v2.0.0 -m "iOS Release 2.0.0 - [Description]"
git push origin main
git push origin v2.0.0
```

## Troubleshooting

### "Permission denied" when running script
```bash
chmod +x sync_ios_version.sh
```

### "Source folder not found"
Check that development folder exists:
```bash
ls -la /Users/michaellavery/Desktop/TaipanCursed
```

### Sync copied too much / not enough
Use `--dry-run` first to preview:
```bash
./sync_ios_version.sh --dry-run
```

### Want to sync only specific files
Edit the script or manually copy:
```bash
cp /Users/michaellavery/Desktop/TaipanCursed/TaipanCursed/GameModel.swift \
   /Users/michaellavery/github/taipan_cursed/TaipanIOS/TaipanCursed/
```

## Best Practices

1. **Always sync from Desktop → Git** (never the reverse!)
2. **Run dry-run first** if you've made major changes
3. **Update CLAUDE.md** every time you sync
4. **Commit frequently** with clear messages
5. **Tag releases** for version milestones
6. **Test before syncing** to avoid breaking the git version

## Quick Checklist

Before each sync:
- [ ] All changes tested and working
- [ ] Build succeeds in Xcode
- [ ] Test files pass (if applicable)
- [ ] Ready to commit

After each sync:
- [ ] Update CLAUDE.md with changes
- [ ] Update README.md if needed
- [ ] Review `git status` output
- [ ] Commit with descriptive message
- [ ] Push to GitHub

## Script Customization

To modify what gets synced, edit `sync_ios_version.sh`:

```bash
nano sync_ios_version.sh
```

**Example: Skip certain file types**
```bash
# Skip .md files
# Comment out or remove the documentation sync section (lines ~90-105)
```

**Example: Add new file type**
```bash
# Add JSON sync
for json_file in "$DESKTOP_PATH"/*.json; do
    if [[ -f "$json_file" ]]; then
        filename=$(basename "$json_file")
        copy_files "$json_file" "$GIT_PATH/" "$filename"
    fi
done
```

## Resources

- **Git Basics**: https://git-scm.com/doc
- **Semantic Versioning**: https://semver.org
- **Bash Scripting**: https://www.gnu.org/software/bash/manual/

---

**Questions?** Open an issue on GitHub!
**Happy Syncing!** 🚀
