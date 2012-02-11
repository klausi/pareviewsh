-------------------------------------------------------------------------------
                            PAReview.sh
-------------------------------------------------------------------------------

Simple Bash script to automatically review Drupal.org project applications. It
takes a Git repository URL as argument, clones the code in
sites/all/modules/pareview_temp and runs some checks. Alternatively it takes a
path to a module/theme project and checks that. The output is suitable for a
comment in the Project Applications issue queue.

Intallation
-----------

Requirements:
  - A Bash shell environment (tested on Ubuntu, should also work on Macs)
  - A Drupal installation (tested with Drupal 7)
  - Git: http://git-scm.com
  - Drupal Code Sniffer: http://drupal.org/project/drupalcs
  - Drush: http://drupal.org/project/drush
  - Coder drupalcs reduced with Coder code review enabled:
    http://drupal.org/sandbox/klausi/1339220


Usage (running in a shell)
--------------------------

$> cd /path/to/drupal
$> pareview.sh GIT-URL [BRANCH]
$> pareview.sh DIR-PATH

Examples:
$> pareview.sh http://git.drupal.org/project/rules.git
$> pareview.sh http://git.drupal.org/project/rules.git 6.x-1.x
$> pareview.sh sites/all/modules/rules
