PAReview.sh
===========

Simple Bash script to automatically review Drupal.org project applications. It
takes a Git repository URL as argument, clones the code in a pareview_temp
folder and runs some checks. Alternatively it takes a path to a module/theme
project and checks that. The output is suitable for a comment in the Project
Applications issue queue.

Intallation
-----------

Requirements:
- A Bash shell environment (tested on Ubuntu, should also work on Macs)
- Git
- [Coder 7.x-2.x](http://drupal.org/project/coder) + [PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer), see [installation instructions](https://drupal.org/node/1419988)
- [DrupalPractice](https://github.com/klausi/drupalpractice)
- [DrupalSecure](http://drupal.org/sandbox/coltrane/1921926)


The script can be placed anywhere, for convenience you can add a link to one of
the executable directories in your $PATH, e.g.:

    sudo ln -s /path/to/downloaded/pareviewsh/pareview.sh /usr/local/bin


Usage (running in a shell)
--------------------------

    $> pareview.sh GIT-URL [BRANCH]
    $> pareview.sh DIR-PATH

Examples:
    
    $> pareview.sh http://git.drupal.org/project/rules.git
    $> pareview.sh http://git.drupal.org/project/rules.git 6.x-1.x
    $> pareview.sh sites/all/modules/rules
