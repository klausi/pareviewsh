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
- [Coder 8.x-2.x](https://www.drupal.org/project/coder) + [PHP_CodeSniffer](https://github.com/squizlabs/PHP_CodeSniffer), see [installation instructions](https://www.drupal.org/node/1419988)
- [DrupalSecure](https://www.drupal.org/sandbox/coltrane/1921926)
- [Codespell](https://github.com/lucasdemarchi/codespell)
- [ESLint](http://eslint.org)


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

If you always want to work with the newest version of Coder with Git clones
(replace /home/klausi/workspace with your desired working directory):

    cd /home/klausi/workspace
    git clone --branch 8.x-2.x http://git.drupal.org/project/coder.git
    git clone --branch master http://git.drupal.org/sandbox/coltrane/1921926.git drupalsecure
    git clone --branch master https://github.com/lucasdemarchi/codespell.git

Install composer dependencies:

    cd /home/klausi/workspace/coder
    composer install

Register the phpcs command globally:

    sudo ln -s /home/klausi/workspace/coder/vendor/bin/phpcs /usr/local/bin

Register the Drupal standards with PHPCS:

    phpcs --config-set installed_paths /home/klausi/workspace/coder/coder_sniffer,/home/klausi/workspace/drupalsecure

Register the codespell command globally:

    cp /home/klausi/workspace/codespell/bin/codespell /home/klausi/workspace/codespell/codespell
    sudo ln -s /home/klausi/workspace/codespell/codespell /usr/local/bin/codespell

Installing ESLint on Ubuntu:

    sudo apt-get install npm
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo npm i -g eslint
