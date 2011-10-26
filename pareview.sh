#!/bin/bash

## You need a Drupal installation + drush + coder_review enabled.
## This script must be run from somewhere in your Drupal installation.

DRUPAL_ROOT=`drush status --pipe drupal_root`

if [ ! -d $DRUPAL_ROOT/sites/all/modules ]; then
  if [ ! -d $DRUPAL_ROOT/sites/all ]; then
    echo "Directory $DRUPAL_ROOT/sites/all not found, please make sure that you run this script in a Drupal installation. Aborting."
    exit
  else
    mkdir $DRUPAL_ROOT/sites/all/modules
  fi
fi

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
  exit
fi
cd test_candidate

# checkout branch
# first try 7.x-?.x
BRANCH_NAME=`git branch -a | grep -o -E "7\.x-[0-9]\.x"`
if [ $? = 0 ]; then
  git checkout -q $BRANCH_NAME &> /dev/null
else
  # try 6.x-?.x
  BRANCH_NAME=`git branch -a | grep -o -E "6\.x-[0-9]\.x"`
  if [ $? = 0 ]; then
    git checkout -q $BRANCH_NAME &> /dev/null
  else
    BRANCH_NAME=`git rev-parse --abbrev-ref HEAD`
    echo "It appears you are working in the \"$BRANCH_NAME\" branch in git. You should really be working in a version specific branch. The most direct documentation on this is <a href=\"http://drupal.org/node/1127732\">Moving from a master branch to a version branch.</a> For additional resources please see the documentation about <a href=\"http://drupal.org/node/1015226\">release naming conventions</a> and <a href=\"http://drupal.org/node/1066342\">creating a branch in git</a>."
  fi
fi
echo "Review of the $BRANCH_NAME branch:"

# get module/theme name
INFO_FILE=`ls *.info`
NAME=${INFO_FILE%.*}
PHP_FILES=`find . -not \( -name \*.tpl.php \) -and \( -name \*.module -or -name \*.php -or -name \*.inc -or -name \*.install \)
`

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
  echo "<li>Run <a href=\"/project/coder\">coder</a> to check your style, some issues were found (please check the <a href=\"http://drupal.org/node/318\">Drupal coding standards</a>):"
  echo "<code>"
  echo "$CODER"
  echo "</code></li>"
fi

# README.txt present?
if [ ! -e README.txt ]; then
  echo "<li>README.txt is missing, see the <a href=\"http://drupal.org/node/447604\">guidelines for in-project documentation</a>.</li>"
else
# line length in README.txt
  LENGTH=`wc -L README.txt | grep -o "^[0-9]*"`
  if [ $LENGTH -gt "80" ]; then
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
grep -q -e "project[[:space:]]*=[[:space:]]*" $NAME.info
if [ $? = 0 ]; then
  echo "<li>Remove \"datestamp\" from the info file, it will be added by drupal.org packaging automatically.</li>"
fi
# @file in module file?
if [ -e $NAME.module ]; then
  grep -q " \* @file" $NAME.module
  if [ $? = 1 ]; then
    echo "<li>@file doc block is missing in the module file, see http://drupal.org/node/1354#files .</li>"
  fi  
fi
# @file in install file?
if [ -e $NAME.install ]; then
  grep -q " \* @file" $NAME.install
  if [ $? = 1 ]; then
    echo "<li>@file doc block is missing in the install file, see http://drupal.org/node/1354#files .</li>"
  fi  
fi
# ?> PHP delimiter at the end of any file?
FILES=`grep -l "^\?>" $PHP_FILES`
if [ $? = 0 ]; then
  echo "<li>The \"?>\" PHP delimiter at the end of files is discouraged, see http://drupal.org/node/318#phptags"
  echo "<code>"
  echo "$FILES"
  echo "</code></li>"
fi
# // Comments should start capitalized
# comments can take more than one line, so we cannot use this rules like this.
#COMMENTS=`grep -rn -E "^[[:space:]]*//[[:space:]]?[[:lower:]]" *`
#if [ $? = 0 ]; then
#  echo "<li>All comments should start capitalized."
#  echo "<code>"
#  echo "$COMMENTS"
#  echo "</code></li>"
#fi
# // Comments should end with a "."
#COMMENTS=`grep -rn -E "^[[:space:]]*//.*[[:alnum:]][[:space:]]*$" *`
#if [ $? = 0 ]; then
#  echo "<li>All comments should end with a \".\"."
#  echo "<code>"
#  echo "$COMMENTS"
#  echo "</code></li>"
#fi
# comments: space after //
COMMENTS=`grep -rn -E "^[[:space:]]*//[[:alnum:]].*" *`
if [ $? = 0 ]; then
  echo "<li>Comments: there should be a space after \"//\"."
  echo "<code>"
  echo "$COMMENTS"
  echo "</code></li>"
fi
# files[] not containing classes/interfaces
FILES=`grep -E "files\[\]" $NAME.info | grep -o -E "[[:alnum:]]+\.[[:alnum:]]+$"`
if [ $? = 0 ]; then
  for FILE in $FILES; do
    grep -q -E "^(class|interface) " $FILE &> /dev/null
    if [ $? -ne 0 ]; then
      echo "<li>$FILE in $NAME.info: It's only necessary to <a href=\"http://drupal.org/node/542202#files\">declare files[] if they declare a class or interface</a>.</li>"
    fi
  done
fi
# functions without doc blocks
for FILE in $PHP_FILES; do
  FUNCTIONS=`grep -E -B 1 "^function [[:alnum:]]+.*\(.*\) \{" $FILE | grep -E -A 1 "^[[:space:]]*$"`
  if [ $? = 0 ]; then
    echo "<li>$FILE: all functions should have doxygen doc blocks, see http://drupal.org/node/1354#functions"
    echo "<code>"
    echo "$FUNCTIONS"
    echo "</code></li>"
  fi
done
echo "</ul>"

echo "<i>This automated report was generated with <a href=\"/sandbox/klausi/1320008\">PAReview.sh</a>, your friendly project application review script. Please report any bugs to klausi.</i>"

