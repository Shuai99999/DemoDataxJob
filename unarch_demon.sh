condition=$1
impala-shell -i 19.236.33.44:21001 -u hive -l --auth_creds_ok_in_clear --ldap_password_cmd="echo -n '密码'" --quiet -q "select <cols> from archive_mysql_db.xxxapp_<table_name> where ${condition};" |grep -v '+----' | sed -n '1p' |sed 's/|/','/g'| awk '$1=$1'|sed 's/, //1' |sed '$s/,$//'>insert

impala-shell -i 19.236.33.44:21001 -u hive -l --auth_creds_ok_in_clear --ldap_password_cmd="echo -n '密码'" --quiet -q "select <cols> from archive_mysql_db.xxxapp_<table_name> where ${condition};" |grep -v '+----' |sed -n '2,$p'|sed 's/|/'\',\''/g' | awk '{gsub(/ /, ""); print}' |sed "s/',//1" |sed 's/..$//'>values

> final_res

insert=`cat insert`

IFS=$'\n\n'
for value in `cat values`
do
echo "insert into <table_name>(${insert}) values(${value});" >> final_res
done

mysql -uxxx -pxxx -hxxx -P3306 -e "source /data/datax/demon/unarch_xxxapp/unarch_from_bigdata/final_res;" xxxdb
