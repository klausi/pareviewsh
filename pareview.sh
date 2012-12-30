#!/bin/bash

## You need git + phpcs + coder 7.x-2.x.

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

  # Check if a default branch is checked out.
  BRANCH_NAME=`git branch`
  if [ -z "$BRANCH_NAME" ]; then
    echo "Git default branch is not set, see <a href=\"http://drupal.org/node/1659588\">the documentation on setting a default branch</a>."
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
    # first try 7.x-?.x
    BRANCH_NAME=`git branch -a | grep -o -E "7\.x-[0-9]\.x$" | tail -n1`
    if [ -n "$BRANCH_NAME" ]; then
      git checkout -q $BRANCH_NAME &> /dev/null
    else
      # try 6.x-?.x
      BRANCH_NAME=`git branch -a | grep -o -E "6\.x-[0-9]\.x$" | tail -n1`
      if [ -n "$BRANCH_NAME" ]; then
        git checkout -q $BRANCH_NAME &> /dev/null
      else
        BRANCH_NAME=`git rev-parse --abbrev-ref HEAD`
        echo "It appears you are working in the \"$BRANCH_NAME\" branch in git. You should really be working in a version specific branch. The most direct documentation on this is <a href=\"http://drupal.org/node/1127732\">Moving from a master branch to a version branch.</a> For additional resources please see the documentation about <a href=\"http://drupal.org/node/1015226\">release naming conventions</a> and <a href=\"http://drupal.org/node/1066342\">creating a branch in git</a>."
      fi
    fi
  fi
  if [ $BRANCH_NAME != "master" ]; then
    # Check that there is no master branch.
    MASTER_BRANCH=`git branch -a | grep -E "^  remotes/origin/master$"`
    if [ $? = 0 ]; then
      echo "There is still a master branch, make sure to set the correct default branch: http://drupal.org/node/1659588 . Then remove the master branch, see also step 6 and 7 in http://drupal.org/node/1127732"
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
    echo "The following git branches do not match the release branch pattern, you should remove/rename them. See http://drupal.org/node/1015226"
    echo "<code>"
    echo "$BRANCH_ERRORS"
    echo "</code>"
  fi
  echo "Review of the $BRANCH_NAME branch:"
fi

# get module/theme name
# if there is more than one info file we take the one with the shortest file name 
INFO_FILE=`ls *.info | awk '{ print length($0),$0 | "sort -n"}' | head -n1 | grep -o -E "[^[:space:]]*$"`
NAME=${INFO_FILE%.*}
PHP_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.test -or -name \*.profile`
NON_TPL_FILES=`find . -not \( -name \*.tpl.php \) -and \( -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.test -name \*.profile \)`
CODE_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.js -or -name \*.test`
TEXT_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.js -or -name \*.test -or -name \*.css -or -name \*.txt -or -name \*.info`
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
if [ ! -e README.txt ]; then
  echo "<li>README.txt is missing, see the <a href=\"http://drupal.org/node/447604\">guidelines for in-project documentation</a>.</li>"
fi
# LICENSE.txt present?
if [ -e LICENSE.txt ]; then
  echo "<li>Remove LICENSE.txt, it will be added by drupal.org packaging automatically.</li>"
fi
# translations folder present?
if [ -d translations ]; then
  echo "<li>Remove the translations folder, translations are done on http://localize.drupal.org</li>"
fi
# .DS_Store present?
CHECK_FILES=".DS_Store .project .settings"
for FILE in $CHECK_FILES; do
  FOUND=`find . -name $FILE`
  if [ -n "$FOUND" ]; then
    echo "<li>Remove all $FILE files from your repository.</li>"
  fi
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
BAD_LINES=`grep -l "^\?>" $NON_TPL_FILES`
if [ $? = 0 ]; then
  echo "<li>The \"?>\" PHP delimiter at the end of files is discouraged, see http://drupal.org/node/318#phptags"
  echo "<code>"
  echo "$BAD_LINES"
  echo "</code></li>"
fi
# Functions without module prefix.
# Exclude *.api.php and *.drush.inc files.
CHECK_FILES=`echo "$PHP_FILES" | grep -v -E "(api\.php|drush\.inc)$"`
for FILE in $CHECK_FILES; do
  FUNCTIONS=`grep -E "^function [[:alnum:]_]+.*\(.*\) \{" $FILE | grep -v -E "^function (_?$NAME|theme|template|phptemplate)"`
  if [ $? = 0 ]; then
    echo "<li>$FILE: all functions should be prefixed with your module/theme name to avoid name clashes. See http://drupal.org/node/318#naming"
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
  echo "<li>Bad line endings were found, always use unix style terminators. See http://drupal.org/coding-standards#indenting"
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

# run drupalcs
DRUPALCS=`phpcs --standard=Drupal --extensions=php,module,inc,install,test,profile,theme,js,css,info,txt .`
if [ $? = 1 ]; then
  echo "<li><a href=\"http://drupal.org/project/coder\">Coder Sniffer</a> has found some issues with your code (please check the <a href=\"http://drupal.org/node/318\">Drupal coding standards</a>). See attachment.</li>"
fi
echo "</ul>"

echo "<i>This automated report was generated with <a href=\"http://drupal.org/project/pareviewsh\">PAReview.sh</a>, your friendly project application review script. You can also use the <a href=\"http://ventral.org/pareview\">online version</a> to check your project. You have to get a <a href=\"http://drupal.org/node/1410826\">review bonus</a> to get a review from me.</i>"

if [[ -n "$DRUPALCS" ]]; then
  echo -e "\n\n\n"
  echo "<code>"
  if [ -n "$DRUPALCS" ]; then
    echo "$DRUPALCS"
  fi
  echo "</code>"
fi
