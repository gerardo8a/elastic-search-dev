#!/usr/bin/env bash
set -u

BASEDIR=$(dirname "$0")
cwd=$(pwd)/$BASEDIR

if [ -z ${1+x} ]; then
    command="nothing"
else
    command=$1
fi

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
#nutch_version=1.13
nutch_base_name=apache-nutch
nutch_extra=src.tar.gz
nutch_package=${nutch_base_name}-${nutch_version}-${nutch_extra}

if [ ! -d ${cwd}/${nutch_base_name}-${nutch_version} ]; then
    if [ ! -d ${nutch_package} ]; then
        echo "Downloading ${nutch_package}"
        echo "Fetching http://www.apache.org/dist/nutch/${nutch_version}/${nutch_package}"
        curl --progress-bar http://www.apache.org/dist/nutch/${nutch_version}/${nutch_package} -o ${nutch_package}

        echo "Fetching http://apache.org/dist/nutch/${nutch_version}/${nutch_package}.md5"
        curl --progress-bar http://apache.org/dist/nutch/${nutch_version}/${nutch_package}.md5 -o ${nutch_package}.md5
    fi
    filemd5=$(cat ${nutch_package}.md5 | awk {"print \$2"})
    nutchmd5=$(md5 -q ${nutch_package})
    check_md5 filemd5 nutchmd5
    unTarPackage ${nutch_package}
fi

#ant
ant_version=1.10.1
ant_base_name=apache-ant
ant_extra=bin.tar.gz
ant_package=${ant_base_name}-${ant_version}-${ant_extra}

if [ ! -d ${cwd}/${ant_base_name}-${ant_version} ]; then
    if [ ! -d ${ant_package} ]; then
        echo "Downloading ${ant_package}"
        echo "Fetching http://download.nextag.com/apache/ant/binaries/${ant_package} -o ${ant_package}"
        curl --progress-bar http://download.nextag.com/apache/ant/binaries/${ant_package} -o ${ant_package}

        echo "Fetching https://www.apache.org/dist/ant/binaries/${ant_package}.md5 -o ${ant_package}.md5"
        curl --progress-bar https://www.apache.org/dist/ant/binaries/${ant_package}.md5 -o ${ant_package}.md5
    fi
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

if [ ! -d ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname} ]; then
    if [ ! -d ${hbase_package} ]; then
        echo "Downloading ${hbase_package}"
        echo "Fetching http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package}"
        curl --progress-bar http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package} -o ${hbase_package}

        echo "Fetching http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package}.mds"
        curl --progress-bar http://archive.apache.org/dist/${hbase_base_name}/${hbase_base_name}-${hbase_version}/${hbase_package}.mds -o ${hbase_package}.mds
    fi

    hbasefilemd5=$(cat ${hbase_package}.mds|grep MD5 -A 1|sed 's/^.*= //'|tr -d '\n'|sed 's/[[:space:]]//g'|tr '[:upper:]' '[:lower:]')
    hbasemd5=$(md5 -q ${hbase_package})
    check_md5 hbasefilemd5 hbasemd5
    unTarPackage ${hbase_package}
fi

build_nutch() {
    # Define which hbase and gora version to be used
    echo "Copy ${cwd}/ivy/ivy.xml -> ${cwd}/${nutch_base_name}-${nutch_version}/ivy/"
    cp ${cwd}/ivy/* ${cwd}/${nutch_base_name}-${nutch_version}/ivy/
    echo "Copy ${cwd}/conf/nutch/*.properties -> ${cwd}/${nutch_base_name}-${nutch_version}/conf/"
    cp ${cwd}/conf/nutch/*.properties ${cwd}/${nutch_base_name}-${nutch_version}/conf/

    echo "Compiling ..."
    cd ${cwd}/${nutch_base_name}-${nutch_version} && ${cwd}/${ant_base_name}-${ant_version}/bin/ant clean && ${cwd}/${ant_base_name}-${ant_version}/bin/ant runtime
    succeed=$?
    if [ $succeed != 0 ]
    then
        echo "Something went wrong while compiling ant"
        exit 1
    fi
    
    echo "Copying conf/nutch/* -> ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/conf"
    cp ${cwd}/conf/nutch/nutch-site.xml ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/conf
    echo "Copying ${cwd}/conf/hbase/* -> ${cwd}/hbase-${hbase_version}${hbase_extra_dirname}/conf"
    cp ${cwd}/conf/hbase/* ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname}/conf
}

hbase_restart() {
    echo "Copying ${cwd}/conf/hbase/* -> ${cwd}/hbase-${hbase_version}${hbase_extra_dirname}/conf"
    cp ${cwd}/conf/hbase/* ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname}/conf

    ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname}/bin/stop-hbase.sh
    ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname}/bin/start-hbase.sh
    echo "Hbase UI Running on http://localhost:16010 ? not sure if this is the right port"
}

nutch_indexing() {
    echo "Injecting urls into nutch"
    ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch inject ${cwd}/urls
    echo "Generate urls to fetch"
    ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch generate -topN 40
    echo "Fetch pages"
    ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch fetch -all
    echo "Parse pages"
    ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch parse -all
    echo "Running update will keep stuff fresh"
    ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch updatedb -all
    echo "Indexing with elastic search"
    ${cwd}/${nutch_base_name}-${nutch_version}/runtime/local/bin/nutch index elasticsearch -all
}

clean_all() {
    command=$1
    if [ "$command" == "cleanall" ]; then
        echo "Cleaning all"
        ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname}/bin/stop-hbase.sh
        if [ -d ${cwd}/${nutch_base_name}-${nutch_version} ] && [ -d ${hbase_base_name}-${hbase_version}${hbase_extra_dirname} ] && [ -d ${cwd}/${ant_base_name}-${ant_version} ]; then
            echo "/bin/rm -f ${cwd}/${nutch_base_name}-${nutch_version}*"
            /bin/rm -rf ${cwd}/${nutch_base_name}-${nutch_version}*
            echo "/bin/rm -f ${cwd}/${ant_base_name}-${ant_version}*"
            /bin/rm -rf ${cwd}/${ant_base_name}-${ant_version}*
            echo "/bin/rm -f ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname}*"
            /bin/rm -rf ${cwd}/${hbase_base_name}-${hbase_version}${hbase_extra_dirname}*
        fi 
        exit 1
    fi
}

clean_gz() {
    echo "Cleaning up..."
    echo "/bin/rm -f ${cwd}/${nutch_package}"
    /bin/rm -f ${cwd}/${nutch_package}
    echo "/bin/rm -f ${cwd}/${ant_package}"
    /bin/rm -f ${cwd}/${ant_package}
    echo "/bin/rm -f ${cwd}/${hbase_package}"
    /bin/rm -f ${cwd}/${hbase_package}
}

#clean_all $command
build_nutch
hbase_restart
nutch_indexing
clean_gz