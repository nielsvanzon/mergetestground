#!/bin/bash

# check for the correct number of arguments
if [ ! $# == 2 ]; then
	echo "use: $0 base_branch target_branch"
	exit
fi

# check for a clean working directory 
if [ -z "$(git status --porcelain)" ]; then 
  	echo "Working directory is clean, continuing..."
else
	echo "Unclean working directory, exiting..."
	exit
fi

BASE_BRANCH=$1
TARGET_BRANCH=$2

# get locally up to date versions of the base and target branches
echo "Fetching updates..."
git fetch --all
echo "Checking out target branch $TARGET_BRANCH..." 
git checkout $TARGET_BRANCH
git pull
echo "Checking out base branch $TARGET_BRANCH..." 
git checkout $BASE_BRANCH
git pull

# searches within the commit difference between the base and target branches the commits with #skipMerge in their commit message
SKIPMERGES="$(git log --reverse --pretty=format:"%H" -i --grep="#skipMerge" $BASE_BRANCH..$TARGET_BRANCH)"

echo "Found ${#SKIPMERGES[@]} skipmerge(s)..."

# for each skip commit found do the following
for i in ${SKIPMERGES[@]}; do

	# find the commit just above the skip merge commit
	BEFORE_SKIP_COMMIT=$(git log ${i}^ -n 1 --pretty=format:"%H")
	# store the skip merge commit hash
	SKIP_COMMIT=${i}

	# do a default merge with the before skip commit
	echo "Merging commit before skip '$BEFORE_SKIP_COMMIT' into '$BASE_BRANCH' with 'default' strategy..."
	git merge $BEFORE_SKIP_COMMIT -m "Merge '$BEFORE_SKIP_COMMIT' into '$BASE_BRANCH'"

	# check for merge conflicts
	if [ -z "$(git status --porcelain)" ]; then 
		echo "Merging before skip commit successful, continuing..."
	else
		echo "Merging before skip commit unsuccessful, breaking for loop..."
		MERGE_CONFLICT_COMMIT=$BEFORE_SKIP_COMMIT
		break
	fi

	# do an ours merge to skip changes with the skip commit
	echo "Merging skip commit '$SKIP_COMMIT' into '$BASE_BRANCH' with 'ours' strategy..."
	git merge $SKIP_COMMIT -s ours -m "Merge '$SKIP_COMMIT' into '$BASE_BRANCH' without changes"

done

# if there where no conflicts so far continue
if [ "$MERGE_CONFLICT_COMMIT" == "" ]; then

	# just an extra message for if there where skip related merges
	if [ ${#SKIPMERGES[@]} -ge 1 ]; then
		echo "Merged all skip related merges successfully, continuing..."
	fi

	echo "Merging '$TARGET_BRANCH' branch into '$BASE_BRANCH' branch..."
	git merge $TARGET_BRANCH

	# check for merge conflicts
	if [ -z "$(git status --porcelain)" ]; then 
		echo "Merging '$TARGET_BRANCH' branch successfully, continuing..."
	else
		echo "Merging '$TARGET_BRANCH' branch unsuccessfully, continuing..."
		MERGE_CONFLICT_COMMIT=$(git log $TARGET_BRANCH -n 1 --pretty=format:"%H")
		break
	fi
fi

# final check for merge conflicts
if [ "$MERGE_CONFLICT_COMMIT" == "" ]; then
	echo "Everything successfully completed, exiting..."
else
	# report on the failed commit
	echo "Merging failed on commit '$MERGE_CONFLICT_COMMIT', exiting..."
fi
