#!/bin/bash

PWD="$(echo $(pwd))"

if ! command -v zip > /dev/null;then
    echo "Please install zip (apt install zip)"
    exit 1
fi

read -p "Enter repo name: " REPO_NAME
read -p "Enter repo title: " REPO_TITLE

echo "User name can like mmar-json"
read -p "Enter user name: " USER_NAME
echo "User email should like mmar-json@users.noreply.github.com"
read -p "Enter user email: " USER_EMAIL

# generate.py
cat <<EOF >${PWD}/build/generate.py
import sys
import json
import os
from github import Github

# Configuration
REPO_NAME = "${REPO_NAME}"
REPO_TITLE = "${REPO_TITLE}"

# Skeleton for the repository
meta = {
    "name": REPO_TITLE,
    "last_update": "",
    "modules": []
}

# Initialize the GitHub objects
g = Github(os.environ['GIT_TOKEN'])
user = g.get_user(REPO_NAME)
repos = user.get_repos()

# Fetch the last repository update
meta["last_update"] = int(user.updated_at.timestamp() * 1000)

# Iterate over all public repositories
for repo in repos:
    # It is possible that module.prop does not exist (meta repo)
    try:
        # Parse module.prop into a python object
        moduleprop_raw = repo.get_contents("module.prop").decoded_content.decode("UTF-8")
        moduleprop = {}
        for line in moduleprop_raw.splitlines():
            if "=" not in line:
                continue
            lhs, rhs = line.split("=", 1)
            moduleprop[lhs] = rhs

        # Create meta module information
        module = {
            "id": moduleprop["id"],
            "last_update": int(repo.updated_at.timestamp() * 1000),
            "prop_url": f"https://raw.githubusercontent.com/{repo.full_name}/{repo.default_branch}/module.prop",
            "zip_url": f"https://github.com/{repo.full_name}/archive/{repo.default_branch}.zip",
            "notes_url": f"https://raw.githubusercontent.com/{repo.full_name}/{repo.default_branch}/README.md",
            "stars": int(repo.stargazers_count)
        }

        # Append to skeleton
        meta["modules"].append(module)
    except:
        continue

# Return our final skeleton
print(json.dumps(meta, indent=4, sort_keys=True))
EOF

# .github/workflows/generate.yml
cat <<EOF >${PWD}/build/.github/workflows/generate.yml
name: Generate JSON
on:
  push:
  workflow_dispatch:
  schedule:
    - cron: '0 * * * *'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - uses: actions/setup-python@v2
        with:
          python-version: '3.x'
          architecture: 'x64'

      - name: Setup Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install PyGithub

      - name: Generate JSON
        run: |
          export GIT_TOKEN="\${{ secrets.AUTH_KEY }}"
          python generate.py "\${{ secrets.GITHUB_TOKEN }}" > modules.json

      - name: Commit Changes
        run: |
          git config --global user.email "${USER_EMAIL}"
          git config --global user.name "${USER_NAME}"
          git add modules.json
          git commit -sm "Update modules.json" || true
          git push || true
EOF

cd ./build
file="../output/${REPO_NAME}.zip"
rm -f $file
zip -r $file * .[^.]*

echo "Your repo has been zipped saved in the output folder"
echo "Go to ${REPO_NAME} and create these env AUTH_KEY & GITHUB_TOKEN"
