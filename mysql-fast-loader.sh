#!/usr/bin/env bash

##
# @author Jay Taylor <outtatime@gmail.com>
#
# @date 2011-10-20
#
# @description Copies MySQL database to ramdisk then runs supplied shell script
# or command. The ramdisk version of the database is then copied back to the
# filesystem. Speeds up IO-intensive operations (e.g. loading heavily indexed
# tables.)
#
# @requires Mac OS-X, Mysql installed from `brew`.
#
# The first argument needs to be the database name that that will be operated on.
#
# @note By default this creates a ramdisk which has approximately 1.1GB of
# storage capacity.
#
# @note This has been tested on OS X Lion.  It definitely won't work on Linux.
# Mysql was installed via `brew`.
#
# @example
# ./mysql-fast-load.sh testdb -c 'mysql -uroot testdb < /Users/jtaylor/Desktop/testdb-20111110.sql'
#

# Path to MySQL data directory.
mysqlDataDir="/usr/local/var/mysql"

# Number of blocks to allocate for the ramdisk.
# 2165430 = ~1.1GB
# 524288 = ~256MB
numBlocks=524288


################################################################################
# Check if there enough information has been provided in order to run.         #
#                                                                              #
# Also make sure that the requisite directories do or don't exist, as needed.  #
################################################################################

# Make sure that this is running on OS X.
if [ -z "`uname -a | grep -o 'Darwin Kernel'`" ]; then
    echo "fatal: This script only works on OS X." 1>&2
    exit 1
fi

# Ensure the user supplied a database name, and that it exists as a regular directory.
dbName=$1
if [ -z "$dbName" ]; then
    echo "fatal: Missing parameter \"databaseName\", this must be the first argument." 1>&2
    exit 1
fi

# Check for the file argument
if [ "$2" = "-s" ] || [ "$2" = "-script" ] || [ "$2" = "--script" ]; then
    if [ -f "$3" ] && [ -r "$3" ]; then
        script="$3"
    else
        echo "fatal: Missing value for file argument (-s), or the supplied file path does not exist or is not readable." 1>&2
        exit 1
    fi
elif [ "$2" = "-c" ] || [ "$2" = "-command" ] || [ "$2" = "--command" ]; then
    # Create temporary shell script to be run.
    script="`mktemp /tmp/fastmysql.XXXXXXXXXXXXX`"
    echo -e '#!/usr/bin/env bash'"\n$3" > $script
else
    echo "fatal: Missing required parameter \"-s|-script|--script\" or \"-c|-command|--command\", unable to continue without one of these." 1>&2
    exit 1
fi

# Ensure the database exists and is a normal directory.
dbPath="$mysqlDataDir/$dbName"
if ! [ -d "$dbPath" ] || [ -h "$dbPath" ]; then
    echo "fatal: Database \"$dbName\" does not exist, or is not a directory." 1>&2
    exit 1
fi

# Ensure that the temporary database path doesn't already exist (indicative of
# a failed previous attempt which wasn't ever cleaned up.)
backedupDbPath="$mysqlDataDir/../$dbName.bak.`date '+%Y-%m-%d_%H%M%S'`"
if [ -d "$backedupDbPath" ]; then
    echo "fatal: Temporary database path \"$backedupDbPath\" already exist.  This must be cleaned up by the user (that's you"'!'") before I can continue." 1>&2
    exit 1
fi

# Ensure that a volume named "ramdisk" isn't already mounted.
volumeName="ramdisk"
ramdiskPath="/Volumes/$volumeName"
if [ -e "$ramdiskPath" ]; then
    echo "fatal: A volume named \"$volumeName\" is already mounted.  It must be unmounted before I can continue." 1>&2
    exit 1
fi


################################################################################
# Get this show on the road                                                    #
################################################################################

function stopMysql {
    echo -n "Stopping mysql server.. "
    mysql.server stop
    sleep 5
    pids="`ps aux | grep 'bin\/mysqld' | grep -v grep | sed -E 's/ +/ /g' | cut -d' ' -f2 | tr '\n' ' '`"
    if [ -n "$pids" ]; then
        echo "info: kill -9'ing remaining mysql pids $pids"
        kill -9 $pids
    fi
    # Verify that it stopped.
    running="`ps aux | grep 'bin/mysqld ' | grep -v 'grep'`"
    if [ -n "$running" ]; then
        echo "fatal: failed to stop mysql" 1>&2
        exit 1
    fi
    echo "done"
}

function startMysql {
    echo -n "Starting mysql server.. "
    mysql.server start
    sleep 5
    # Verify that it started.
    running="`ps aux | grep 'bin/mysqld ' | grep -v 'grep'`"
    if [ -z "$running" ]; then
        echo "fatal: failed to start mysql" 1>&2
        exit 1
    fi
    echo "done"
}


stopMysql

echo -n "Renaming $dbPath to $backedupDbPath.. "
mv "$dbPath" "$backedupDbPath"
echo "done"

echo -n "Creating ramdisk \"$volumeName\".. "
diskutil erasevolume HFS+ "$volumeName" `hdiutil attach -nomount ram://$numBlocks`
echo "done"

echo -n "Creating symbolic link from ramdisk to database directory.. "
ln -s "$ramdiskPath" "$dbPath"
echo "done"

echo -n "Copying database to ramdisk.. "
cp -r $backedupDbPath/* $dbPath/
echo "done"

startMysql

echo -e "Executing shell script: $script\n--------------------------------------------------------------------------------"
bash $script
echo -e "--------------------------------------------------------------------------------\nExecution completed"

stopMysql

echo -n "Making temp directory.. "
tmpPath=`mktemp -d -t fastmysql`
echo "\"$tmpPath\" done"

echo -n "Copying ramdisk version to disk (\"$tmpPath\").. "
cp -r $dbPath/* $tmpPath
echo "done"

echo -n "Unmounting ramdisk \"$ramdiskPath\".. "
umount $ramdiskPath
echo "done"

echo -n "Unlinking \"$dbPath\".. "
unlink $dbPath
echo "done"

echo -n "Moving \"$tmpPath\" to \"$dbPath\".. "
mv $tmpPath $dbPath
echo "done"

startMysql

echo -e "\nAll done"'!'

exit 0
