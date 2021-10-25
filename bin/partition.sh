PG_PORT=""
PG_DBNAME=""
SCHEMA=""

sql="SELECT c.relname FROM pg_catalog.pg_class c LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind IN ('p') AND n.nspname <> 'pg_catalog' AND n.nspname <> 'information_schema' AND n.nspname !~ '^pg_toast' AND pg_catalog.pg_table_is_visible(c.oid);"

result=$(psql -c "$sql" -p $PG_PORT -d $PG_DBNAME)
array=($(echo ${result}))
handle_partition(){
    get_partition_sql="select c.relname from pg_class c join pg_inherits i on i.inhrelid = c. oid join pg_class d on d.oid = i.inhparent where d.relname = '$1' and c.relispartition='t';"
    p_result=$(psql -c "$get_partition_sql" -p $PG_PORT -d $PG_DBNAME)
    p_array=($(echo ${p_result}))
    partition_information=$1
    for(( j=2;j<${#p_array[@]}-2;j++)) do
        partition_information=$partition_information,${p_array[j]}
        sed -i 22a\ "sed -i \"/^COPY[[:space:]]$SCHEMA.${p_array[j]}[[:space:]](.*)[[:space:]]FROM[[:space:]]stdin;/ { s/${p_array[j]}/$1/g;}\"  pg.sql" ~/pg2og_migration/export.sh
    done;
    echo "$partition_information">>~/pg2og_migration/partition_table_information.txt
}
if [ ! -f "~/pg2og_migration/partition_table_information.txt" ]; then
    rm -f ~/pg2og_migration/partition_table_information.txt
fi
for(( i=2;i<${#array[@]}-2;i++)) do
    handle_partition ${array[i]}
done;
