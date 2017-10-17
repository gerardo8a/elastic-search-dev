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

echo "Running ant on nutch..."
cd apache-nutch-${version} && ./../apache-ant-${ant_version}/bin/ant
succeed=$?

if [ $succeed != 0 ]
then
    echo "Something went wrong while running ant"
    exit 1
fi

echo "Cleaning up..."
cd $cwd
echo "/bin/rm -f apache-nutch-${version}*gz*"
/bin/rm -f apache-nutch-${version}*gz*
echo "/bin/rm -f apache-ant-${ant_version}*gz*"
/bin/rm -f apache-ant-${ant_version}*gz*

echo "Copying conf/nutch-site.xml -> ./apache-nutch-${version}/runtime/local/conf"
cp conf/nutch-site.xml ./apache-nutch-${version}/runtime/local/conf

