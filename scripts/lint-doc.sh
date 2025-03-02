#!/usr/bin/env bash
set -o pipefail

cd "$(dirname "$0")/.." || exit 1
echo "=> Linting documents at path $(pwd) as $(whoami)..."
echo
ERRORCODE=0

# Use long options (e.g. --header instead of -H) for curl examples in documentation.
echo '=> Checking for cURL short options...'
echo
grep --extended-regexp --recursive --color=auto 'curl (.+ )?-[^- ].*' doc/ >/dev/null 2>&1
if [ $? -eq 0 ]
then
  echo '✖ ERROR: Short options for curl should not be used in documentation!
         Use long options (e.g., --header instead of -H):' >&2
  grep --extended-regexp --recursive --color=auto 'curl (.+ )?-[^- ].*' doc/
  ((ERRORCODE++))
fi

# Documentation pages need front matter for tracking purposes.
echo '=> Checking documentation for front matter...'
echo
if ! scripts/lint-docs-metadata.sh
then
  echo '✖ ERROR: These documentation pages need front matter. See https://docs.gitlab.com/ee/development/documentation/index.html#stage-and-group-metadata for how to add it.' >&2
  echo
  ((ERRORCODE++))
fi

# Test for non-standard spaces (NBSP, NNBSP, ZWSP) in documentation.
echo '=> Checking for non-standard spaces...'
echo
grep --extended-regexp --binary-file=without-match --recursive '[  ​]' doc/ >/dev/null 2>&1
if [ $? -eq 0 ]
then
  echo '✖ ERROR: Non-standard spaces (NBSP, NNBSP, ZWSP) should not be used in documentation.
         https://docs.gitlab.com/ee/development/documentation/styleguide/index.html#spaces-between-words
         Replace with standard spaces:' >&2
  # Find the spaces, then add color codes with sed to highlight each NBSP or NNBSP in the output.
  grep --extended-regexp --binary-file=without-match --recursive --color=auto '[  ]' doc \
       | sed -e ''/ /s//`printf "\033[0;101m \033[0m"`/'' -e ''/ /s//`printf "\033[0;101m \033[0m"`/''
  ((ERRORCODE++))
fi

# Ensure that the CHANGELOG.md does not contain duplicate versions
DUPLICATE_CHANGELOG_VERSIONS=$(grep --extended-regexp '^## .+' CHANGELOG.md | sed -E 's| \(.+\)||' | sort -r | uniq -d)
echo '=> Checking for CHANGELOG.md duplicate entries...'
echo
if [ "${DUPLICATE_CHANGELOG_VERSIONS}" != "" ]
then
  echo '✖ ERROR: Duplicate versions in CHANGELOG.md:' >&2
  echo "${DUPLICATE_CHANGELOG_VERSIONS}" >&2
  ((ERRORCODE++))
fi

# Make sure no files in doc/ are executable
EXEC_PERM_COUNT=$(find doc/ -type f -perm 755 | wc -l)
echo "=> Checking $(pwd)/doc for executable permissions..."
echo
if [ "${EXEC_PERM_COUNT}" -ne 0 ]
then
  echo '✖ ERROR: Executable permissions should not be used in documentation! Use `chmod 644` to the files in question:' >&2
  find doc/ -type f -perm 755
  ((ERRORCODE++))
fi

# Do not use 'README.md', instead use 'index.md'
# Number of 'README.md's as of 2021-08-17
NUMBER_READMES=0
FIND_READMES=$(find doc/ -name "README.md" | wc -l)
echo '=> Checking for new README.md files...'
echo
if [ ${FIND_READMES} -ne $NUMBER_READMES ]
then
  echo
  echo '  ✖ ERROR: The number of README.md file(s) has changed. Use index.md instead of README.md.' >&2
  echo '  ✖        If removing a README.md file, update NUMBER_READMES in lint-doc.sh.' >&2
  echo '  https://docs.gitlab.com/ee/development/documentation/site_architecture/folder_structure.html#work-with-directories-and-files' >&2
  echo
  ((ERRORCODE++))
fi

# Do not use dashes (-) in directory names, use underscores (_) instead.
# Number of directories with dashes as of 2021-09-17
NUMBER_DASHES=2
FIND_DASHES=$(find doc -type d -name "*-*" | wc -l)
echo '=> Checking for directory names containing dashes...'
echo
if [ ${FIND_DASHES} -ne $NUMBER_DASHES ]
then
  echo
  echo '  ✖ ERROR: The number of directory names containing dashes has changed. Use underscores instead of dashes for the directory names.' >&2
  echo '  ✖        If removing a directory containing dashes, update NUMBER_DASHES in lint-doc.sh.' >&2
  echo '  https://docs.gitlab.com/ee/development/documentation/site_architecture/folder_structure.html#work-with-directories-and-files' >&2
  echo
  ((ERRORCODE++))
fi

# Do not use uppercase letters in directory and file names, use all lowercase instead.
# (find always returns 0, so we use the grep hack https://serverfault.com/a/225827)
FIND_UPPERCASE_DIRS=$(find doc -type d -name "*[[:upper:]]*")
echo '=> Checking for directory names containing an uppercase letter...'
echo
if echo "${FIND_UPPERCASE_DIRS}" | grep . &>/dev/null
then
  echo '✖ ERROR: Found one or more directories with an uppercase letter in their name. Use lowercase instead of uppercase for the directory names.' >&2
  echo 'https://docs.gitlab.com/ee/development/documentation/site_architecture/folder_structure.html#work-with-directories-and-files' >&2
  echo
  echo "${FIND_UPPERCASE_DIRS}"
  echo
  ((ERRORCODE++))
fi
FIND_UPPERCASE_FILES=$(find doc -type f -name "*[[:upper:]]*.md")
echo '=> Checking for file names containing an uppercase letter...'
echo
if echo "${FIND_UPPERCASE_FILES}" | grep . &>/dev/null
then
  echo '✖ ERROR: Found one or more file names with an uppercase letter in their name. Use lowercase instead of uppercase for the file names.' >&2
  echo 'https://docs.gitlab.com/ee/development/documentation/site_architecture/folder_structure.html#work-with-directories-and-files' >&2
  echo
  echo "${FIND_UPPERCASE_FILES}"
  echo
  ((ERRORCODE++))
fi

# Run Vale and Markdownlint only on changed files. Only works on merged results
# pipelines, so first checks if a merged results CI variable is present. If not present,
# runs test on all files.
if [ -z "${CI_MERGE_REQUEST_TARGET_BRANCH_SHA}" ]
then
  MD_DOC_PATH=${MD_DOC_PATH:-doc}
  echo "Merge request pipeline (detached) detected. Testing all files."
else
  MERGE_BASE=$(git merge-base ${CI_MERGE_REQUEST_TARGET_BRANCH_SHA} ${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA})
  if git diff --diff-filter=d --name-only "${MERGE_BASE}..${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA}" | grep -E "\.vale|\.markdownlint|lint-doc\.sh|docs\.gitlab-ci\.yml"
  then
    MD_DOC_PATH=${MD_DOC_PATH:-doc}
    echo "Vale, Markdownlint, lint-doc.sh, or pipeline configuration changed. Testing all files."
  else
    MD_DOC_PATH=$(git diff --diff-filter=d --name-only "${MERGE_BASE}..${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA}" -- 'doc/*.md')
    if [ -n "${MD_DOC_PATH}" ]
    then
      echo -e "Merged results pipeline detected. Testing only the following files:\n${MD_DOC_PATH}"
    fi
  fi
fi

function run_locally_or_in_container() {
  local cmd=$1
  local args=$2
  local registry_url="registry.gitlab.com/gitlab-org/gitlab-docs/lint-markdown:alpine-3.16-vale-2.22.0-markdownlint-0.32.2-markdownlint2-0.6.0"

  if hash ${cmd} 2>/dev/null
  then
    $cmd $args
  # When using software like Rancher Desktop, both nerdctl and docker binaries are available
  # but only one is configured. To check which one to use, we need to probe each runtime
  elif (hash nerdctl 2>/dev/null) && (nerdctl info 2>&1 1>/dev/null)
  then
    nerdctl run -t -v "${PWD}:/gitlab" -w /gitlab --rm ${registry_url} ${cmd} ${args}
  elif (hash docker 2>/dev/null) && (docker info 2>&1 1>/dev/null)
  then
    docker run -t -v "${PWD}:/gitlab" -w /gitlab --rm ${registry_url} ${cmd} ${args}
  else
    echo
    echo "  ✖ ERROR: '${cmd}' not found. Install '${cmd}' or a container runtime (Docker/Nerdctl) to proceed." >&2
    echo
    ((ERRORCODE++))
  fi

  if [ $? -ne 0 ]
  then
    echo
    echo "  ✖ ERROR: '${cmd}' failed with errors." >&2
    echo
    ((ERRORCODE++))
  fi
}

echo '=> Linting markdown style...'
echo
if [ -z "${MD_DOC_PATH}" ]
then
  echo "Merged results pipeline detected, but no markdown files found. Skipping."
else
  yarn markdownlint --config .markdownlint.yml ${MD_DOC_PATH} --rules doc/.markdownlint/rules

  if [ $? -ne 0 ]
  then
    echo
    echo '✖ ERROR: Markdownlint failed with errors.' >&2
    echo
    ((ERRORCODE++))
  fi
fi

echo '=> Linting prose...'
run_locally_or_in_container 'vale' "--minAlertLevel error --output=doc/.vale/vale.tmpl ${MD_DOC_PATH}"

if [ $ERRORCODE -ne 0 ]
then
  echo "✖ ${ERRORCODE} lint test(s) failed. Review the log carefully to see full listing."
  exit 1
else
  echo "✔ Linting passed"
  exit 0
fi
