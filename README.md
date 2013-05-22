UnitTestRunner
==============

STILL VERY ERROR PRONE. USE AT YOUR OWN RISK.
Message me if you know me/
email me at <miguelgalang@gmail.com> to ask for write access.

This project uses a ramdisk to run a suite of unit tests to improve runtime.

I used the script from jaytaylor with some minor modifications.
https://gist.github.com/jaytaylor/1302100

Before using either add this path to $PATH
or create symbolic links in a path included in $PATH


cd <$PATH-included-folder>
ln -s <path-of-script>/mysql-fast-loader.sh mysql-fast-loader.sh
ln -s <path-of-script>/run-all-tests.sh run-all-tests.sh


Open run-all-tests.sh and change path to unit test folder.


run using 'run-all-tests.sh'

