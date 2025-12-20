#!/bin/bash
set -e

VERSION="$1"
DESCRIPTION="$2"
PREVIOUS_COMMIT="$3"

if [ -z "$VERSION" ]; then
    echo "Error: VERSION not provided"
    exit 1
fi

RELEASE_NOTES="release-notes.md"

{
    echo "$DESCRIPTION"
    echo ""
    
    if [ -n "$PREVIOUS_COMMIT" ]; then
        echo "---"
        echo ""
        echo "## Commit History"
        echo ""
        
        if git rev-parse "$PREVIOUS_COMMIT" >/dev/null 2>&1; then
            echo "### Changes since $PREVIOUS_COMMIT"
            echo ""
            git log --pretty=format:"- %s (\`%h\`)" "$PREVIOUS_COMMIT"..HEAD
        else
            echo "### Full commit history"
            echo ""
            git log --pretty=format:"- %s (\`%h\`)" --max-count=50
        fi
        
        echo ""
    fi
} > "$RELEASE_NOTES"

echo "Release notes generated in $RELEASE_NOTES"
cat "$RELEASE_NOTES"