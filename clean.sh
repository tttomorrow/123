PG_USER=""
PG_HOST=""
PG_DATA_DIR=""
OG_DATA_DIR=""

if [ -d ~/pg2og_migration/ ]; then
    rm -rf ~/pg2og_migration
fi
if [ -f $OG_DATA_DIR/pg.sql ]; then
    rm -rf $OG_DATA_DIR/pg.sql
fi
ssh $PG_USER@$PG_HOST  << eeooff
    if [ -d ~/pg2og_migration/ ]; then
        rm -rf ~/pg2og_migration
    fi
    if [ -f $PG_DATA_DIR/pg.sql ]; then
        rm -rf $PG_DATA_DIR/pg.sql
    fi
eeooff

curl -X DELETE http://localhost:8083/connectors/fulfillment-connector

echo "clean done!"