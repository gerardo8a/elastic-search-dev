#!/usr/bin/env bash

cwd=$(pwd)
echo "You need JDK 8 to make this work"
`which java` -version
export JAVA_HOME=$(/usr/libexec/java_home)

version=2.3.1
echo "Downloading nutch ${version}..."

curl -sv http://www.apache.org/dist/nutch/2.3.1/apache-nutch-${version}-src.tar.gz -o apache-nutch-${version}-src.tar.gz
curl -sv http://apache.org/dist/nutch/2.3.1/apache-nutch-${version}-src.tar.gz.md5 -o apache-nutch-${version}-src.tar.gz.md5

filemd5=$(cat apache-nutch-${version}-src.tar.gz.md5 | awk {"print \$2"})
nutchmd5=$(md5 -q apache-nutch-${version}-src.tar.gz)

if [ "$filemd5" != "$nutchmd5" ]
then
    echo "Signature md5 = $filemd5"
    echo "File      md5 = $nutchmd5"
    echo "----------------------------------------------------------"
    echo "No md5 matching, you should not be using this software !!!"
    echo "----------------------------------------------------------"
    exit 1
fi

echo "Unpacking nutch..."
tar xvfz apache-nutch-${version}-src.tar.gz
succeed=$?

if [ $succeed != 0 ]
then
    echo "Can't unpack package apache-nutch-${version}-src.tar.gz"
    exit 1
fi

ant_version=1.10.1
echo "Downloading ant ${ant_version}..."

curl -sv http://download.nextag.com/apache//ant/binaries/apache-ant-${ant_version}-bin.tar.gz -o apache-ant-${ant_version}-bin.tar.gz
curl -sv https://www.apache.org/dist/ant/binaries/apache-ant-${ant_version}-bin.tar.gz.md5 -o apache-ant-${ant_version}-bin.tar.gz.md5
                 
antfilemd5=$(cat apache-ant-${ant_version}-bin.tar.gz.md5)
antmd5=$(md5 -q apache-ant-${ant_version}-bin.tar.gz)

if [ "$antfilemd5" != "$antmd5" ]
then
    echo "Signature md5 = $antfilemd5"
    echo "File      md5 = $antmd5"
    echo "----------------------------------------------------------"
    echo "No md5 matching, you should not be using this software !!!"
    echo "----------------------------------------------------------"
    exit 1
fi

echo "Unpacking ant..."
tar xvfz apache-ant-${ant_version}-bin.tar.gz
succeed=$?

if [ $succeed != 0 ]
then
    echo "Can't unpack package apache-ant-${ant_version}-bin.tar.gz"
    exit 1
fi

echo "Copy ivy/ivy.xml -> ./apache-nutch-${version}/"
cp ivy/* ./apache-nutch-${version}/ivy/

hbase_version=0.98.8
echo "Downloading HBase-${hbase_version}"
curl -sv http://archive.apache.org/dist/hbase/hbase-${hbase_version}/hbase-${hbase_version}-hadoop2-bin.tar.gz -o hbase-${hbase_version}-hadoop2-bin.tar.gz
curl -sv http://archive.apache.org/dist/hbase/hbase-${hbase_version}/hbase-${hbase_version}-hadoop2-bin.tar.gz.mds -o hbase-${hbase_version}-hadoop2-bin.tar.gz.mds

tar xvfz hbase-${hbase_version}-hadoop2-bin.tar.gz
succeed=$?

if [ $succeed != 0 ]
then
    echo "Can't unpack package hbase-${hbase_version}-hadoop2-bin.tar.gz"
    exit 1
fi

echo "Compiling -> nutch"
cd apache-nutch-${version} && ./../apache-ant-${ant_version}/bin/ant runtime
succeed=$?

if [ $succeed != 0 ]
then
    echo "Something went wrong while running ant"
    exit 1
fi

# Return to the script dir
cd $cwd && pwd
echo "Copying conf/nutch/* -> ./apache-nutch-${version}/runtime/local/conf"
cp conf/nutch/* ./apache-nutch-${version}/runtime/local/conf

echo "Copying conf/hbase/* -> ./hbase-${hbase_version}-hadoop2/conf"
cp conf/hbase/* ./hbase-${hbase_version}-hadoop2/conf

./hbase-${hbase_version}-hadoop2/bin/start-hbase.sh
echo "Hbase UI Running on http://localhost:16010"

echo "Injecting urls into nutch"
./apache-nutch-${version}/runtime/local/bin/nutch inject urls
echo "Generate urls to fetch"
./apache-nutch-${version}/runtime/local/bin/nutch generate -topN 40
echo "Fetch pages"
./apache-nutch-${version}/runtime/local/bin/nutch fetch -all
echo "Parse pages"
./apache-nutch-${version}/runtime/local/bin/nutch parse -all
echo "Running update will keep stuff fresh"
#./apache-nutch-${version}/runtime/local/bin/nutch updatedb -all
echo "Indexing with elastic search"
./apache-nutch-${version}/runtime/local/bin/nutch index elasticsearch -all


echo "Cleaning up..."
cd $cwd
echo "/bin/rm -f apache-nutch-${version}*gz*"
/bin/rm -f apache-nutch-${version}*gz*
echo "/bin/rm -f apache-ant-${ant_version}*gz*"
/bin/rm -f apache-ant-${ant_version}*gz*
echo "/bin/rm -f hbase-${hbase_version}*gz*"
/bin/rm -f hbase-${hbase_version}*gz*