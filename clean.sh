#!/bin/sh
curl -X DELETE http://localhost:8083/connectors/fulfillment-connector
echo "clean fulfillment-connector"
ID=`ps -ux | grep "java" | grep -v "grep" | awk '{print $2}'`
echo $ID
for id in $ID
do
    kill -9 $id
    echo "killed $id"
done
echo "clean done!"