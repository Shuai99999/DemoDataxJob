app_name=$1
slave_ip=$2
slave_port=$3
schema=$4
table_name=$5
where=$6

SCHEMA=$(echo ${schema} | tr a-z A-Z)
CT=$(mysql -uxxx -pxxx -h${slave_ip} -P${slave_port} -e "SET SESSION group_concat_max_len=4294967295;SELECT concat('CREATE TABLE archive_mysql_db.', upper(TABLE_SCHEMA), '_', TABLE_NAME, '(', group_concat(concat ( case lower(column_name) when 'fields' then 'convert_fields' when 'timestamp' then 'convert_timestamp' when 'percent' then 'convert_percent' when 'method' then 'convert_method' when 'sort' then 'convert_sort' when 'role' then 'convert_role' else lower(column_name) end, ' ', case data_type when 'char' then 'STRING' when 'varchar' then 'STRING' when 'time' then 'STRING' when 'blob' then 'STRING'  when 'longtext' then 'STRING' when 'bigint' then 'BIGINT' when 'tinyint' then 'TINYINT' when 'smallint' then 'SMALLINT' when 'decimal'   then 'DOUBLE' when 'double' then 'DOUBLE' when 'float' then 'DOUBLE' when 'datetime' then 'TIMESTAMP' when 'timestamp' then 'TIMESTAMP' when 'int' then 'INT' when 'date' then 'STRING'  when 'bit' then 'BOOLEAN' when 'text' then 'STRING' when 'mediumblob' then 'STRING' when 'longblob' then 'STRING' when 'mediumtext' then 'STRING' ELSE 'STRING' END, ' comment ', '\'', COLUMN_COMMENT, '\'') order by ORDINAL_POSITION), ')' , ' stored as orc;') from  information_schema.columns WHERE TABLE_SCHEMA= '${schema}' and TABLE_NAME='${table_name}';" ${schema} -N | grep -v '+----')
echo $CT

impala-shell -i 10.246.86.47:21001 -u hive -l --auth_creds_ok_in_clear --ldap_password_cmd="echo -n 'Hive,2023'" -q "${CT} commit;"

#mycol=`mysql -uxxx -pxxx -h${slave_ip} -P${slave_port} -e "desc ${table_name};" ${schema} -N |awk '{print "\""$1"\"""\,"}'| sed '$s/.$//'`

mysqlColumns=$(mysql -uxxx -pxxx -h${slave_ip} -P${slave_port} -e "desc ${table_name};" ${schema} -N | awk '{print $1}' | sed 's/^/"/g' | sed 's/$/",/g' | sed '$s/,//g')

echo ${mysqlColumns} >/data/datax/job/${app_name}/mytemp

mysqlColumnsQuery=$(mysql -uxxx -pxxx -h${slave_ip} -P${slave_port} -e "desc ${table_name};" ${schema} -N | awk '{print $1}' | awk '{{printf"%s,",$0}}' | sed 's/.$//')

myPk=$(mysql -uxxx -pxxx -h${slave_ip} -P${slave_port} -e "desc ${table_name};" ${schema} -N | grep PRI | sed -n 1p | awk '{print $1}')

if [ ! ${myPk} ]; then
  myPk=$(mysql -uxxx -pxxx -h${slave_ip} -P${slave_port} -e "show create table ${table_name};" ${schema} -N | awk -F "PARTITION BY" '{print $2}' | awk -F "(" '{print $2}' | awk -F ")" '{print $1}')
fi

query="select ${mysqlColumnsQuery} from ${where};"
mycol=$(cat /data/datax/job/${app_name}/mytemp)

bigcols=$(impala-shell -i 10.246.86.47:21001 -u hive -l --auth_creds_ok_in_clear --ldap_password_cmd="echo -n 'Hive,2023'" --quiet -q "desc archive_mysql_db.${SCHEMA}_${table_name}" | grep -v '+----' | sed -n '2,$p' | awk -F "|" '{print "{\"name\":\""$2"\", \"type\":\""$3"\"},"}' | awk '$1=$1' | sed '$s/.$//')

echo ${bigcols} >/data/datax/job/${app_name}/bigtemp
sed -i s/"\" "/"\""/g /data/datax/job/${app_name}/bigtemp
sed -i s/" \""/"\""/g /data/datax/job/${app_name}/bigtemp
bigcol=$(cat /data/datax/job/${app_name}/bigtemp)

cp /data/datax/job/${app_name}/m2b.json /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<schema>"/"${schema}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<table_name>"/"${table_name}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<mycol>"/"${mycol}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<bigcol>"/"${bigcol}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
#sed -i s/"<myPk>"/"${myPk}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<myPk>"/""/g /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<query>"/"${query}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<slave_ip>"/"${slave_ip}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
sed -i s/"<slave_port>"/"${slave_port}"/g /data/datax/job/${app_name}/${schema}.${table_name}.json
