#!/bin/bash
date=$(date "+%Y-%m-%d %H:%M:%S")
week=$(date "+%w")
#del_date=`date -d "30 day ago" +%Y-%m-%d`
del_date=$(date +%Y-%m-%d)

app_name=xxx
master_dbname=xxx_master
slave_dbname=xxx_slave

master_db_name=$(cat /home/mysql/dba/userinfo | grep ${master_dbname})
master_ip=$(echo ${master_db_name} | awk '{print $1}')
master_port=$(echo ${master_db_name} | awk '{print $2}')
master_username=$(echo ${master_db_name} | awk '{print $3}')
master_password=$(echo ${master_db_name} | awk '{print $4}')
slave_db_name=$(cat /home/mysql/dba/userinfo | grep ${slave_dbname})
slave_ip=$(echo ${slave_db_name} | awk '{print $1}')
slave_port=$(echo ${slave_db_name} | awk '{print $2}')
slave_username=$(echo ${slave_db_name} | awk '{print $3}')
slave_password=$(echo ${slave_db_name} | awk '{print $4}')

declare -A del_condition
del_condition=(
  [xxx_db.xxx_order_data]="xxx_order_data where create_date < date_add( date('${del_date}'), interval -730 DAY)"
)

for table_name in $(echo ${!del_condition[*]}); do
  db_name=$(echo ${table_name} | awk -F "." '{print $1}')
  table=$(echo ${table_name} | awk -F "." '{print $2}')
  userinfo=$(cat /home/mysql/dba/userinfo | grep "${slave_ip} ${slave_port}" | sed -n 1p)
  ip=$(echo $userinfo | awk '{print $1}')
  port=$(echo $userinfo | awk '{print $2}')
  username=$(echo $userinfo | awk '{print $3}')
  password=$(echo $userinfo | awk '{print $4}')
  for database in $(mysql -h${ip} -P${port} -u${username} -p${password} -e "show databases;"); do
    if [[ ${database} == ${db_name} ]]; then
      /data/datax/job/${app_name}/colm2b.sh ${app_name} ${slave_ip} ${slave_port} "${database}" "${table}" "${del_condition["${table_name}"]}"
      /bin/python3 /data/datax/datax7/bin/datax.py /data/datax/job/${app_name}/${database}.${table}.json >/data/datax/job/${app_name}/${database}.${table}.log
      mysqlCount=$(mysql -u${username} -p${password} -h${ip} -P${port} -e "select count(*) from ${del_condition["${table_name}"]};" ${database} -N)
      bigdataCount=$(cat /data/datax/job/${app_name}/${database}.${table}.log | grep 读出记录总数 | awk '{print $NF}')
      echo "${database}.${table} mysqlCount: $mysqlCount  bigdataCount: $bigdataCount" >>/data/datax/job/${app_name}/arch_${app_name}_mysql.log
      #if [ $? -eq 0 ]; then
      if [ $mysqlCount -eq $bigdataCount ] && [ ! -z $mysqlCount ]; then
        /home/mysql/dba/del_row_arch.sh "${master_dbname}" "${del_condition["${table_name}"]}" "${database}" >>/data/datax/job/${app_name}/arch_${app_name}_mysql.log
        echo "${date} ${database}.${table} has been deleted" >>/data/datax/job/${app_name}/arch_${app_name}_mysql.log
      else
        echo "${date} ${database}.${table} failed" >>/data/datax/job/${app_name}/arch_${app_name}_mysql.log
      fi
    fi
  done
done
