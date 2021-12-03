PG_HOST=""
PG_USER=""
PG_DBNAME=""
PG_PORT=""
SCHEMA=""
PG_DATA_DIR=""
DATA_DIR=~/pg2og_migration

ssh $PG_USER@$PG_HOST  << eeooff
exportdb(){
    cd ~/pg2og_migration
    echo "" > pg.log
    if [ ! -f $DATA_DIR/pg.sql ];then
        pg_dump -p $PG_PORT -a $PG_DBNAME --schema=$SCHEMA --snapshot=$1 > $PG_DATA_DIR/pg.sql
    else
        echo "重写覆盖$DATA_DIR/pg.sql" >> pg.log
        pg_dump -p $PG_PORT -a $PG_DBNAME --schema=$SCHEMA --snapshot=$1 > $PG_DATA_DIR/pg.sql
    fi
    echo "成功导出数据库$PG_DBNAME至$PG_DATA_DIR/pg.sql" >> pg.log
}

handle_sql(){
    sed -i '/^SET.*/d' $PG_DATA_DIR/pg.sql
    sed -i '/^SELECT.*/d' $PG_DATA_DIR/pg.sql
}
echo "pg_dump -p $PG_PORT -a $PG_DBNAME --snapshot=$1 > $PG_DATA_DIR/pg.sql" >> pg.log
exportdb $1
handle_sql
eeooff