# Postgres database schema to be migrated
# default:public
SCHEMA="public"

# host of postgres
# for example, PG_HOST="0.0.0.0"
PG_HOST=""

# install user of postgres
# for example, PG_USER="postgres"
PG_USER=""

# database port of postgres database
# for example, PG_PORT="5432"
PG_PORT=""

# Postgres database name to be migrated
# for example, PG_DBNAME="pg_dbname"
PG_DBNAME=""

# The directory where intermediate data is stored on the postgres side
# for example, PG_DATA_DIR="/data/pg2og"
PG_DATA_DIR=""

# database port of openGauss in local host
# for example, OG_PORT="5432"
OG_PORT=""

# opengauss database name for receiving data from postgres
# for example, OG_DBNAME="og_dbname"
OG_DBNAME=""

# The directory where intermediate data is stored on the opengauss side
# for example, OG_DATA_DIR="/data/pg2og"
OG_DATA_DIR=""

DIR=$(cd `dirname $0`;pwd)
BIN_DIR=$DIR/bin
CONFIG_DIR=$DIR/config
PATCH_DIR=$DIR/debezium-patch
KAFKA_VERSION1=2.13
KAFKA_VERSION2=2.8.1
KAFKA_DIR=$DIR/kafka_$KAFKA_VERSION1-$KAFKA_VERSION2
SNAPSHOT_DIR=$DIR/pgdumpSnapshotter
DEBEZIUM_DIR=$DIR/debezium
CONSUMER_DIR=$DIR/openGauss-tools-onlineMigration
LOG_DIR=$DIR/log

DEBEZIUM_ORACLE_CONNECTOR_DIR=$DIR/debezium-connector-postgres

install_kafka_debezium_consumer(){
    cd $DIR

    wget -c https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/$KAFKA_VERSION2/kafka_$KAFKA_VERSION1-$KAFKA_VERSION2.tgz
    wget -c https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/1.6.1.Final/debezium-connector-postgres-1.6.1.Final-plugin.tar.gz

    tar -zxf kafka_$KAFKA_VERSION1-$KAFKA_VERSION2.tgz
    tar -zxf debezium-connector-postgres-1.6.1.Final-plugin.tar.gz
    
    git clone --branch v1.6.1.Final https://github.com/debezium/debezium.git

    git clone https://gitee.com/ma-ruoyan/openGauss-tools-onlineMigration.git

}

compile_snapshot(){
    if [ ! -d $SNAPSHOT_DIR/lib ]; then
        mkdir $SNAPSHOT_DIR/lib
    fi 
    cp -f $DEBEZIUM_ORACLE_CONNECTOR_DIR/debezium-api-1.6.1.Final.jar $SNAPSHOT_DIR/lib
    cp -f $DEBEZIUM_ORACLE_CONNECTOR_DIR/debezium-connector-postgres-1.6.1.Final.jar $SNAPSHOT_DIR/lib
    cp -f $DEBEZIUM_ORACLE_CONNECTOR_DIR/debezium-core-1.6.1.Final.jar $SNAPSHOT_DIR/lib
    cp -f $DEBEZIUM_ORACLE_CONNECTOR_DIR/failureaccess-1.0.1.jar $SNAPSHOT_DIR/lib
    cp -f $DEBEZIUM_ORACLE_CONNECTOR_DIR/guava-30.0-jre.jar $SNAPSHOT_DIR/lib
    cp -f $DEBEZIUM_ORACLE_CONNECTOR_DIR/postgresql-42.2.14.jar $SNAPSHOT_DIR/lib
    cp -f $DEBEZIUM_ORACLE_CONNECTOR_DIR/protobuf-java-3.8.0.jar $SNAPSHOT_DIR/lib
    cd $SNAPSHOT_DIR
    mvn clean
    mvn install
    mvn package
    cp -f $SNAPSHOT_DIR/target/mytest-jar-1.0-SNAPSHOT.jar $DEBEZIUM_ORACLE_CONNECTOR_DIR
}

compile_debezium_core(){
    cd $DEBEZIUM_DIR
    git apply $PATCH_DIR/v161_onlyonetopic.patch
    mvn clean package -pl debezium-core -Dquick -DskipTest -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true
    cp -f $DEBEZIUM_DIR/debezium-core/target/debezium-core-1.6.1.Final.jar $DEBEZIUM_ORACLE_CONNECTOR_DIR
}

compile_consumer(){
    cd $CONSUMER_DIR
    mvn clean
    mvn install
    mvn package
}
handle_clean(){
    cd $DIR
    echo "handle $DIR/clean.sh"
    sed -i "s/^PG_HOST=.*/PG_HOST=${PG_HOST}/" ./clean.sh
    sed -i "s/^PG_USER=.*/PG_USER=${PG_USER}/" ./clean.sh
    sed -i "s!^PG_DATA_DIR=.*!PG_DATA_DIR=${PG_DATA_DIR}!" ./clean.sh
    sed -i "s!^OG_DATA_DIR=.*!OG_DATA_DIR=${OG_DATA_DIR}!" ./clean.sh
}
# configure export.sh
handle_export(){
    cd $BIN_DIR
    echo "handle $CONFIG_DIR/export.sh"
    sed -i "s/^PG_HOST=.*/PG_HOST=${PG_HOST}/" ./export.sh
    sed -i "s/^PG_USER=.*/PG_USER=${PG_USER}/" ./export.sh
    sed -i "s/^PG_DBNAME=.*/PG_DBNAME=${PG_DBNAME}/" ./export.sh
    sed -i "s/^PG_PORT=.*/PG_PORT=${PG_PORT}/" ./export.sh
    sed -i "s/^SCHEMA=.*/SCHEMA=${SCHEMA}/" ./export.sh
    sed -i "s!^PG_DATA_DIR=.*!PG_DATA_DIR=${PG_DATA_DIR}!" ./export.sh
    if [ ! -d ~/pg2og_migration/ ]; then
        mkdir ~/pg2og_migration/
    fi 
    ssh $PG_USER@$PG_HOST  << eeooff
        if [ ! -d ~/pg2og_migration/ ]; then
            mkdir ~/pg2og_migration/
        fi
        if [ ! -d $PG_DATA_DIR ]; then
            mkdir $PG_DATA_DIR
        fi
eeooff
    sleep 1
    scp  $BIN_DIR/export.sh $PG_USER@$PG_HOST:~/pg2og_migration/export.sh
    cd $DIR
}
get_partition(){
    cd $BIN_DIR
    sed -i "s/^PG_PORT=.*/PG_PORT=${PG_PORT}/" ./partition.sh
    sed -i "s/^PG_DBNAME=.*/PG_DBNAME=${PG_DBNAME}/" ./partition.sh
    sed -i "s/^SCHEMA=.*/SCHEMA=${SCHEMA}/" ./partition.sh
    sed -i "s!^PG_DATA_DIR=.*!PG_DATA_DIR=${PG_DATA_DIR}!" ./partition.sh
    scp  $BIN_DIR/partition.sh $PG_USER@$PG_HOST:~/pg2og_migration/partition.sh

    ssh $PG_USER@$PG_HOST  << eeooff
        sh ~/pg2og_migration/partition.sh
eeooff
    sleep 5
    scp  $PG_USER@$PG_HOST:~/pg2og_migration/export.sh ~/pg2og_migration/export.sh
    scp  $PG_USER@$PG_HOST:~/pg2og_migration/partition_table_information.txt $CONFIG_DIR/partition_table_information.txt
}
# configure import.sh
handle_import(){
    cd $BIN_DIR
    echo "handle $CONFIG_DIR/import.sh"
    sed -i "s/^PG_HOST=.*/PG_HOST=${PG_HOST}/" ./import.sh
    sed -i "s/^PG_USER=.*/PG_USER=${PG_USER}/" ./import.sh
    sed -i "s/^OG_PORT=.*/OG_PORT=${OG_PORT}/" ./import.sh
    sed -i "s/^OG_DBNAME=.*/OG_DBNAME=${OG_DBNAME}/" ./import.sh
    sed -i "s!^PG_DATA_DIR=.*!PG_DATA_DIR=${PG_DATA_DIR}!" ./import.sh
    sed -i "s!^OG_DATA_DIR=.*!OG_DATA_DIR=${OG_DATA_DIR}!" ./import.sh
    if [ ! -d ~/pg2og_migration/ ]; then
        mkdir ~/pg2og_migration/
    fi
    cp -f ./import.sh ~/pg2og_migration/
    cd $DIR
}
# establish mutual trust connection between postgres host and opengauss host
rsa(){
    cd $DIR
    echo "establish mutual trust connection between postgres host and opengauss host"
    echo "please enter password for $PG_USER@$PG_HOST"
    ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa 
    ssh-copy-id -i  ~/.ssh/id_rsa.pub $PG_USER@$PG_HOST
}

# 
start_debezium(){
    cd $DIR
    if [ ! -d $KAFKA_DIR/connect/ ]; then
        mkdir $KAFKA_DIR/connect
    fi
    if [ ! -d $LOG_DIR/ ]; then
        mkdir $LOG_DIR
    fi
    cp -r $DEBEZIUM_ORACLE_CONNECTOR_DIR $KAFKA_DIR/connect

    sed -i "$ a\ plugin.path=${KAFKA_DIR}/connect"  $KAFKA_DIR/config/connect-distributed.properties

    cd $KAFKA_DIR/
    echo "start zookeeper..."
    chmod -R 777 ./bin
    sh ./bin/zookeeper-server-start.sh ./config/zookeeper.properties > $LOG_DIR/zookeeper.log &

    sleep 10
    echo "start kafka..."
    # chmod +x ./bin/kafka-server-start.sh
    sh ./bin/kafka-server-start.sh ./config/server.properties > $LOG_DIR/kafka.log &

    sleep 10
    echo "start kafka connect..."
    # chmod +x ./bin/connect-distributed.sh
    sh ./bin/connect-distributed.sh ./config/connect-distributed.properties | tee $LOG_DIR/debezium.log &

    sleep 10
    curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://localhost:8083/connectors/ -d @$CONFIG_DIR/register-pg13.json
    
    sleep 5

    cd $DIR
}

start_consumer(){
    echo "start consumer..."
    cd $CONSUMER_DIR/target
    java -jar OnlineMigration-1.0-SNAPSHOT.jar --schema $SCHEMA --from-beginning --consumer-file-path $CONFIG_DIR/consumer_setting.properties --partition-table-information-path $CONFIG_DIR/partition_table_information.txt
    cd $DIR
}

rsa

install_kafka_debezium_consumer

compile_snapshot

compile_debezium_core

compile_consumer

handle_export

get_partition

handle_import

handle_clean

start_debezium

start_consumer
