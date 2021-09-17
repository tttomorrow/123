# 工具介绍

本工具为postgresql13至openGauss数据库的迁移工具。

若主机A上运行着postgresql13数据库，主机B上运行着openGauss数据库，需要将postgresql13中数据库DBNAME迁移至openGauss数据库。

# 迁移准备

- postgresql13端

  - 安装wal2json

    ```shell
    git clone https://github.com/eulerto/wal2json.git
    cd wal2json
    make
    make install
    ```
    
  - 更改数据库配置文件postgresql.conf

    1. 添加内容

       ```shell
       shared_preload_libraries = 'wal2json'
       ```

    2. 指定内容

       ```shell
       wal_level = logical             
       max_wal_senders = 1             
       max_replication_slots = 1       
       ```
    
  - postgresql13设置监听

    需设置主机B可以连接主机A的postgresql13数据库

    1. 修改postgresql.conf文件

       ```shell
       #listen_address='localhost'改成
       
       listen_address='*'
       ```

    2. 修改pg_hba.conf文件配置

       添加：

       ```shell
       host	all		all		192.168.0.0/16		trust
       ```

       其中，192.168.0.0/16表示192.168.0.0~192.168.255.255的网段均可访问postgresql13数据库。

  - postgresql13设置允许使用 Debezium 连接器主机进行复制

    配置pg_hba.conf文件

    ```shell
    local   replication     all                          trust   
    host    replication     all  127.0.0.1/32            trust   
    host    replication     all  ::1/128                 trust   
    ```

  - 重启postgresql13数据库

    ```shell
    pg_ctl stop -D XXX/data
    pg_ctl start -D XXX/data
    ```
    
  - 检查待迁移数据库内所有table是否存在主键

    wal2json无法解析没有主键表的插入删除。对于没有主键的表，需要对其进行如下修改：

    ```sql
    alter table tablename replica identity full;
    ```

  - 创建复制用户

    考虑到安全性，最好不要创建最高权限的复制用户，建议创建拥有最低权限的复制用户

    ```sql
    CREATE ROLE copyuser with password 'testdb@1234' REPLICATION LOGIN;
    CREATE ROLE <replication_group>;
    GRANT REPLICATION_GROUP TO <original_owner>;
    GRANT REPLICATION_GROUP TO copyuser;
    ALTER TABLE <table_name> OWNER TO <replication_group>;
    ```
  
- openGauss端

  - 在openGauss创建复制用户，用于JDBC连接

    ```sql
    create user testuser with password 'testdb@1234';
    grant all privileges to testuser;
    ```

  - openGauss配置客户端接入认证
  
    pg_hba.conf添加以下内容
  
    ```shell
    host all all 127.0.0.1/32 sha256
    ```
  
  - openGauss的添加监听
  
    postgresql.conf添加以下内容：
  
    ```
    #listen_addresses='localhost'改成
    
    listen_addresses='*'
    ```
  
  - 创建接收数据库
  
    此工具仅迁移数据库内数据，数据库表结构、索引等需要在opengauss端手动创建。
    
  - 重启opengauss数据库
  
    ```shell
    gs_ctl restart -D XXX/data
    ```

# 迁移工具局限性

- 在数据库迁移过程中，数据库向客户端提供的服务存在一定的局限性（仅支持DML）

  在线迁移模块中的debezium工具仅可以捕获对postgres数据库插入、更新和删除的行级更改，无法捕获到对postgres数据库表结构、表索引等更改。这意味着，在数据库迁移过程中，数据库向客户端提供的服务存在一定的局限性，客户端仅可以对已创建物理表进行插入(insert)、更新(update)和删除(delete)的行级更改，无法创建新表、修改表结构、修改索引等操作。

- 待迁移物理表中不存在中文字符

  在postgres数据库中每个中文字符占用2个字节，而在opengauss中每个中文字符占用3个字节。若待迁移物理表中存在中文字符，可能会出现 value too long for type char(XXX)的错误。

# 迁移工具使用

将迁移工具拷贝至openGauss所在主机

- mvn

  建议3.6.3

- java版本

  java 11

- 配置PostgreSQL 连接器

  配置文件路径：openGauss2postgresql13-tools-migration\config\register-pg13-xtreams.json

  ```json
  {
    "name": "fulfillment-connector",  
    "config": {
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector", 
      "database.hostname": "0.0.0.0", 
      "database.port": "5432", 
      "database.user": "copyuser", 
      "database.password": "testdb@1234", 
      "database.dbname" : "pg_dbname", 
      "database.server.name": "fulfillment", 
      "plugin.name":"wal2json",
      "slot.name":"slotname",
      "provide.transaction.metadata":"true",
      "snapshot.mode":"custom",
      "snapshot.custom.class":"io.debezium.connector.postgresql.snapshot.PgDumpSnapshotter"
    }
  }
  ```

  需更改的配置：

  | 配置名称          | 更改后的内容                          |
  | ----------------- | ------------------------------------- |
  | database.hostname | 装有postgresql13数据库的主机A的IP地址 |
  | database.port     | postgresql13数据库的连接端口          |
  | database.user     | postgresql13数据库中创建的复制用户名  |
  | database.password | 复制用户的密码                        |
  | database.dbname   | 待迁移数据库名                        |

- 配置消费者端JDBC

  配置文件路径：openGauss2postgresql13-tools-migration\config\consumer_setting.properties

  ```shell
  bootstrap.servers=localhost:9092
  enable.auto.commit=False
  auto.commit.interval.ms=1000
  key.deserializer=org.apache.kafka.common.serialization.StringDeserializer
  value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
  lsnfile=lsn.txt
  database.server.name=fulfillment
  group.id=consumer
  database.driver.classname=org.postgresql.Driver
  database.url=jdbc:postgresql://127.0.0.1:5432/og_dbname?stringtype=unspecified
  database.user=testuser
  database.password=testdb@1234
  ```

  需更改的配置：

  | 配置名称             | 更改后的内容                                                 |
  | -------------------- | ------------------------------------------------------------ |
  | database.server.name | 需要同register-pg13-xtreams.json中database.server.name相同   |
  | database.url         | jdbc:postgresql://127.0.0.1:port/dbname  其中，port为opengauss的连接端口，dbname为待迁移数据库名 |
  | database.user        | openGauss数据库中创建复制用户                                |
  | database.password    | 复制用户的密码                                               |

- 配置openGauss2postgresql13-tools-migration\migration.sh

  | 变量名称  | 添加内容                               |
  | --------- | -------------------------------------- |
  | SCHEMA    | 待迁移schema，若无schema，则填入public |
  | PG_HOST   | postgres所在主机ip                     |
  | PG_USER   | postgres的安装用户                     |
  | PG_PORT   | 待迁移postgres数据库连接端口           |
  | PG_DBNAME | 待迁移postgres数据库名称               |
  | OG_PORT   | 本机openGauss数据库连接端口            |
  | OG_DBNAME | 本机openGauss端接收数据库名称          |

- 运行shell脚本

  `sh migration.sh`

