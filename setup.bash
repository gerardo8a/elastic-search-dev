#!/usr/bin/env bash
cwd=$(pwd)

check_md5() {
    local filemd5=$1
    local packagemd5=$1
    if [ "$filemd5" != "$packagemd5" ]; then
        echo "Signature md5 = $filemd5"
        echo "File      md5 = $packagemd5"
        echo "----------------------------------------------------------"
        echo "No md5 matching, you should not be using this software !!!"
        echo "----------------------------------------------------------"
        exit 1
    fi
}

unTarPackage() {
    local package=$1
    echo "Unpacking ${package} ..."
    tar xfz ${package}
    local succeed=$?

    if [ $succeed != 0 ]; then
        echo "Can't unpack package ${package}"
        exit 1
    fi
}

echo "You need JDK 8 to make this work, configuring JAVA_HOME"
`which java` -version
export JAVA_HOME=$(/usr/libexec/java_home)
echo ${JAVA_HOME}

# Nutch
nutch_version=2.3.1
nutch_base_name=apache-nutch
nutch_extra=src.tar.gz
nutch_package=${nutch_base_name}-${nutch_version}-${nutch_extra}

if [ ! -d ${nutch_base_name}-${nutch_version} ]; then
    echo "Downloading ${nutch_package}"
    echo "Fetching http://www.apache.org/dist/nutch/${nutch_version}/${nutch_package}"
    curl --progress-bar http://www.apache.org/dist/nutch/${nutch_version}/${nutch_package} -o ${nutch_package}

    echo "Fetching http://apache.org/dist/nutch/${nutch_version}/${nutch_package}.md5"
    curl --progress-bar http://apache.org/dist/nutch/${nutch_version}/${nutch_package}.md5 -o ${nutch_package}.md5

    filemd5=$(cat ${nutch_package}.md5 | awk {"print \$2"})
    nutchmd5=$(md5 -q ${nutch_package})
    check_md5 filemd5 nutchmd5
    unTarPackage ${nutch_package}
fi

ant_version=1.10.1
ant_base_name=apache-ant
ant_extra=bin.tar.gz
ant_package=${ant_base_name}-${ant_version}-${ant_extra}

if [ ! -d ${ant_base_name}-${ant_version} ]; then
    echo "Downloading ${ant_package}"
    echo "Fetching http://download.nextag.com/apache/ant/binaries/${ant_package} -o ${ant_package}"
    curl --progress-bar http://download.nextag.com/apache/ant/binaries/${ant_package} -o ${ant_package}

    echo "Fetching https://www.apache.org/dist/ant/binaries/${ant_package}.md5 -o ${ant_package}.md5"
    curl --progress-bar https://www.apache.org/dist/ant/binaries/${ant_package}.md5 -o ${ant_package}.md5

    antfilemd5=$(cat ${ant_package}.md5)
    antmd5=$(md5 -q ${ant_package})
    check_md5 antfilemd5 antmd5
    unTarPackage ${ant_package}
fi

# hbase_version=1.2.6
# hbase_version=0.94.27
hbase_version=0.98.8
hbase_base_name=hbase
hbase_extra=hadoop2-bin.tar.gz
hbase_package=${hbase_base_name}-${hbase_version}-${hbase_extra}
hbase_extra_dirname=-hadoop2

if [ ! -d ${hbase_base_name}-${hbase_version}${hbase_extra_dirname} ]; then
    echo "Downloading ${hbase_package}"
    echo "Fetching http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package}"
    curl --progress-bar http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package} -o ${hbase_package}

    echo "Fetching http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package}.mds"
    curl --progress-bar http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package}.mds -o ${hbase_package}.mds

    hbasefilemd5=$(cat ${hbase_package}.mds|grep MD5 -A 1|sed 's/^.*= //'|tr -d '\n'|sed 's/[[:space:]]//g'|tr '[:upper:]' '[:lower:]')
    hbasemd5=$(md5 -q ${hbase_package})
    check_md5 hbasefilemd5 hbasemd5
    unTarPackage ${hbase_package}
fi

# Configuration and Compiling section
echo "Copy ivy/ivy.xml -> ./${nutch_base_name}-${nutch_version}/"
cp ivy/* ./${nutch_base_name}-${nutch_version}/ivy/

echo "Compiling ..."
cd ${nutch_base_name}-${nutch_version} && ./../${ant_base_name}-${ant_version}/bin/ant clean && ./../${ant_base_name}-${ant_version}/bin/ant runtime
succeed=$?

if [ $succeed != 0 ]
then
    echo "Something went wrong while compiling ant"
    exit 1
fi

# Return to the script dir
cd $cwd && pwd
echo "Copying conf/nutch/* -> ./${nutch_base_name}-${nutch_version}/runtime/local/conf"
cp conf/nutch/* ./${nutch_base_name}-${nutch_version}/runtime/local/conf
cp conf/hbase/* ./${nutch_base_name}-${nutch_version}/runtime/local/conf

echo "Copying conf/hbase/* -> ./hbase-${hbase_version}${hbase_extra_dirname}/conf"
cp conf/hbase/* ./${hbase_base_name}-${hbase_version}${hbase_extra_dirname}/conf

./${hbase_base_name}-${hbase_version}${hbase_extra_dirname}/bin/start-hbase.sh
echo "Hbase UI Running on http://localhost:16010"

echo "Injecting urls into nutch"
./${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch inject urls
echo "Generate urls to fetch"
./${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch generate -topN 40
echo "Fetch pages"
./${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch fetch -all
echo "Parse pages"
./${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch parse -all
echo "Running update will keep stuff fresh"
./${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch updatedb -all
echo "Indexing with elastic search"
./${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch index elasticsearch -all


echo "Cleaning up..."
cd $cwd
echo "/bin/rm -f ${nutch_base_name}-${nutch_version}*.gz*"
/bin/rm -f ${nutch_base_name}-${nutch_version}*.gz*
echo "/bin/rm -f ${ant_base_name}-${ant_version}*.gz*"
/bin/rm -f ${ant_base_name}-${ant_version}*.gz*
echo "/bin/rm -f ${hbase_base_name}-${hbase_version}*.gz*"
/bin/rm -f ${hbase_base_name}-${hbase_version}*.gz*