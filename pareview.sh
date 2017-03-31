#! /usr/bin/env bash

## You need git + phpcs + coder 8.x-2.x + eslint + codespell

if [[ $# -lt 1 || $1 == "--help" || $1 == "-h" ]]
then
  echo "Usage:    `basename $0` GIT-URL [BRANCH]"
  echo "          `basename $0` DIR-PATH"
  echo "Examples:"
  echo "  `basename $0` http://git.drupal.org/project/rules.git"
  echo "  `basename $0` http://git.drupal.org/project/rules.git 6.x-1.x"
  echo "  `basename $0` sites/all/modules/rules"
  exit
fi

# Get the directory pareview.sh is stored in to access config files such as
# eslint.json later.
SOURCE="${BASH_SOURCE[0]}"
# resolve $SOURCE until the file is no longer a symlink
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
PAREVIEWSH_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


# check if the first argument is valid directory.
if [ -d $1 ]; then
 cd $1
# otherwise treat the user input as git URL.
else
  if [ -d pareview_temp ]; then
    # clean up test dir
    rm -rf pareview_temp
  else
    mkdir pareview_temp
  fi

  # clone project quietly
  git clone -q $1 pareview_temp &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Git clone failed. Aborting."
    exit 1
  fi
  cd pareview_temp

  # Check if the repository is empty.
  BRANCH_EXISTS=`git branch -a`
  if [ -z "$BRANCH_EXISTS" ]; then
    echo "Git repository is empty. Aborting."
    exit 1
  fi

  GIT_ERRORS=()

  # Check if a default branch is checked out.
  BRANCH_NAME=`git branch`
  if [ -z "$BRANCH_NAME" ]; then
    GIT_ERRORS+=("Git default branch is not set, see <a href=\"https://www.drupal.org/node/1659588\">the documentation on setting a default branch</a>.")
  fi

  # checkout branch
  # check if a branch name was passed on the command line
  if [ $2 ]; then
    BRANCH_NAME=$2
    git checkout -q $BRANCH_NAME &> /dev/null
    if [ $? = 1 ]; then
      echo "Git checkout of branch $BRANCH_NAME failed. Aborting."
      exit 1
    fi
  else
    # First try ?.x-?.x. We want to get the highest core compatibility number,
    # i.e. 8.x-1.x before 7.x-1.x. So we take the last match.
    BRANCH_NAME=`git branch -a | grep -o -E "[0-9]\.x-[0-9]\.x$" | tail -n1`
    if [ -n "$BRANCH_NAME" ]; then
      git checkout -q $BRANCH_NAME &> /dev/null
    else
      # Exclude branch lines that have "->" pointing to HEAD or whatever.
      BRANCH_NAME=`git branch -a | grep -v -- "->" | sed -e 's/ *remotes\/origin\///p' | tail -n1`
      GIT_ERRORS+=("It appears you are working in the \"$BRANCH_NAME\" branch in git. You should really be working in a version specific branch. The most direct documentation on this is <a href=\"https://www.drupal.org/node/1127732\">Moving from a master branch to a version branch.</a> For additional resources please see the documentation about <a href=\"https://www.drupal.org/node/1015226\">release naming conventions</a> and <a href=\"https://www.drupal.org/node/1066342\">creating a branch in git</a>.")
    fi
  fi
  if [ $BRANCH_NAME != "master" ]; then
    # Check that there is no master branch.
    MASTER_BRANCH=`git branch -a | grep -E "^  remotes/origin/master$"`
    if [ $? = 0 ]; then
      GIT_ERRORS+=("There is still a master branch, make sure to set the correct default branch: https://www.drupal.org/node/1659588 . Then remove the master branch, see also step 6 and 7 in https://www.drupal.org/node/1127732")
    fi
    git checkout -q $BRANCH_NAME &> /dev/null
  fi
  TAG_CLASH=`git tag -l | grep $BRANCH_NAME`
  if [ $? = 0 ]; then
    echo "There is a git tag that has the same name as the branch $BRANCH_NAME. Make sure to remove this tag to avoid confusion."
    exit 1
  fi
  # Check that no branch patterns with the suffix "dev" are used.
  # Check also that no tag name patterns are used as branches.
  BRANCH_ERRORS=`git branch -a | grep -E "([0-9]\.x-[0-9]\.x-dev$|[0-9]\.[0-9]-[0-9]\.x$|[0-9]\.x-[0-9]\.[0-9]$|[0-9]\.[0-9]-[0-9]\.[0-9]$)"`
  if [ $? = 0 ]; then
    GIT_ERRORS+=("The following git branches do not match the release branch pattern, you should remove/rename them. See https://www.drupal.org/node/1015226\n<code>\n$BRANCH_ERRORS\n</code>")
  fi

  # Check that the last commit message is not just one word.
  COMMIT_MESSAGE=`git log -1 --pretty=%B`
  if [[ $COMMIT_MESSAGE != *" "* ]]; then
    GIT_ERRORS+=("The last commit message is just one word, you should provide a meaningful short summary what you changed. See https://www.drupal.org/node/52287")
  fi

  if [ ${#GIT_ERRORS[@]} -gt 0 ]; then
    echo "Git errors:"
    echo "<ul>"
    for ((i = 0; i < ${#GIT_ERRORS[@]}; i++)); do
      echo -e "<li>${GIT_ERRORS[i]}</li>"
    done
    echo "</ul>"
  fi

  BRANCH_VERSION=`git rev-parse --short HEAD`
  echo "Review of the $BRANCH_NAME branch (commit $BRANCH_VERSION):"
fi

# Get module/theme name.
# If there is more than one info file we take the one with the shortest file
# name. We look for *.info (Drupal 7) and *.info.yml (Drupal 8) files.
INFO_FILE=`ls | grep '\.info\(\.yml\)\?$' | awk '{ print length($0),$0 | "sort -n"}' | head -n1 | grep -o -E "[^[:space:]]*$"`
NAME=${INFO_FILE%%.*}
PHP_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.test -or -name \*.profile`
NON_TPL_FILES=`find . -not \( -name \*.tpl.php \) -and \( -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.test -name \*.profile \)`
CODE_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.js -or -name \*.test`
TEXT_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.js -or -name \*.test -or -name \*.css -or -name \*.txt -or -name \*.info -or -name \*.yml`
FILES=`find . -path ./.git -prune -o -type f -print`
INFO_FILES=`find . -name \*.info`
# ensure $PHP_FILES is not empty
if [ -z "$PHP_FILES" ]; then
  # just set it to the current directory.
  PHP_FILES="."
  CODE_FILES="."
  NON_TPL_FILES="."
fi
echo "<ul>"

# README.txt present?
if [ ! -e README.txt ] && [ ! -e README.md ] ; then
  echo "<li>README.md or README.txt is missing, see the <a href=\"https://www.drupal.org/node/447604\">guidelines for in-project documentation</a>.</li>"
fi
# There should be only one README file either *.md or *.txt, not both.
if [ -e README.txt ] && [ -e README.md ] ; then
  echo "<li>There should be only one README file, either README.md or README.txt.</li>"
fi
# LICENSE.txt present?
if [ -e LICENSE.txt ]; then
  echo "<li>Remove LICENSE.txt, it will be added by drupal.org packaging automatically.</li>"
fi
if [ -e LICENSE ]; then
  echo "<li>Remove the LICENSE, drupal.org packaging will add a LICENSE.txt file automatically.</li>"
fi
# translations folder present?
if [ -d translations ]; then
  echo "<li>Remove the translations folder, translations are done on http://localize.drupal.org</li>"
fi
# .DS_Store present?
CHECK_FILES=".DS_Store .idea node_modules .project .sass-cache .settings vendor"
for FILE in $CHECK_FILES; do
  FOUND=`find . -name $FILE`
  if [ -n "$FOUND" ]; then
    echo "<li>Remove all $FILE files from your repository.</li>"
  fi
done
# Backup files present?
BACKUP=`find . -name "*~"`
if [ ! -z "$BACKUP" ]; then
  echo "<li>Remove all backup files from your repository:"
  echo "<code>"
  echo "$BACKUP"
  echo "</code></li>"
fi
# Font files present?
FONT_FILES=`find . -iname \*.ttf`
for FILE in $FONT_FILES; do
  echo "<li>$FILE appears to be a font file. It must be removed if you are not its author, tell users where to download it instead. See drupal.org's policy regarding 3rd party files: https://www.drupal.org/node/422996</li>"
done

for FILE in $INFO_FILES; do
  # "version" in info file?
  grep -q -e "version[[:space:]]*=[[:space:]]*" $FILE
  if [ $? = 0 ]; then
    echo "<li>Remove \"version\" from the $FILE file, it will be added by drupal.org packaging automatically.</li>"
  fi
  # "project" in info file?
  grep -q -e "project[[:space:]]*=[[:space:]]*" $FILE
  if [ $? = 0 ]; then
    echo "<li>Remove \"project\" from the $FILE file, it will be added by drupal.org packaging automatically.</li>"
  fi
  # "datestamp" in info file?
  grep -q -e "datestamp[[:space:]]*=[[:space:]]*" $FILE
  if [ $? = 0 ]; then
    echo "<li>Remove \"datestamp\" from the $FILE file, it will be added by drupal.org packaging automatically.</li>"
  fi
done

# ?> PHP delimiter at the end of any file?
BAD_LINES=`grep -l "^\?>" $NON_TPL_FILES 2> /dev/null`
if [ $? = 0 ]; then
  echo "<li>The \"?>\" PHP delimiter at the end of files is discouraged, see https://www.drupal.org/node/318#phptags"
  echo "<code>"
  echo "$BAD_LINES"
  echo "</code></li>"
fi
# Functions without module prefix.
# Exclude *.api.php and *.drush.inc files.
CHECK_FILES=`echo "$PHP_FILES" | grep -v -E "(api\.php|drush\.inc)$"`
for FILE in $CHECK_FILES; do
  FUNCTIONS=`grep -E "^function [[:alnum:]_]+.*\(.*\) \{" $FILE 2> /dev/null | grep -v -E "^function (_?$NAME|theme|template|phptemplate)"`
  if [ $? = 0 ]; then
    echo "<li>$FILE: all functions should be prefixed with your module/theme name to avoid name clashes. See https://www.drupal.org/node/318#naming"
    echo "<code>"
    echo "$FUNCTIONS"
    echo "</code></li>"
  fi
done
# bad line endings in files
BAD_LINES1=`file $FILES | grep "line terminators"`
# the "file" command does not detect bad line endings in HTML style files, so
# we run this grep command in addition.
BAD_LINES2=`grep -rlI $'\r' *`
if [ -n "$BAD_LINES1" ] || [ -n "$BAD_LINES2" ]; then
  echo "<li>Bad line endings were found, always use unix style terminators. See https://www.drupal.org/coding-standards#indenting"
  echo "<code>"
  echo "$BAD_LINES1"
  echo "$BAD_LINES2"
  echo "</code></li>"
fi
# old CVS $Id$ tags
BAD_LINES=`grep -rnI "\\$Id" *`
if [ $? = 0 ]; then
  echo "<li>Remove all old CVS \$Id tags, they are not needed anymore."
  echo "<code>"
  echo "$BAD_LINES"
  echo "</code></li>"
fi
# PHP parse error check
for FILE in $PHP_FILES; do
  ERRORS=`php -l $FILE 2>&1`
  if [ $? -ne 0 ]; then
    echo "<li>$ERRORS</li>"
  fi
done
# \feff character check at the beginning of files.
for FILE in $TEXT_FILES; do
  ERRORS=`grep ^$'\xEF\xBB\xBF' $FILE`
  if [ $? = 0 ]; then
    echo "<li>$FILE: the byte order mark at the beginning of UTF-8 files is discouraged, you should remove it.</li>"
  fi
done

# Run drupalcs.
# If the project contains SCSS files then we don't check the included CSS files
# because they are probably generated.
SCSS_FILES=`find . -path ./.git -prune -o -type f -name \*.scss -print`
if [ -z "$SCSS_FILES" ]; then
  DRUPALCS=`phpcs --standard=Drupal --report-width=74 --extensions=php,module,inc,install,test,profile,theme,css,info,txt,md,yml . 2>&1`
else
  DRUPALCS=`phpcs --standard=Drupal --report-width=74 --extensions=php,module,inc,install,test,profile,theme,info,txt,md,yml . 2>&1`
fi
DRUPALCS_ERRORS=$?
if [ $DRUPALCS_ERRORS -gt 0 ]; then
  LINES=`echo "$DRUPALCS" | wc -l`
  if [ $LINES -gt 20 ]; then
    echo "<li><a href=\"https://www.drupal.org/project/coder\">Coder Sniffer</a> has found some issues with your code (please check the <a href=\"https://www.drupal.org/node/318\">Drupal coding standards</a>). See attachment.</li>"
  else
    echo "<li><a href=\"https://www.drupal.org/project/coder\">Coder Sniffer</a> has found some issues with your code (please check the <a href=\"https://www.drupal.org/node/318\">Drupal coding standards</a>)."
    echo "<code>"
    echo "$DRUPALCS"
    echo "</code></li>"
    DRUPALCS_ERRORS=0
  fi
fi

# Check if eslint is installed.
hash eslint 2>/dev/null
if [ $? = 0 ]; then
  # Run eslint.
  ESLINT=`eslint --config $PAREVIEWSH_DIR/eslint.json --format compact . 2>&1`
  ESLINT_ERRORS=$?
  if [ $ESLINT_ERRORS -gt 0 ]; then
    LINES=`echo "$ESLINT" | wc -l`
    if [ $LINES -gt 20 ]; then
      echo "<li><a href=\"http://eslint.org/\">ESLint</a> has found some issues with your code (please check the <a href=\"https://www.drupal.org/node/172169\">JavaScript coding standards</a>). See attachment.</li>"
    else
      echo "<li><a href=\"http://eslint.org/\">ESLint</a> has found some issues with your code (please check the <a href=\"https://www.drupal.org/node/172169\">JavaScript coding standards</a>)."
      echo "<code>"
      echo "$ESLINT"
      echo "</code></li>"
      ESLINT_ERRORS=0
    fi
  fi
fi

# Run DrupalPractice
DRUPALPRACTICE=`phpcs --standard=DrupalPractice --report-width=74 --extensions=php,module,inc,install,test,profile,theme,yml . 2>&1`
if [ "$?" -gt 0 ]; then
  echo "<li><a href=\"https://www.drupal.org/project/drupalpractice\">DrupalPractice</a> has found some issues with your code, but could be false positives."
  echo "<code>"
  echo "$DRUPALPRACTICE"
  echo "</code></li>"
fi

# Run DrupalSecure and ignore stderr because it sometimes throws PHP warnings.
DRUPALSECURE=`phpcs --standard=DrupalSecure --report-width=74 --extensions=php,module,inc,install,test,profile,theme . 2> /dev/null`
if [ $? = 1 ]; then
  echo "<li><a href=\"https://www.drupal.org/sandbox/coltrane/1921926\">DrupalSecure</a> has found some issues with your code (please check the <a href=\"https://www.drupal.org/writing-secure-code\">Writing secure core</a> handbook)."
  echo "<code>"
  echo "$DRUPALSECURE"
  echo "</code></li>"
fi

# Check if codespell is installed.
hash codespell 2>/dev/null
if [ $? = 0 ]; then
  # Run codespell. Ignore *.lock files because they are generated.
  SPELLING=`codespell --disable-colors --skip "*.lock" 2>/dev/null`
  if [ ! -z "$SPELLING" ]; then
    echo "<li><a href=\"https://github.com/lucasdemarchi/codespell\">Codespell</a> has found some spelling errors in your code."
    echo "<code>"
    echo "$SPELLING"
    echo "</code></li>"
  fi
fi

# Check if the project contains automated tests.
D7_TEST_FILES=`find . -name \*\.test`
D8_TEST_DIRS=`find . -type d \( -iname test -or -iname tests \)`
# Do not throw this error for themes, they usually don't have tests.
if [ -z "$D7_TEST_FILES" ] && [ -z "$D8_TEST_DIRS" ] && [ ! -e template.php ] && [ ! -e *.theme ] ; then
  echo "<li>No automated test cases were found, did you consider writing <a href=\"https://www.drupal.org/simpletest\">Simpletests</a> or <a href=\"https://www.drupal.org/phpunit\">PHPUnit tests</a>? This is not a requirement but encouraged for professional software development.</li>"
fi

echo "</ul>"

echo "<i>This automated report was generated with <a href=\"https://www.drupal.org/project/pareviewsh\">PAReview.sh</a>, your friendly project application review script. You can also use the <a href=\"http://pareview.sh\">online version</a> to check your project. You have to get a <a href=\"https://www.drupal.org/node/1975228\">review bonus</a> to get a review from me.</i>"

if [[ $DRUPALCS_ERRORS -gt 0 ]]; then
  echo -e "\n\n\n"
  echo "<code>"
  if [ -n "$DRUPALCS" ]; then
    echo "$DRUPALCS"
  fi
  echo "</code>"
fi

if [[ $ESLINT_ERRORS = 1 ]]; then
  echo -e "\n\n\n"
  echo "<code>"
  if [ -n "$ESLINT" ]; then
    echo "$ESLINT"
  fi
  echo "</code>"
fi
