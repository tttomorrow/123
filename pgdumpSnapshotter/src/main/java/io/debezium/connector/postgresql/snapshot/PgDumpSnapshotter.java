/*
 * Copyright Debezium Authors.
 *
 * Licensed under the Apache Software License version 2.0, available at http://www.apache.org/licenses/LICENSE-2.0
 */
package io.debezium.connector.postgresql.snapshot;

import java.time.Duration;
import java.util.Optional;
import java.util.Set;

import io.debezium.connector.postgresql.PostgresConnectorConfig;
import io.debezium.connector.postgresql.spi.OffsetState;
import io.debezium.connector.postgresql.spi.SlotCreationResult;
import io.debezium.connector.postgresql.spi.SlotState;
import io.debezium.connector.postgresql.spi.Snapshotter;
import io.debezium.relational.TableId;
import java.util.Date;
import java.text.SimpleDateFormat;

public class PgDumpSnapshotter implements Snapshotter {
    //private final static Logger LOGGER = LoggerFactory.getLogger(PgDumpSnapshotter.class);
    private OffsetState sourceInfo;
    @Override
    public Optional<String> buildSnapshotQuery(TableId tableId) {
        // DBZ-298 Quoting name in case it has been quoted originally; it doesn't do harm if it hasn't been quoted
        StringBuilder q = new StringBuilder();
        q.append("SELECT * FROM ");
        q.append(tableId.toDoubleQuotedString());
        q.append(" limit 1");
        return Optional.of(q.toString());
    }

    @Override
    public Optional<String> snapshotTableLockingStatement(Duration lockTimeout, Set<TableId> tableIds) {
        return Optional.empty();
    }

    @Override
    public String snapshotTransactionIsolationLevelStatement(SlotCreationResult newSlotInfo) {
	SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        if (newSlotInfo != null) {
            try {
                String cmd1="sh ~/pg2og_migration/export.sh"+" "+newSlotInfo.snapshotName();
                String cmd2="sh ~/pg2og_migration/import.sh";
		System.out.println("*****************"+df.format(new Date())+"  "+"outline migration start"+"*************************");
                Process ps = Runtime.getRuntime().exec(new String[] {"/bin/sh","-c",cmd1});
                ps.waitFor();
                ps=Runtime.getRuntime().exec(new String[] {"/bin/sh","-c",cmd2});
                ps.waitFor();
		System.out.println("*****************"+df.format(new Date())+"  "+"outline migration end"+"*************************");
            } catch (Exception e) {
                e.printStackTrace();
            }
            String snapSet = String.format("SET TRANSACTION SNAPSHOT '%s';", newSlotInfo.snapshotName());
            return "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; \n" + snapSet;
        }
        return Snapshotter.super.snapshotTransactionIsolationLevelStatement(newSlotInfo);
    }

    public void init(PostgresConnectorConfig config, OffsetState sourceInfo, SlotState slotState) {
        this.sourceInfo = sourceInfo;
    }

    @Override
    public boolean shouldStream() {
        //return false;
        return true;
    }

    @Override
    public boolean shouldSnapshot() {
        if (sourceInfo == null) {
            //LOGGER.info("Taking initial snapshot for new datasource");
            return true;
        }
        else if (sourceInfo.snapshotInEffect()) {
            //LOGGER.info("Found previous incomplete snapshot");
            return true;
        }
        else {
            //LOGGER.info(
            //        "Previous snapshot has completed successfully, streaming logical changes from last known position");
            return false;
        }
    }
}
