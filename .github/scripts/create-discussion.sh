#!/bin/bash
set -e

NEW_THEMES="$1"
REPO_ID="$2"
CATEGORY_ID="$3"

for REPO in $NEW_THEMES; do
  echo "Processing theme: $REPO"

  # Fetch metadata.json using GitHub API (automatically uses default branch)
  METADATA=$(gh api "repos/${REPO}/contents/metadata.json" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo '{}')

  if [ "$METADATA" = "{}" ]; then
    echo "Could not fetch metadata for $REPO, skipping"
    continue
  fi

  TITLE=$(echo "$METADATA" | jq -r '.title // "Unknown Theme"')

  # Try to fetch DESCRIPTION.md first, fall back to metadata.json description
  DESCRIPTION_MD=$(gh api "repos/${REPO}/contents/DESCRIPTION.md" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo "")
  if [ -n "$DESCRIPTION_MD" ]; then
    DESCRIPTION="$DESCRIPTION_MD"
  else
    DESCRIPTION=$(echo "$METADATA" | jq -r '.description // "No description provided"')
  fi

  CREATORS=$(echo "$METADATA" | jq -r '.creators | join(", ") // "Unknown"')
  VERSION=$(echo "$METADATA" | jq -r '.version // "1.0.0"')
  TAGS=$(echo "$METADATA" | jq -r 'if .tags then .tags | join(", ") else "" end')
  HAS_SHADERS=$(echo "$METADATA" | jq -r '.hasShaders // false')
  FIRST_IMAGE=$(echo "$METADATA" | jq -r '.images[0] // empty')

  IMAGE_SECTION=""
  if [ -n "$FIRST_IMAGE" ]; then
    # Get default branch for raw URL
    DEFAULT_BRANCH=$(gh api "repos/${REPO}" --jq '.default_branch' 2>/dev/null || echo 'main')
    IMAGE_URL="https://raw.githubusercontent.com/${REPO}/${DEFAULT_BRANCH}/images/${FIRST_IMAGE}"
    IMAGE_SECTION="### Preview

![${TITLE}](${IMAGE_URL})

"
  fi

  TAGS_LINE=""
  if [ -n "$TAGS" ]; then
    TAGS_LINE="- **Tags**: ${TAGS}
"
  fi

  BODY="## ${TITLE}

${DESCRIPTION}

### Details

- **Repository**: [${REPO}](https://github.com/${REPO})
- **Creator(s)**: ${CREATORS}
- **Version**: ${VERSION}
- **Has Shaders**: ${HAS_SHADERS}
${TAGS_LINE}
${IMAGE_SECTION}---

Share your thoughts, feedback, or questions about this theme below!"

  gh api graphql \
    -f query='mutation($repositoryId: ID!, $categoryId: ID!, $title: String!, $body: String!) { createDiscussion(input: { repositoryId: $repositoryId, categoryId: $categoryId, title: $title, body: $body }) { discussion { url } } }' \
    -f repositoryId="$REPO_ID" \
    -f categoryId="$CATEGORY_ID" \
    -f title="[Theme] ${TITLE}" \
    -f body="$BODY"

  echo "Created discussion for: $TITLE"
done
