PG_HOST=""
PG_USER=""
PG_DATA_DIR=""
OG_DBNAME=""
OG_PORT=""
OG_DATA_DIR=""
if [ ! -d ~/pg2og_migration/ ];then
    mkdir ~/pg2og_migration/
fi
if [ ! -d $OG_DATA_DIR ];then
    mkdir $OG_DATA_DIR
fi
scp  $PG_USER@$PG_HOST:$PG_DATA_DIR/pg.sql $OG_DATA_DIR/pg.sql
gsql -p $OG_PORT -d $OG_DBNAME -f $OG_DATA_DIR/pg.sql
echo "导入数据库成功"
