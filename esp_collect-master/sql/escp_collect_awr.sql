----------------------------------------------------------------------------------------
--
-- File name:   escp_collect_awr.sql (2016-06-01)
--
-- Purpose:     Collect Resources Metrics for an Oracle Database
--
-- Author:      Carlos Sierra
--
-- Usage:       Extract from AWR a subset of:
--
--                  view                         resource(s)
--                  ---------------------------- -----------------
--                  DBA_HIST_ACTIVE_SESS_HISTORY CPU
--                  DBA_HIST_SGA                 MEM
--                  DBA_HIST_PGASTAT             MEM
--                  DBA_HIST_TBSPC_SPACE_USAGE   DISK
--                  DBA_HIST_LOG                 DISK
--                  DBA_HIST_SYSSTAT             IOPS MBPS NETW IC
--                  DBA_HIST_DLM_MISC            IC
--                  DBA_HIST_OSSTAT              OS
--
--              Collections from this script are consumed by the ESCP tool.
--
-- Example:     # cd escp_collect
--              # sqlplus / as sysdba
--              SQL> START sql/escp_master.sql
--
-- Notes:       Developed and tested on 11.2.0.3, 12.1.0.2
--
-- Warning:     Requires a license for the Oracle Diagnostics Pack
--
---------------------------------------------------------------------------------------
--
DEF ESCP_MAX_DAYS = '365';
DEF ESCP_DATE_FORMAT = 'YYYY-MM-DD"T"HH24:MI:SS';

SET TERM OFF ECHO OFF FEED OFF VER OFF HEA OFF PAGES 0 COLSEP ', ' LIN 32767 TRIMS ON TRIM ON TI OFF TIMI OFF ARRAY 100 NUM 20 SQLBL ON BLO . RECSEP OFF;

ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ".,";
ALTER SESSION SET NLS_SORT = 'BINARY';
ALTER SESSION SET NLS_COMP = 'BINARY';
ALTER SESSION SET NLS_DATE_FORMAT = '&&ESCP_DATE_FORMAT.';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT = '&&ESCP_DATE_FORMAT.';

-- get host name (up to 30, stop before first '.', no special characters)
DEF escp_host_name_short = '';
COL escp_host_name_short NEW_V escp_host_name_short FOR A30;
SELECT LOWER(SUBSTR(SYS_CONTEXT('USERENV', 'SERVER_HOST'), 1, 30)) escp_host_name_short FROM DUAL;
SELECT SUBSTR('&&escp_host_name_short.', 1, INSTR('&&escp_host_name_short..', '.') - 1) escp_host_name_short FROM DUAL;
SELECT TRANSLATE('&&escp_host_name_short.',
'abcdefghijklmnopqrstuvwxyz0123456789-_ ''`~!@#$%&*()=+[]{}\|;:",.<>/?'||CHR(0)||CHR(9)||CHR(10)||CHR(13)||CHR(38),
'abcdefghijklmnopqrstuvwxyz0123456789-_') escp_host_name_short FROM DUAL;

-- get collection date
DEF escp_collection_yyyymmdd = '';
COL escp_collection_yyyymmdd NEW_V escp_collection_yyyymmdd FOR A8;
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD') escp_collection_yyyymmdd FROM DUAL;

-- get collection days
DEF escp_collection_days = '&&ESCP_MAX_DAYS.';
COL escp_collection_days NEW_V escp_collection_days;
SELECT NVL(TO_CHAR(LEAST(EXTRACT(DAY FROM retention), TO_NUMBER('&&ESCP_MAX_DAYS.'))), '&&ESCP_MAX_DAYS.') escp_collection_days FROM dba_hist_wr_control;

COL escp_this_dbid NEW_V escp_this_dbid;
SELECT 'get_dbid', TO_CHAR(dbid) escp_this_dbid FROM v$database
/

COL escp_this_inst_num NEW_V escp_this_inst_num;
SELECT 'get_instance_number', TO_CHAR(instance_number) escp_this_inst_num FROM v$instance
/

DEF escp_min_snap_id = '';
COL escp_min_snap_id NEW_V escp_min_snap_id;
SELECT 'get_min_snap_id', TO_CHAR(MIN(snap_id)) escp_min_snap_id FROM dba_hist_snapshot WHERE dbid = &&escp_this_dbid. AND CAST(begin_interval_time AS DATE) > SYSDATE - &&escp_collection_days.
/
SELECT NVL('&&escp_min_snap_id.','0') escp_min_snap_id FROM DUAL
/

DEF;

---------------------------------------------------------------------------------------

SPO escp_&&escp_host_name_short._&&escp_collection_yyyymmdd..csv APP;

COL escp_metric_group    FOR A8;
COL escp_metric_acronym  FOR A16;
COL escp_instance_number FOR A4;
COL escp_end_date        FOR A20;
COL escp_value           FOR A128;

-- header
SELECT 'METGROUP'       escp_metric_group,
       'METRIC_ACRONYM' escp_metric_acronym,
       'INST'           escp_instance_number,
       'END_DATE'       escp_end_date,
       'VALUE'          escp_value 
  FROM DUAL
/

SELECT 'BEGIN'                    escp_metric_group,
       d.name                     escp_metric_acronym,
       TO_CHAR(i.instance_number) escp_instance_number,
       SYSDATE                    escp_end_date,
       i.host_name                escp_value 
  FROM v$instance i, 
       v$database d
/

-- collection user
SELECT 'COLLECT' escp_metric_group,
       'USER'    escp_metric_acronym,
       NULL      escp_instance_number,
       NULL      escp_end_date,
       USER      escp_value 
  FROM v$instance
/

-- collection days
SELECT 'COLLECT'                                  escp_metric_group,
       'DAYS'                                     escp_metric_acronym,
       NULL                                       escp_instance_number,
       TO_CHAR(SYSDATE - &&escp_collection_days.) escp_end_date,
       '&&escp_collection_days.'                  escp_value 
  FROM v$instance
/

---------------------------------------------------------------------------------------

-- database dbid
SELECT 'DATABASE'       escp_metric_group,
       'DBID'           escp_metric_acronym,
       NULL             escp_instance_number,
       NULL             escp_end_date,
       TO_CHAR(dbid)    escp_value 
  FROM v$database
/

-- database name
SELECT 'DATABASE'       escp_metric_group,
       'NAME'           escp_metric_acronym,
       NULL             escp_instance_number,
       NULL             escp_end_date,
       name             escp_value 
  FROM v$database
/

-- database created
SELECT 'DATABASE'       escp_metric_group,
       'CREATED'        escp_metric_acronym,
       NULL             escp_instance_number,
       NULL             escp_end_date,
       TO_CHAR(created) escp_value 
  FROM v$database
/

-- database db_unique_name
SELECT 'DATABASE'       escp_metric_group,
       'DB_UNIQUE_NAME' escp_metric_acronym,
       NULL             escp_instance_number,
       NULL             escp_end_date,
       db_unique_name   escp_value 
  FROM v$database
/

-- database instance_name_min
SELECT 'DATABASE'         escp_metric_group,
       'INST_NAME_MIN'    escp_metric_acronym,
       NULL               escp_instance_number,
       NULL               escp_end_date,
       MIN(instance_name) escp_value 
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
/

-- database instance_name_max
SELECT 'DATABASE'         escp_metric_group,
       'INST_NAME_MAX'    escp_metric_acronym,
       NULL               escp_instance_number,
       NULL               escp_end_date,
       MAX(instance_name) escp_value 
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
/

-- database host_name_min
SELECT 'DATABASE'      escp_metric_group,
       'HOST_NAME_MIN' escp_metric_acronym,
       NULL            escp_instance_number,
       NULL            escp_end_date,
       MIN(host_name)  escp_value 
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
/

-- database host_name_max
SELECT 'DATABASE'      escp_metric_group,
       'HOST_NAME_MAX' escp_metric_acronym,
       NULL            escp_instance_number,
       NULL            escp_end_date,
       MAX(host_name)  escp_value 
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
/

-- database version
SELECT 'DATABASE' escp_metric_group,
       'VERSION'  escp_metric_acronym,
       NULL       escp_instance_number,
       NULL       escp_end_date,
       version    escp_value 
  FROM v$instance
/

-- database platform_name
SELECT 'DATABASE'    escp_metric_group,
       'PLATFORM'    escp_metric_acronym,
       NULL          escp_instance_number,
       NULL          escp_end_date,
       platform_name escp_value 
  FROM v$database
/

-- database db_block_size
SELECT 'DATABASE'           escp_metric_group,
       'DB_BLOCK_SIZE'      escp_metric_acronym,
       NULL                 escp_instance_number,
       NULL                 escp_end_date,
       SUBSTR(value, 1, 10) escp_value 
  FROM v$system_parameter2
 WHERE name = 'db_block_size'
/

-- database min_instance_host_id
SELECT 'DATABASE'                    escp_metric_group,
       'MIN_INST_HOST'               escp_metric_acronym,
       TO_CHAR(MIN(instance_number)) escp_instance_number,
       NULL                          escp_end_date,
       MIN(host_name)                escp_value 
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
   AND instance_number IN (
SELECT MIN(instance_number) 
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
)
/

---------------------------------------------------------------------------------------

-- instance instance_name
WITH
all_instances AS (
SELECT instance_number, MAX(startup_time) max_startup_time
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
 GROUP BY 
       instance_number
)
SELECT 'INSTANCE'                 escp_metric_group,
       'INSTANCE_NAME'            escp_metric_acronym,
       TO_CHAR(h.instance_number) escp_instance_number,
       h.startup_time             escp_end_date,
       h.instance_name            escp_value
  FROM all_instances a,
       dba_hist_database_instance h
 WHERE h.dbid = &&escp_this_dbid.
   AND h.instance_number = a.instance_number
   AND h.startup_time = a.max_startup_time
 ORDER BY
       h.instance_number
/

-- instance host_name
WITH
all_instances AS (
SELECT instance_number, MAX(startup_time) max_startup_time
  FROM dba_hist_database_instance
 WHERE dbid = &&escp_this_dbid.
 GROUP BY 
       instance_number
)
SELECT 'INSTANCE'                 escp_metric_group,
       'HOST_NAME'                escp_metric_acronym,
       TO_CHAR(h.instance_number) escp_instance_number,
       h.startup_time             escp_end_date,
       h.host_name                escp_value
  FROM all_instances a,
       dba_hist_database_instance h
 WHERE h.dbid = &&escp_this_dbid.
   AND h.instance_number = a.instance_number
   AND h.startup_time = a.max_startup_time
 ORDER BY
       h.instance_number
/

---------------------------------------------------------------------------------------

-- DBA_HIST_ACTIVE_SESS_HISTORY CPU
SELECT 'CPU'                      escp_metric_group,
       CASE h.session_state 
       WHEN 'ON CPU' THEN 'CPU' 
       ELSE 'RMCPUQ' 
       END                        escp_metric_acronym,
       TO_CHAR(h.instance_number) escp_instance_number,
       h.sample_time              escp_end_date,
       TO_CHAR(COUNT(*))          escp_value
  FROM dba_hist_active_sess_history h
 WHERE h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND (h.session_state = 'ON CPU' OR h.event = 'resmgr:cpu quantum')
   AND h.sample_time >= SYSTIMESTAMP - &&escp_collection_days.
 GROUP BY
       h.session_state,
       h.instance_number,
       h.sample_time
 ORDER BY
       h.session_state,
       h.instance_number,
       h.sample_time
/

-- DBA_HIST_SGA MEM
SELECT 'MEM'                      escp_metric_group,
       'SGA'                      escp_metric_acronym,
       TO_CHAR(h.instance_number) escp_instance_number,
       s.end_interval_time        escp_end_date,
       TO_CHAR(SUM(h.value))      escp_value
  FROM dba_hist_sga      h,
       dba_hist_snapshot s
 WHERE h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
   AND s.end_interval_time >= SYSTIMESTAMP - &&escp_collection_days.
 GROUP BY
       h.instance_number,
       s.end_interval_time
 ORDER BY
       h.instance_number,
       s.end_interval_time
/

-- DBA_HIST_PGASTAT MEM
SELECT 'MEM'                      escp_metric_group,
       'PGA'                      escp_metric_acronym,
       TO_CHAR(h.instance_number) escp_instance_number,
       s.end_interval_time        escp_end_date,
       TO_CHAR(h.value)           escp_value
  FROM dba_hist_pgastat  h,
       dba_hist_snapshot s
 WHERE h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND h.name = 'total PGA allocated'
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
   AND s.end_interval_time >= SYSTIMESTAMP - &&escp_collection_days.
 ORDER BY
       h.instance_number,
       s.end_interval_time
/

-- DBA_HIST_TBSPC_SPACE_USAGE DISK
SELECT 'DISK'                                         escp_metric_group,
       SUBSTR(t.contents, 1, 4)                       escp_metric_acronym,
       NULL                                           escp_instance_number,
       s.end_interval_time                            escp_end_date,
       TO_CHAR(SUM(h.tablespace_size * t.block_size)) escp_value
  FROM dba_hist_tbspc_space_usage h,
       dba_hist_snapshot          s,
       v$tablespace               v,
       dba_tablespaces            t
 WHERE h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = &&escp_this_inst_num.
   AND s.end_interval_time >= SYSTIMESTAMP - &&escp_collection_days.
   AND v.ts# = h.tablespace_id
   AND t.tablespace_name = v.name
 GROUP BY
       t.contents,
       s.end_interval_time
 ORDER BY
       t.contents,
       s.end_interval_time
/

-- DBA_HIST_LOG DISK
SELECT 'DISK'                            escp_metric_group,
       'LOG'                             escp_metric_acronym,
       NULL                              escp_instance_number,
       s.end_interval_time               escp_end_date,
       TO_CHAR(SUM(h.bytes * h.members)) escp_value
  FROM dba_hist_log      h,
       dba_hist_snapshot s
 WHERE h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = &&escp_this_inst_num.
   AND s.end_interval_time >= SYSTIMESTAMP - &&escp_collection_days.
 GROUP BY
       s.end_interval_time
 ORDER BY
       s.end_interval_time
/

-- DBA_HIST_SYSSTAT IOPS MBPS NETW IC
SELECT CASE h.stat_name
       WHEN 'physical read total IO requests'        THEN 'IOPS'
       WHEN 'physical write total IO requests'       THEN 'IOPS'
       WHEN 'redo writes'                            THEN 'IOPS'
       WHEN 'physical read total bytes'              THEN 'MBPS'
       WHEN 'physical write total bytes'             THEN 'MBPS'
       WHEN 'redo size'                              THEN 'MBPS'
       WHEN 'bytes sent via SQL*Net to client'       THEN 'NETW'
       WHEN 'bytes received via SQL*Net from client' THEN 'NETW'
       WHEN 'bytes sent via SQL*Net to dblink'       THEN 'NETW'
       WHEN 'bytes received via SQL*Net from dblink' THEN 'NETW'
       WHEN 'gc cr blocks received'                  THEN 'IC'
       WHEN 'gc current blocks received'             THEN 'IC'
       WHEN 'gc cr blocks served'                    THEN 'IC'
       WHEN 'gc current blocks served'               THEN 'IC'
       WHEN 'gcs messages sent'                      THEN 'IC'
       WHEN 'ges messages sent'                      THEN 'IC'
       END                                           escp_metric_group,
       CASE h.stat_name
       WHEN 'physical read total IO requests'        THEN 'RREQS'
       WHEN 'physical write total IO requests'       THEN 'WREQS'
       WHEN 'redo writes'                            THEN 'WREDO'
       WHEN 'physical read total bytes'              THEN 'RBYTES'
       WHEN 'physical write total bytes'             THEN 'WBYTES'
       WHEN 'redo size'                              THEN 'WREDOBYTES'
       WHEN 'bytes sent via SQL*Net to client'       THEN 'TOCLIENT'
       WHEN 'bytes received via SQL*Net from client' THEN 'FROMCLIENT'
       WHEN 'bytes sent via SQL*Net to dblink'       THEN 'TODBLINK'
       WHEN 'bytes received via SQL*Net from dblink' THEN 'FROMDBLINK'
       WHEN 'gc cr blocks received'                  THEN 'GCCRBR'
       WHEN 'gc current blocks received'             THEN 'GCCBLR'
       WHEN 'gc cr blocks served'                    THEN 'GCCRBS'
       WHEN 'gc current blocks served'               THEN 'GCCBLS'
       WHEN 'gcs messages sent'                      THEN 'GCSMS'
       WHEN 'ges messages sent'                      THEN 'GESMS'
       END                                           escp_metric_acronym,
       TO_CHAR(h.instance_number)                    escp_instance_number,
       s.end_interval_time                           escp_end_date,
       TO_CHAR(h.value)                              escp_value
  FROM dba_hist_sysstat  h,
       dba_hist_snapshot s
 WHERE h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND h.stat_name IN (
       'physical read total IO requests',
       'physical write total IO requests',
       'redo writes',
       'physical read total bytes',
       'physical write total bytes',
       'redo size',
       'bytes sent via SQL*Net to client',
       'bytes received via SQL*Net from client',
       'bytes sent via SQL*Net to dblink',
       'bytes received via SQL*Net from dblink',
       'gc cr blocks received',
       'gc current blocks received',
       'gc cr blocks served',
       'gc current blocks served',
       'gcs messages sent',
       'ges messages sent'
       )
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
   AND s.end_interval_time >= SYSTIMESTAMP - &&escp_collection_days.
 ORDER BY
       CASE h.stat_name
       WHEN 'physical read total IO requests'        THEN 1.1
       WHEN 'physical write total IO requests'       THEN 1.2
       WHEN 'redo writes'                            THEN 1.3
       WHEN 'physical read total bytes'              THEN 2.1
       WHEN 'physical write total bytes'             THEN 2.2
       WHEN 'redo size'                              THEN 2.3
       WHEN 'bytes sent via SQL*Net to client'       THEN 3.1
       WHEN 'bytes received via SQL*Net from client' THEN 3.2
       WHEN 'bytes sent via SQL*Net to dblink'       THEN 3.3
       WHEN 'bytes received via SQL*Net from dblink' THEN 3.4
       WHEN 'gc cr blocks received'                  THEN 4.1
       WHEN 'gc current blocks received'             THEN 4.2
       WHEN 'gc cr blocks served'                    THEN 4.3
       WHEN 'gc current blocks served'               THEN 4.4
       WHEN 'gcs messages sent'                      THEN 4.5
       WHEN 'ges messages sent'                      THEN 4.6
       END,
       h.instance_number,
       s.end_interval_time
/

-- DBA_HIST_DLM_MISC IC
SELECT 'IC'                       escp_metric_group,
       CASE h.name
       WHEN 'gcs msgs received' THEN 'GCSMR'
       WHEN 'ges msgs received' THEN 'GESMR'
       END                        escp_metric_acronym,
       TO_CHAR(h.instance_number) escp_instance_number,
       s.end_interval_time        escp_end_date,
       TO_CHAR(h.value)           escp_value
  FROM dba_hist_dlm_misc h,
       dba_hist_snapshot s
 WHERE h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND h.name IN (
       'gcs msgs received',
       'ges msgs received'
       )
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
   AND s.end_interval_time >= SYSTIMESTAMP - &&escp_collection_days.
 ORDER BY
       CASE h.name
       WHEN 'gcs msgs received' THEN 1
       WHEN 'ges msgs received' THEN 2
       END,
       h.instance_number,
       s.end_interval_time
/

-- DBA_HIST_OSSTAT OS
SELECT 'OS'                       escp_metric_group,
       CASE h.stat_name
       WHEN 'LOAD'                  THEN 'OSLOAD'
       WHEN 'NUM_CPUS'              THEN 'OSCPUS'
       WHEN 'NUM_CPU_CORES'         THEN 'OSCORES'
       WHEN 'PHYSICAL_MEMORY_BYTES' THEN 'OSMEMBYTES'
       END                        escp_metric_acronym,
       TO_CHAR(h.instance_number) escp_instance_number,
       s.end_interval_time        escp_end_date,
       TO_CHAR(h.value)           escp_value
  FROM dba_hist_osstat   h,
       dba_hist_snapshot s
 WHERE h.stat_name IN ('LOAD', 'NUM_CPUS', 'NUM_CPU_CORES', 'PHYSICAL_MEMORY_BYTES')
   AND h.snap_id >= &&escp_min_snap_id.
   AND h.dbid = &&escp_this_dbid.
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
   AND s.end_interval_time >= SYSTIMESTAMP - &&escp_collection_days.
 ORDER BY
       CASE h.stat_name
       WHEN 'LOAD'                  THEN 1
       WHEN 'NUM_CPUS'              THEN 2
       WHEN 'NUM_CPU_CORES'         THEN 3
       WHEN 'PHYSICAL_MEMORY_BYTES' THEN 4
       END,
       h.instance_number,
       s.end_interval_time
/   

---------------------------------------------------------------------------------------

-- collection end
SELECT 'END'                      escp_metric_group,
       d.name                     escp_metric_acronym,
       TO_CHAR(i.instance_number) escp_instance_number,
       SYSDATE                    escp_end_date,
       i.host_name                escp_value 
  FROM v$instance i, 
       v$database d
/

SPO OFF;
SET TERM ON ECHO OFF FEED ON VER ON HEA ON PAGES 14 COLSEP ' ' LIN 80 TRIMS OFF TRIM ON TI OFF TIMI OFF ARRAY 15 NUM 10 SQLBL OFF BLO ON RECSEP WR;
