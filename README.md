# Installing elastic search in your laptop

* install docker https://docs.docker.com/engine/installation/
* install git https://git-scm.com/downloads
* Clone the git repo - https://github.com/elastic/stack-docker
  * ```git clone git@github.com:elastic/stack-docker.git```
* Change to the stat-docker directory and run 
  * ```docker-compose up```
* Default 
  * user elastic
  * password changeme 

After docker is done you will end up with twi services up the api and Kibana listening in the following ports
* Api http://localhost:9200/
* Kibana http://localhost:5601/

# Installing nutch
* You need to have Java 8
* You need to have elastic search running
* Clone repo
  * ```git@github.com:gerardo8a/elastic-search-dev.git```
* Configure hadoop directory
   * ```conf/hbase/hbase-site.xml```
* run ```./setup.bash``` this will take care of pulling, compiling, crawling and pushing to elastic (this last is not working for me)
* The only service we start is the hbase process, to stop it run ```./stop-hbase.sh```
