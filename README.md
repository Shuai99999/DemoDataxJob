这是一个 MySQL 归档历史数据到 impala 的 demo，通过 datax 这个开源工具归档历史数据并校验数据后在 MySQL 端删除已归档的数据，之后用户只能在 impala 端查询数据。 1.调用 arch_xxx_mysql.sh，
app_name=xxx 系统名称
master_dbname=xxx_master 数据库主库地址名称（在另一个数据库密码文件中，每个数据库都有自己的名字）
slave_dbname=xxx_slave 数据库从库地址名称
在 del_condition 中填入要归档的表和条件，这是一个 shell 的字典，有多个表就换行填入多个即可

2.调用 colm2b.sh，生成 datax 要使用的 json 文件

3.执行 datax 抽取数据

4.校验抽取的数据和 MySQL 中符合条件的数据量是否一致

5.若一致，则在 MySQL 端执行删除这些已归档的数据

另外，下面这个脚本是反向同步的，也就是拉归档，如果数据已归档而业务需要把它拉回来，可以通过这个脚本实现
unarch_demon.sh
