#!/bin/bash
# sync_ios_version.sh - Sync iOS version from Desktop to Git repo
# Usage: ./sync_ios_version.sh [--dry-run]
#
# This script syncs the TaipanCursed iOS development version from
# /Users/michaellavery/Desktop/TaipanCursed to the git repo at
# /Users/michaellavery/github/taipan_cursed/TaipanIOS

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
DESKTOP_PATH="/Users/michaellavery/Desktop/TaipanCursed"
GIT_PATH="/Users/michaellavery/github/taipan_cursed/TaipanIOS"

# Check if dry run
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🔍 DRY RUN MODE - No files will be copied${NC}\n"
fi

# Verify source exists
if [[ ! -d "$DESKTOP_PATH" ]]; then
    echo -e "${RED}❌ Error: Desktop TaipanCursed not found at $DESKTOP_PATH${NC}"
    exit 1
fi

# Verify git repo exists
if [[ ! -d "$GIT_PATH" ]]; then
    echo -e "${YELLOW}⚠️  Git TaipanIOS folder not found. Creating...${NC}"
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$GIT_PATH/TaipanCursed"
    fi
fi

echo -e "${BLUE}📱 TaipanIOS Sync Utility${NC}"
echo -e "${BLUE}========================${NC}\n"

# Function to copy files
copy_files() {
    local source=$1
    local dest=$2
    local description=$3

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would copy: $description"
        echo -e "  From: $source"
        echo -e "  To:   $dest"
    else
        echo -e "${GREEN}✓${NC} Copying: $description"
        cp -r "$source" "$dest"
    fi
}

# 1. Sync Swift source files
echo -e "${BLUE}📝 Syncing Swift source files...${NC}"
if [[ -d "$DESKTOP_PATH/TaipanCursed" ]]; then
    copy_files "$DESKTOP_PATH/TaipanCursed/*.swift" "$GIT_PATH/TaipanCursed/" "All .swift files"
else
    echo -e "${RED}❌ Source folder not found: $DESKTOP_PATH/TaipanCursed${NC}"
    exit 1
fi

# 2. Sync Assets
echo -e "\n${BLUE}🎨 Syncing Assets...${NC}"
if [[ -d "$DESKTOP_PATH/TaipanCursed/Assets.xcassets" ]]; then
    copy_files "$DESKTOP_PATH/TaipanCursed/Assets.xcassets" "$GIT_PATH/TaipanCursed/" "Assets.xcassets"
else
    echo -e "${YELLOW}⚠️  No Assets.xcassets found (may be expected)${NC}"
fi

# 3. Sync Xcode project
echo -e "\n${BLUE}📦 Syncing Xcode project...${NC}"
if [[ -d "$DESKTOP_PATH/TaipanCursed.xcodeproj" ]]; then
    copy_files "$DESKTOP_PATH/TaipanCursed.xcodeproj" "$GIT_PATH/" "TaipanCursed.xcodeproj"
else
    echo -e "${RED}❌ Xcode project not found: $DESKTOP_PATH/TaipanCursed.xcodeproj${NC}"
    exit 1
fi

# 4. Sync test files
echo -e "\n${BLUE}🧪 Syncing test files...${NC}"
TEST_FILES_FOUND=false
for test_file in "$DESKTOP_PATH"/test_*.swift; do
    if [[ -f "$test_file" ]]; then
        TEST_FILES_FOUND=true
        filename=$(basename "$test_file")
        copy_files "$test_file" "$GIT_PATH/" "$filename"
    fi
done

if [[ "$TEST_FILES_FOUND" == false ]]; then
    echo -e "${YELLOW}⚠️  No test_*.swift files found${NC}"
fi

# 5. Sync documentation files
echo -e "\n${BLUE}📚 Syncing documentation files...${NC}"
DOC_FILES_FOUND=false
for doc_file in "$DESKTOP_PATH"/*.md; do
    if [[ -f "$doc_file" ]]; then
        DOC_FILES_FOUND=true
        filename=$(basename "$doc_file")
        # Skip README.md and CLAUDE.md (managed separately)
        if [[ "$filename" != "README.md" && "$filename" != "CLAUDE.md" ]]; then
            copy_files "$doc_file" "$GIT_PATH/" "$filename"
        fi
    fi
done

if [[ "$DOC_FILES_FOUND" == false ]]; then
    echo -e "${YELLOW}⚠️  No .md documentation files found${NC}"
fi

# 6. Sync build scripts (if any)
echo -e "\n${BLUE}🔧 Syncing build scripts...${NC}"
SCRIPT_FILES_FOUND=false
for script_file in "$DESKTOP_PATH"/*.sh; do
    if [[ -f "$script_file" ]]; then
        SCRIPT_FILES_FOUND=true
        filename=$(basename "$script_file")
        # Skip this sync script itself
        if [[ "$filename" != "sync_ios_version.sh" ]]; then
            copy_files "$script_file" "$GIT_PATH/" "$filename"
        fi
    fi
done

if [[ "$SCRIPT_FILES_FOUND" == false ]]; then
    echo -e "${YELLOW}⚠️  No .sh script files found${NC}"
fi

# Summary
echo -e "\n${GREEN}✅ Sync Complete!${NC}\n"

if [[ "$DRY_RUN" == false ]]; then
    echo -e "${BLUE}📊 Summary:${NC}"
    echo -e "  Source: $DESKTOP_PATH"
    echo -e "  Destination: $GIT_PATH"
    echo -e "\n${YELLOW}💡 Next Steps:${NC}"
    echo -e "  1. cd $GIT_PATH"
    echo -e "  2. git status  # Review changes"
    echo -e "  3. git add -A  # Stage all changes"
    echo -e "  4. git commit -m \"Update iOS version vX.X.X - [description]\"  # Commit"
    echo -e "  5. git push  # Push to GitHub"
    echo -e "\n${BLUE}📝 Don't forget to update:${NC}"
    echo -e "  - CLAUDE.md with version notes"
    echo -e "  - README.md if user instructions changed"
else
    echo -e "${YELLOW}ℹ️  This was a dry run. Run without --dry-run to actually copy files.${NC}"
fi

echo ""
