#!/bin/bash
# ==========================================
# DB_Check
# Helth check of the database :
#   - Listener
#   - Database running
#   - ORA alert
#   - Tablespaces
#   - Dataguard Check
# -----------------------------------------
# Author : Pascal ALBOUY
#   V1.0 : Hypermonitoring checks
#   V1.1 : Modifing script to check DB
#          for Patch project (Fabien MONS)
# -----------------------------------------
# Parameter :
#   $1 : ORACLE_SID of the DB
# ==========================================
#set -x
script=`basename $0`
db=$1
export RetCode=0

check_fs()
{
#-----------------------------------------------------------------------------------
## df -kh or bdf
if [ "$quoi" = "HP-UX" ]
then
nb=`bdf | egrep '100%|99%|98%' | wc -l`
  if [ $nb -gt 0 ]
  then
    FILESYSTEM="<td> <font color="red"> KO </font> </td>"
	RetCode=$(( RetCode + 1 ))
  else
    FILESYSTEM="<td> <font color="green"> OK </font> </td>"
  fi
else
nb=`df -k | egrep '100%|99%|98%' | wc -l`
  if [ $nb -gt 0 ]
  then
    FILESYSTEM="<td> <font color="red"> KO </font> </td>"
	RetCode=$(( RetCode + 1 ))
  else
    FILESYSTEM="<td> <font color="green"> OK </font> </td>"
  fi
fi
#-----------------------------------------------------------------------------------
}

check_listener()
{
#-----------------------------------------------------------------------------------
# Listener actif and service sur Db
listen=`lsnrctl status | grep $db | grep "Service" | wc -l`
if [ $? -eq 0 ] && [ $listen -gt 0 ]
then
#  if [ -f $TNS_ADMIN/sqlnet.ora ]
#  then
#    cat $TNS_ADMIN/sqlnet.ora | sed '1,\$s/TNSNAMES/TNSNAMES,EZCONNECT/'
#  else
#    echo "NAMES.DIRECTORY_PATH= (TNSNAMES,EZCONNECT) " >> $TNS_ADMIN/sqlnet.ora
#  fi
#  listen=`lsnrctl status | grep $db | grep Service | cut -d'"' -f2 | head -1`
#  sqlplus sys@\"$ou:1521/$listen\" as sysdba << EOF
#  exit
#EOF
#  res=$?
#  if [ $res -eq 0 ]
#  then
    LISTENER="<td> <font color="green"> OK </font> </td>"
#  else
#    LISTENER="<td> <font color="red"> KO </font> </td>"
#  fi
else
  LISTENER="<td> <font color="red"> KO </font> </td>"
  RetCode=$(( RetCode + 1 ))
fi
#-----------------------------------------------------------------------------------
}


# looking for database environment
ORAENV_ASK="NO"
HOME=`pwd`
cd ${HOME}
. ${HOME}/.profile > /dev/null 2>&1
if [ -f ${HOME}/ofa??? ]
then
  # German Database with ofaxxx script
  ofa=`ls -1 $HOME/ofa???|head -1`
  . $ofa ${db} > /dev/null 2>&1
else
  export RAC=${EXPL:-/home/oracle/tools}
  [[ -f ${RAC}/bin/ora_include ]] && . ${RAC}/bin/ora_include
  [[ -f ${RAC}/bin/ostd_include ]] && . ${RAC}/bin/ostd_include
  ora_inst_setenv ${db} 2>/dev/null 1>/dev/null
  if [ $? -ne 0 ]
  then
    if [ -f ${ORACLE_HOME}/bin/oraenv ]
    then
      ORACLE_SID=${db}
      ORAENV_ASK="NO"
      echo " Lancement de ${ORACLE_HOME}/bin/oraenv"
      . ${ORACLE_HOME}/bin/oraenv
    else
      ORACLE_SID=${db}
      ORAENV_ASK="NO"
      echo " Lancement de /usr/local/bin/oraenv"
      . /usr/local/bin/oraenv
    fi
  fi
fi

ou=`uname -n | cut -d'.' -f1`
quoi=`uname -s`
result=/tmp/"$script"_"$db"_"$ou".log
>$result

#-----------------------------------------------------------------------------------
# Base active
active=`ps -edf | grep pmon | grep $db | wc -l`
res=$?
if [ $res -eq 0 ] && [ $active -eq 1 ]
then
  KO="N"
  DATABASE="<td> <font color="green"> OK </font> </td>"
else
  KO="Y"
  DATABASE="<td> <font color="red"> KO </font> </td>"
  RetCode=$(( RetCode + 1 ))
fi

if [ "$KO" = "Y" ]
then
#--------------
# Base Inactive
#--------------

check_fs
check_listener

echo " " >>$result
echo '<table border=1 bordercolor="black" width=1024 cellpadding=2 cellspacing=0><tr><td align=center>6</td><td align=center> Database </td> <td> Check database Status</td> <td align=center> Once a day</td> <td align=center> 7:30 am DST</td> <td align=center> Natco</td>'$DATABASE   >> $result
echo '<tr><td align=center>7</td><td align=center> Database </td><td> Check FS </td><td align=center> Once a day </td><td align=center> 7:30 am DST </td> <td align=center> Natco </td>'$FILESYSTEM >> $result
echo '<tr><td align=center>9</td><td align=center> Database </td><td> Check Listener Status </td><td align=center> Once a day </td><td align=center> 7:30 am DST </td><td align=center> Natco </td>'$LISTENER'</tr></table>' >> $result

else

# -----------
# Base active
# -----------

# Dataguard status
sqlplus -s '/ as sysdba' <<EOF >/tmp/quisuisje$$ 2>&1
set verify off;
set feedback off;
set pagesize 0;
set recsep off;
set tab off;
select 'Database role:'||DATABASE_ROLE||':'
from V\$DATABASE;
EOF
DB_ROLE=`head -1 /tmp/quisuisje$$ | tail -1 | cut -d':' -f2`
rm -f /tmp/quisuisje$$ 

if [[ ( "$DB_ROLE" = "PRIMARY" ) ]]
then

check_fs
check_listener

#-----------------------------------------------------------------------------------
# Look for ORA-
#####sqlplus -s '/ as sysdba' <<EOF >/tmp/release$$ 2>&1
#####set verify off;
#####set feedback off;
#####set pagesize 0;
#####set recsep off;
#####set tab off;
#####select 'RELEASE:'||substr(banner,INSTR(banner,'Edition Release')+16,2)  from v\$version where rownum=1;
#####EOF
#####RELEASE=`head -1 /tmp/release$$ | tail -1 | cut -d':' -f2`
#####if [ "$RELEASE" = "11" ]
#####then
#####sqlplus -s '/ as sysdba' <<EOF >/tmp/errORA$$ 2>&1
#####clear break;
#####clear col;
#####clear compute;
#####ttitle off;
#####set pagesize 50;
#####set linesize 250;
#####set feedback on;
#####set heading on;
#####set wrap off;
#####set feed on;
#####alter session set nls_date_format='DD-MM-YYYY HH24:MI:SS';
#####select originating_timestamp,
#####       message_text
#####from X\$DBGALERTEXT
#####where originating_timestamp > (select startup_time from v\$instance)
#####  and message_text like '%ORA-%'
#####  and message_text not like '%PATROL_TMP%'
#####  and (
#####          message_text not like 'ORA-0001' OR message_text not like 'ORA-00001' OR message_text not like 'ORA-60'
#####       OR message_text not like 'ORA-060' OR message_text not like 'ORA-0060' OR message_text not like 'ORA-00060'
#####       OR message_text not like 'ORA000060' OR message_text not like 'ORA-219' OR message_text not like 'ORA-0219'
#####       OR message_text not like 'ORA-00219' OR message_text not like 'ORA-00230' OR message_text not like 'ORA-604'
#####       OR message_text not like 'ORA-0604' OR message_text not like 'ORA-00604' OR message_text not like 'ORA-609'
#####       OR message_text not like 'ORA-922' OR message_text not like 'ORA-942' OR message_text not like 'ORA-0942'
#####       OR message_text not like 'ORA-00942' OR message_text not like 'ORA-00955' OR message_text not like 'ORA-1002'
#####       OR message_text not like 'ORA-01002' OR message_text not like 'ORA-01013' OR message_text not like 'ORA-01031'
#####       OR message_text not like 'ORA-1119' OR message_text not like 'ORA-01119' OR message_text not like 'ORA-1237'
#####       OR message_text not like 'ORA-01237' OR message_text not like 'ORA-01403' OR message_text not like 'ORA-01422'
#####       OR message_text not like 'ORA-1427' OR message_text not like 'ORA-01427' OR message_text not like 'ORA-01449'
#####       OR message_text not like 'ORA-01466' OR message_text not like 'ORA-1516' OR message_text not like 'ORA-01516'
#####       OR message_text not like 'ORA-1534' OR message_text not like 'ORA-01534' OR message_text not like 'ORA-1543'
#####       OR message_text not like 'ORA-01543' OR message_text not like 'ORA-1555' OR message_text not like 'ORA-01555'
#####       OR message_text not like 'ORA-1593' OR message_text not like 'ORA-01593' OR message_text not like 'ORA-1594'
#####       OR message_text not like 'ORA-01594' OR message_text not like 'ORA-1595' OR message_text not like 'ORA-01595'
#####       OR message_text not like 'ORA-1636' OR message_text not like 'ORA-01598' OR message_text not like 'ORA-01636'
#####       OR message_text not like 'ORA-1652' OR message_text not like 'ORA-01652' OR message_text not like 'ORA-01722'
#####       OR message_text not like 'ORA-01722' OR message_text not like 'ORA-2019' OR message_text not like 'ORA-02019'
#####       OR message_text not like 'ORA-2050' OR message_text not like 'ORA-02050' OR message_text not like 'ORA-2054'
#####       OR message_text not like 'ORA-02054' OR message_text not like 'ORA-2057' OR message_text not like 'ORA-02057'
#####       OR message_text not like 'ORA-2063' OR message_text not like 'ORA-02063' OR message_text not like 'ORA-2068'
#####       OR message_text not like 'ORA-02068' OR message_text not like 'ORA-3214' OR message_text not like 'ORA-03214'
#####       OR message_text not like 'ORA-3297' OR message_text not like 'ORA-03297' OR message_text not like 'ORA-04063'
#####       OR message_text not like 'ORA-06508' OR message_text not like 'ORA-6512' OR message_text not like 'ORA-06512'
#####       OR message_text not like 'ORA-06531' OR message_text not like 'ORA-06550' OR message_text not like 'ORA-06550'
#####       OR message_text not like 'ORA-06575' OR message_text not like 'ORA-12012' OR message_text not like 'ORA-12570'
#####       OR message_text not like 'ORA-16166' OR message_text not like 'ORA-16222' OR message_text not like 'ORA-16222'
#####       OR message_text not like 'ORA-16246' OR message_text not like 'ORA-16246' OR message_text not like 'ORA-20000'
#####       OR message_text not like 'ORA-20001' OR message_text not like 'ORA-27478' OR message_text not like 'ORA-28500'
#####       OR message_text not like 'ORA-29273' OR message_text not like 'ORA-29532' OR message_text not like 'ORA-30951'
#####       OR message_text not like 'ORA-32773'
#####      )
#####order by originating_timestamp
#####;
#####EOF
#####  NB_ERR=`cat /tmp/errORA$$ | grep -i ORA- | wc -l`
#####  if [ $NB_ERR -gt 0 ]
#####  then
#####    ERRORORA="<td> <font color="red"> KO </font> </td>" 
#####	RetCode=$(( RetCode + 1 ))
#####    cat /tmp/errORA$$ >>$result
#####  else
#####    ERRORORA="<td> <font color="green"> OK </font> </td>" 
#####  fi
#####else
###### Previous release to release 11
###### Need to check on alert log
#####sqlplus -s '/ as sysdba' <<EOF >/tmp/errORA$$ 2>&1
#####set verify off;
#####set feedback off;
#####set pagesize 0;
#####set recsep off;
#####set tab off;
#####select 'BDUMP:'||value  from v\$parameter where name like 'background_dump_dest%';
#####EOF
#####  BDUMP=`head -1 /tmp/errORA$$ | tail -1 | cut -d':' -f2`
#####  if [ "$BDUMP" != "" ]
#####  then
#####  cat $BDUMP/alert_$db.log | grep "ORA-" | grep -v PATROL_TMP | egrep -v "PATROL_TMP" | egrep -v "ORA-0001|ORA-00001|ORA-60|ORA-060|ORA-0060|ORA-00060|ORA000060|ORA-219|ORA-0219|ORA-00219|ORA-00230|ORA-604|ORA-0604|ORA-00604|ORA-609|ORA-922|ORA-942|ORA-0942|ORA-00942|ORA-00955|ORA-1002|ORA-01002|ORA-01013|ORA-01031|ORA-1119|ORA-01119|ORA-1237|ORA-01237|ORA-01403|ORA-01422|ORA-1427|ORA-01427|ORA-01449|ORA-01466|ORA-1516|ORA-01516|ORA-1534|ORA-01534|ORA-1543|ORA-01543|ORA-1555|ORA-01555|ORA-1593|ORA-01593|ORA-1594|ORA-01594|ORA-1595|ORA-01595|ORA-1636|ORA-01598|ORA-01636|ORA-1652|ORA-01652|ORA-01722|ORA-01722|ORA-2019|ORA-02019|ORA-2050|ORA-02050|ORA-2054|ORA-02054|ORA-2057|ORA-02057|ORA-2063|ORA-02063|ORA-2068|ORA-02068|ORA-3214|ORA-03214|ORA-3297|ORA-03297|ORA-04063|ORA-06508|ORA-6512|ORA-06512|ORA-06531|ORA-06550|ORA-06550|ORA-06575|ORA-12012|ORA-12570|ORA-16166|ORA-16222|ORA-16222|ORA-16246|ORA-16246|ORA-20000|ORA-20001|ORA-27478|ORA-28500|ORA-29273|ORA-29532|ORA-30951|ORA-32773" >> /tmp/errORA$$
#####  NB_ERR=`cat /tmp/errORA$$ | grep -i ORA- | wc -l`
#####  if [ $NB_ERR -gt 0 ]
#####  then
#####    ERRORORA="<td> <font color="red"> KO </font> </td>" 
#####	RetCode=$(( RetCode + 1 ))
#####    cat /tmp/errORA$$ >>$result
#####  else
#####    ERRORORA="<td> <font color="green"> OK </font> </td>" 
#####  fi
#####  else
#####    ERRORORA="<td> <font color="red"> ?? </font> </td>" 
#####  fi
#####fi
#####rm /tmp/errORA$$
#####rm /tmp/release$$
#-----------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------
# Dataguard status
# Run at beginning to check if PRY or STDY
#sqlplus -s '/ as sysdba' <<EOF >/tmp/quisuisje$$ 2>&1
#set verify off;
#set feedback off;
#set pagesize 0;
#set recsep off;
#set tab off;
#select 'Database role:'||DATABASE_ROLE||':'
#from V\$DATABASE;
#EOF
#DB_ROLE=`head -1 /tmp/quisuisje$$ | tail -1 | cut -d':' -f2`

# Dataguard configuration ?
sqlplus -s '/ as sysdba' <<EOF >/tmp/quisuisje$$ 2>&1
set verify off;
set feedback off;
set pagesize 0;
set recsep off;
set tab off;
select 'DestId:'||DECODE(count(distinct dest_id),0,'NOTDG','1','NOTDG','DG')||':'
from V\$ARCHIVED_LOG;
EOF
DESTID=`head -1 /tmp/quisuisje$$ | tail -1 | cut -d':' -f2`
rm /tmp/quisuisje$$
#
if [[ ( "$DB_ROLE" = "PRIMARY" ) ]] && [[ ( "$DESTID" = "DG" ) ]]
then
sqlplus -s '/ as sysdba' <<EOF >/tmp/dataguardstatus$$ 2>&1
set head off
set feedback off;
set term on;
set verify off;
set recsep off;
set pagesize 0;
set feed off;
set term off;
set trimspool off
set linesize 200
set echo on
set wrap on
select 'PRY:'||pry||':STY:'||sty
from
(
SELECT b.reset_log_time,
       b.last_seq pry,
       nvl(a.applied_seq,0) sty,
       a.last_app_timestamp
FROM
 (SELECT RESETLOGS_ID,max(SEQUENCE#) applied_seq, max(NEXT_TIME) last_app_timestamp
  FROM V\$ARCHIVED_LOG where applied = 'YES'
  group by RESETLOGS_ID ) a,
 (SELECT RESETLOGS_ID, max(NEXT_TIME) last_app_timestamp,max(RESETLOGS_TIME) reset_log_time, MAX (sequence#) last_seq
  FROM V\$ARCHIVED_LOG
  group by RESETLOGS_ID) b
WHERE a.RESETLOGS_ID(+) = b.RESETLOGS_ID
  and b.RESETLOGS_ID = (select max(RESETLOGS_ID) from V\$ARCHIVED_LOG)
)
;
EOF
# delete empty lines
awk 'NF != 0' /tmp/dataguardstatus$$ > /tmp/dataguardstatus2$$

PRY=`head -1 /tmp/dataguardstatus2$$ | tail -1 | cut -d':' -f2`
STY=`head -1 /tmp/dataguardstatus2$$ | tail -1 | cut -d':' -f4`
let diff=$PRY-$STY
if [ $diff -gt 1 ]
then
  DATAGUARD="<td> <font color="red"> KO $PRY:$STY </font> </td>"
  RetCode=$(( RetCode + 1 ))
else
  DATAGUARD="<td> <font color="green"> OK $PRY:$STY </font> </td>"
fi
rm /tmp/dataguardstatus$$
rm /tmp/dataguardstatus2$$
else
  DATAGUARD="<td> <font color="blue"> NA </font> </td>"
fi

#-----------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------
# Sum Up
sqlplus -s '/ as sysdba' <<EOF >>$result
set linesize 600
set pagesize 20
set feed off
set head off
set wrap off
col db format a150
col ch format a49
col once format a35
col heur format a35
col nat format a30
col st format a80
select db,ch,once,heur,nat,st from
(
select 1 a,'<table border=1 bordercolor="black" width=1024 cellpadding=2 cellspacing=0><tr><td align=center>6</td><td align=center> Database </td>' db,'<td> Check database Status</td>' ch,    '<td align=center> Once a day</td>' once,'<td align=center> 7:30 am DST</td>' heur,'<td align=center> Natco</td>' nat,'$DATABASE' st from dual
  union
select 2 a,'<tr><td align=center>7</td><td align=center> Database </td>' db,'<td> Check FS </td>' ch, '<td align=center> Once a day </td>' once,'<td align=center> 7:30 am DST </td>' heur,'<td align=center> Natco </td>' nat,'$FILESYSTEM' st from dual
  union
select 3 a,'<tr><td align=center>8</td><td align=center> Database </td>' db,'<td> ORA error or Alert log </td>' ch,   '<td align=center> Once a day </td>' once,'<td align=center> 7:30 am DST </td>' heur,'<td align=center> Natco </td>' nat,'$ERRORORA' st from dual
  union
select 4 a,'<tr><td align=center>9</td><td align=center> Database </td>' db,'<td> Check Listener Status  </td>' ch,    '<td align=center> Once a day </td>' once,'<td align=center> 7:30 am DST </td>' heur,'<td align=center> Natco </td>' nat,'$LISTENER' st from dual
  union
select 5 a,'<tr><td align=center>10</td><td align=center> Database </td>' db,'<td> Check DB Cluster/Dataguard </td>' ch,'<td align=center> Once a day </td>' once,'<td align=center> 7:30 am DST </td>' heur,'<td align=center> Natco </td>' nat,'$DATAGUARD </tr></table>' st from dual
)
order by a
;
EOF
#-----------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------
echo "" >> $result
echo "<u>Filesystems of $ou server</u> :" >> $result
if [ "$quoi" = "HP-UX" ]
then
bdf >> $result
else
df -k >> $result
fi
#-----------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------
# Tablespace allocation
echo "" >> $result
echo "<u>Tablespaces $db</u> :"  >> $result
echo "" >> $result
sqlplus -s '/ as sysdba' <<EOF >>$result
set linesize 200
set feed off
set pagesize 50
col tbs                                 heading 'Tablespace' format a30;
col max                                 heading 'Max|Autoextend(Mo)' format 9999999999999
col avail                               heading 'Available(Mo)' format 999999999999
col avail                               heading 'Available(Mo)' format 999999999999
col used                                heading 'Used (Mo)' format 9999999999
col pused                               heading '%Used' format 999.99
col pfree                               heading '%Free' format 999.99
SELECT A.tablespace_name tbs,
round(C.max_size) max,
round(C.max_size - A.total_size + B.free_size) avail,
round(A.total_size - B.free_size) used,
round((A.total_size - B.free_size) * 100/ C.max_size) pused,
100-round((A.total_size - B.free_size) * 100/ C.max_size) pfree
FROM
(select tablespace_name, sum((bytes/1024)/1024) total_size
from sys.dba_data_files
group by tablespace_name) A,
(select tablespace_name, sum((bytes/1024)/1024) free_size
from sys.dba_free_space
group by tablespace_name ) B,
(select tablespace_name, sum(decode(AUTOEXTENSIBLE, 'YES',maxbytes,bytes)/1024)/1024 max_size
from sys.dba_data_files
group by tablespace_name) C,
(select name from v\$database) D
WHERE A.tablespace_name = B.tablespace_name(+)
AND A.tablespace_name = C.tablespace_name(+)
AND A.tablespace_name like '%'
order by 1;
EOF
#-----------------------------------------------------------------------------------
# end PRIMARY / STANDBY
fi
# end database is up / down
fi

echo "Exit code: $RetCode"
exit $RetCode
