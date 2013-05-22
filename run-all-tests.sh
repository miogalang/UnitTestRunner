#path to unit tests
unitTestPath="/Users/mio/workspace/lifebit/workspace/tests"
testDbName="lifebit_test"

curPath=$(pwd)

cd $unitTestPath

mysql-fast-loader.sh $testDbName -c "phpunit ."

cd $curPath
