#!/bin/bash

## You need a Drupal installation + git + drupalcs + drush + coder_review enabled.
## This script must be run from somewhere in your Drupal installation.

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

DRUPAL_ROOT=`drush status --pipe drupal_root`

if [ ! -d $DRUPAL_ROOT/sites/all/modules ]; then
  if [ ! -d $DRUPAL_ROOT/sites/all ]; then
    echo "Directory $DRUPAL_ROOT/sites/all not found, please make sure that you run this script in a Drupal installation. Aborting."
    exit 1
  else
    mkdir $DRUPAL_ROOT/sites/all/modules
  fi
fi

# check if the first argument is valid directory.
if [ -d $1 ]; then
 cd $1
# otherwise treat the user input as git URL.
else
  if [ -d $DRUPAL_ROOT/sites/all/modules/pareview_temp ]; then
    # clean up test dir
    rm -rf $DRUPAL_ROOT/sites/all/modules/pareview_temp/*
  else
    mkdir $DRUPAL_ROOT/sites/all/modules/pareview_temp
  fi

  cd $DRUPAL_ROOT/sites/all/modules/pareview_temp
  # clone project quietly
  git clone -q $1 test_candidate &> /dev/null
  if [ $? -ne 0 ]; then
    echo "Git clone failed. Aborting."
    exit 1
  fi
  cd test_candidate

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
    # Check that the master branch is empty.
    git checkout -q master &> /dev/null
    if [ $? = 0 ]; then
      FILES_IN_MASTER=`ls | grep -v -E "^README.txt$"`
      if [ $? = 0 ]; then
        echo "There are still files other than README.txt in the master branch, make sure to remove them. See also step 5 in http://drupal.org/node/1127732"
      fi
    fi
    git checkout -q $BRANCH_NAME &> /dev/null
  fi
  echo "Review of the $BRANCH_NAME branch:"
fi

# get module/theme name
# if there is more than one info file we take the one with the shortest file name 
INFO_FILE=`ls *.info | awk '{ print length($0),$0 | "sort -n"}' | head -n1 | grep -o -E "[^[:space:]]*$"`
NAME=${INFO_FILE%.*}
PHP_FILES=`find . -not \( -name \*.tpl.php \) -and \( -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.test \)`
CODE_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.js -or -name \*.test`
TEXT_FILES=`find . -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install -or -name \*.js -or -name \*.test -or -name \*.css -or -name \*.txt -or -name \*.info`
FILES=`find . -path ./.git -prune -o -type f -print`
# ensure $PHP_FILES is not empty
if [ -z "$PHP_FILES" ]; then
  # just set it to the current directory.
  PHP_FILES="."
  CODE_FILES="."
fi

# coder is not very good at detecting files in directories.
if [ -e $NAME.module ]; then
  CODER_PATH=sites/all/modules/pareview_temp/test_candidate/$NAME.module
else
  CODER_PATH=sites/all/modules/pareview_temp/test_candidate
fi
echo "<ul>"
# run coder
CODER=`drush coder-review no-empty minor comment i18n security sql style $CODER_PATH`
echo $CODER | grep -q "+"
if [ $? = 0 ]; then
  echo "<li>Run <a href=\"http://drupal.org/project/coder\">coder</a> to check your style, some issues were found (please check the <a href=\"http://drupal.org/node/318\">Drupal coding standards</a>):"
  echo "<code>"
  echo "$CODER"
  echo "</code></li>"
fi

# run drupalcs
DRUPALCS=`phpcs --standard=DrupalCodingStandard --extensions=php,module,inc,install,test,profile,theme,js,txt .`
if [ $? = 1 ]; then
  echo "<li><a href=\"http://drupal.org/project/drupalcs\">Drupal Code Sniffer</a> has found some code style issues (please check the <a href=\"http://drupal.org/node/318\">Drupal coding standards</a>):"
  echo "<code>"
  echo "$DRUPALCS"
  echo "</code></li>"
fi

# README.txt present?
if [ ! -e README.txt ]; then
  echo "<li>README.txt is missing, see the <a href=\"http://drupal.org/node/447604\">guidelines for in-project documentation</a>.</li>"
else
# line length in README.txt
  LONG=`grep -c '.\{81\}' README.txt`
  if [ $LONG -gt "0" ]; then
    echo "<li>Lines in README.txt should not exceed 80 characters, see the <a href=\"http://drupal.org/node/447604\">guidelines for in-project documentation</a>.</li>"
  fi
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
if [ -e .DS_Store ]; then
  echo "<li>Remove .DS_Store from your repository.</li>"
fi
# "version" in info file?
grep -q -e "version[[:space:]]*=[[:space:]]*" $NAME.info
if [ $? = 0 ]; then
  echo "<li>Remove \"version\" from the info file, it will be added by drupal.org packaging automatically.</li>"
fi
# "project" in info file?
grep -q -e "project[[:space:]]*=[[:space:]]*" $NAME.info
if [ $? = 0 ]; then
  echo "<li>Remove \"project\" from the info file, it will be added by drupal.org packaging automatically.</li>"
fi
# "datestamp" in info file?
grep -q -e "datestamp[[:space:]]*=[[:space:]]*" $NAME.info
if [ $? = 0 ]; then
  echo "<li>Remove \"datestamp\" from the info file, it will be added by drupal.org packaging automatically.</li>"
fi
# ?> PHP delimiter at the end of any file?
BAD_LINES=`grep -l "^\?>" $PHP_FILES`
if [ $? = 0 ]; then
  echo "<li>The \"?>\" PHP delimiter at the end of files is discouraged, see http://drupal.org/node/318#phptags"
  echo "<code>"
  echo "$BAD_LINES"
  echo "</code></li>"
fi
# files[] not containing classes/interfaces
INFO_FILES=`grep -E "files\[\]" $NAME.info | grep -o -E "[^[:space:]=]+[[:space:]]*$"`
if [ $? = 0 ]; then
  for FILE in $INFO_FILES; do
    grep -q -E "^(abstract )?(class|interface) " $FILE &> /dev/null
    if [ $? -ne 0 ]; then
      echo "<li>$FILE in $NAME.info: It's only necessary to <a href=\"http://drupal.org/node/542202#files\">declare files[] if they declare a class or interface</a>.</li>"
    fi
  done
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
# usage of t() in hook_schema()
if [ -e $NAME.install ]; then
  SCHEMA_LINE_NO=`grep -n -E "_schema\(\) ?\{" $NAME.install | cut -f1 -d:`
  if [ -n "$SCHEMA_LINE_NO" ]; then
    # @todo replace hard coded 1000 sed command with something that prints the
    # rest of a file
    SCHEMA_CONTENT=`sed -n $SCHEMA_LINE_NO,1000p $NAME.install`
    SCHEMA_END_NO=`echo "$SCHEMA_CONTENT" | grep -n -E "^\}" | cut -f1 -d: | head -n1`
    SCHEMA_CONTENT=`echo "$SCHEMA_CONTENT" | sed -n 1,"$SCHEMA_END_NO"p`
    BAD_LINES=`echo "$SCHEMA_CONTENT" | grep -E "[^[:alnum:]_]t\("`
    if [ $? = 0 ]; then
      echo "<li>Do not use t() in hook_schema(), this will only generate overhead for translators."
      echo "<code>"
      echo "$BAD_LINES"
      echo "</code></li>"
    fi
  fi
fi
# Last character in text files must be '\n'.
for FILE in $TEXT_FILES; do
  BAD_LINES=`tail -c 1 $FILE | od -c | grep '\\n'`
  if [ $? -ne 0 ]; then
    BAD_FILES=("${BAD_FILES[@]}" "$FILE")
  fi
done
if [ -n "$BAD_FILES" ]; then
  echo "<li>All text files should end in a single newline (\n). See http://drupal.org/node/318#indenting"
  echo "<code>"
  echo "${BAD_FILES[*]}"
  echo "</code></li>"
fi
echo "</ul>"

echo "<i>This automated report was generated with <a href=\"http://drupal.org/sandbox/klausi/1320008\">PAReview.sh</a>, your friendly project application review script. Go and <a href=\"http://drupal.org/project/issues/projectapplications?status=8\">review some other project applications</a>, so we can get back to yours sooner.</i>"

