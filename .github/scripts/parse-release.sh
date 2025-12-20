#!/bin/bash
set -e

RELEASES_FILE="assets/releases.txt"

if [ ! -f "$RELEASES_FILE" ]; then
    echo "Error: $RELEASES_FILE not found"
    exit 1
fi

parse_latest_release() {
    local in_release=false
    local version=""
    local description=""
    local line_count=0
    
    while IFS= read -r line; do
        if [[ -z "$line" || "$line" =~ ^#[[:space:]]*$ ]]; then
            continue
        fi
        
        if [[ "$line" =~ ^#[[:space:]]*=---[[:space:]]*(.+)[[:space:]]*---= ]]; then
            if [ "$in_release" = false ]; then
                version="${BASH_REMATCH[1]}"
                version=$(echo "$version" | xargs)
                in_release=true
                continue
            fi
        fi
        
        if [[ "$line" =~ ^#[[:space:]]*=---[[:space:]]*END[[:space:]]*---= ]]; then
            if [ "$in_release" = true ]; then
                break
            fi
        fi
        
        if [ "$in_release" = true ]; then
            clean_line="${line#\# }"
            if [ -n "$description" ]; then
                description="$description"$'\n'"$clean_line"
            else
                description="$clean_line"
            fi
        fi
    done < "$RELEASES_FILE"
    
    echo "$version|$description"
}

latest_info=$(parse_latest_release)
latest_version=$(echo "$latest_info" | cut -d'|' -f1)
latest_description=$(echo "$latest_info" | cut -d'|' -f2-)

if [ -z "$latest_version" ]; then
    echo "Error: Could not parse latest release from $RELEASES_FILE"
    exit 1
fi

echo "Latest version in releases.txt: $latest_version"

if git rev-parse "$latest_version" >/dev/null 2>&1; then
    echo "Release $latest_version already exists"
    echo "new_release=false" >> $GITHUB_OUTPUT
    exit 0
fi

echo "New release detected: $latest_version"
echo "new_release=true" >> $GITHUB_OUTPUT
echo "version=$latest_version" >> $GITHUB_OUTPUT

{
    echo "description<<EOF"
    echo "$latest_description"
    echo "EOF"
} >> $GITHUB_OUTPUT

previous_commit=""
if [ -f "assets/installation.json" ]; then
    previous_commit=$(grep -oP '"commit":\s*"\K[^"]+' assets/installation.json | head -n 1)
fi

if [ -z "$previous_commit" ]; then
    previous_commit=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
fi

echo "previous_commit=$previous_commit" >> $GITHUB_OUTPUT
echo "Previous commit/tag: $previous_commit"