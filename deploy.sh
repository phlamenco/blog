#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project.
hugo # if using a theme, replace with `hugo -t <YOURTHEME>`

# Go To Public folder
cd public
# Add changes to git.
git add .

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# solve conflict
git branch temporary-work
git checkout temporary-work
git merge -s ours master
git checkout master
git merge --no-edit temporary-work

# Push source and build repos.
git push origin master

git branch -d temporary-work

# Come Back up to the Project Root
cd ..

git submodule update --init

git add .
git commit -m "update blog content"
git push origin master
