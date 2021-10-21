PG_HOST=""
PG_USER=""
OG_DBNAME=""
OG_PORT=""
if [ ! -d ~/pg2og_migration/ ];then
    mkdir ~/pg2og_migration/
fi
scp  $PG_USER@$PG_HOST:~/pg2og_migration/pg.sql ~/pg2og_migration/pg.sql
gsql -p $OG_PORT -d $OG_DBNAME -f ~/pg2og_migration/pg.sql
echo "导入数据库成功"
