PAReview.sh
===========

Simple Bash script to automatically review Drupal.org project applications. It
takes a Git repository URL as argument, clones the code in a pareview_temp
folder and runs some checks. Alternatively it takes a path to a module/theme
project and checks that. The output is suitable for a comment in the Project
Applications issue queue.

Online version
--------------
http://pareview.sh

Intallation
-----------

Requirements:
- A Bash shell environment (tested on Ubuntu, should also work on Macs)
- Git
- [Coder 7.x-2.x](http://drupal.org/project/coder) + [PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer), see [installation instructions](https://drupal.org/node/1419988)
- [DrupalPractice](https://github.com/klausi/drupalpractice)
- [DrupalSecure](http://drupal.org/sandbox/coltrane/1921926)
- [Codespell](https://github.com/lucasdemarchi/codespell)


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


Bleeding edge installation of depedencies
-----------------------------------------

If you always want to work with the newest versions of all PHPCS Standards
involved using Git clones (replace /home/klausi/workspace with your desired
working directory):

    cd /home/klausi/workspace
    git clone --branch phpcs-fixer https://github.com/squizlabs/PHP_CodeSniffer.git
    git clone --branch 8.x-2.x http://git.drupal.org/project/coder.git
    git clone --branch 8.x-1.x http://git.drupal.org/project/drupalpractice.git
    git clone --branch master http://git.drupal.org/sandbox/coltrane/1921926.git drupalsecure

Then link the standards into PHPCS:

    ln -s /home/klausi/workspace/coder/coder_sniffer/Drupal /home/klausi/workspace/PHP_CodeSniffer/CodeSniffer/Standards
    ln -s /home/klausi/workspace/drupalpractice/DrupalPractice /home/klausi/workspace/PHP_CodeSniffer/CodeSniffer/Standards
    ln -s /home/klausi/workspace/drupalsecure/DrupalSecure /home/klausi/workspace/PHP_CodeSniffer/CodeSniffer/Standards

Register the phpcs command globally:

    sudo ln -s /home/klausi/workspace/PHP_CodeSniffer/scripts/phpcs /usr/local/bin
