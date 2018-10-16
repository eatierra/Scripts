select * from SYS.CONFIGURATIONS

-- Get I/O utilization by database (Query 8) (IO Usage By Database)
WITH Aggregate_IO_Statistics
AS
(SELECT DB_NAME(database_id) AS [Database Name],
CAST(SUM(num_of_bytes_read + num_of_bytes_written)/1048576 AS DECIMAL(12, 2)) AS io_in_mb
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS [DM_IO_STATS]
--WHERE database_id NOT IN (4, 5, 32767)
GROUP BY database_id)
SELECT ROW_NUMBER() OVER(ORDER BY io_in_mb DESC) AS [I/O Rank], [Database Name], 
      CAST(io_in_mb/ SUM(io_in_mb) OVER() * 100.0 AS DECIMAL(5,2)) AS [I/O Percent],
      io_in_mb AS [Total I/O (MB)]     
FROM Aggregate_IO_Statistics
ORDER BY [I/O Rank] OPTION (RECOMPILE);

-- Get a count of SQL connections by IP address (Query 10) (Connection Counts by IP Address)    
SELECT ec.client_net_address, es.[program_name], es.[host_name], es.login_name, 
COUNT(ec.session_id) AS [connection count] 
FROM sys.dm_exec_sessions AS es WITH (NOLOCK) 
INNER JOIN sys.dm_exec_connections AS ec WITH (NOLOCK) 
ON es.session_id = ec.session_id 
GROUP BY ec.client_net_address, es.[program_name], es.[host_name], es.login_name  
ORDER BY ec.client_net_address, es.[program_name] OPTION (RECOMPILE);

-- Azure SQL Database size  (Query 17) (Azure SQL DB Size)
SELECT CAST(SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS bigint) * 8192.) / 1024 / 1024 AS DECIMAL(15,2)) AS [Database Size In MB],
       CAST(SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS bigint) * 8192.) / 1024 / 1024 / 1024 AS DECIMAL(15,2)) AS [Database Size In GB]
FROM sys.database_files WITH (NOLOCK)
WHERE [type_desc] = N'ROWS' OPTION (RECOMPILE);

-- Detect blocking (run multiple times)  (Query 12) (Detect Blocking)						
-- Helps troubleshoot blocking and deadlocking issues
-- The results will change from second to second on a busy system
-- You should run this query multiple times when you see signs of blocking
SELECT t1.resource_type AS [lock type], DB_NAME(resource_database_id) AS [database],
t1.resource_associated_entity_id AS [blk object],t1.request_mode AS [lock req],  -- lock requested
t1.request_session_id AS [waiter sid], t2.wait_duration_ms AS [wait time],       -- spid of waiter  
(SELECT [text] FROM sys.dm_exec_requests AS r WITH (NOLOCK)                      -- get sql for waiter
CROSS APPLY sys.dm_exec_sql_text(r.[sql_handle]) 
WHERE r.session_id = t1.request_session_id) AS [waiter_batch],
(SELECT SUBSTRING(qt.[text],r.statement_start_offset/2, 
    (CASE WHEN r.statement_end_offset = -1 
    THEN LEN(CONVERT(nvarchar(max), qt.[text])) * 2 
    ELSE r.statement_end_offset END - r.statement_start_offset)/2) 
FROM sys.dm_exec_requests AS r WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(r.[sql_handle]) AS qt
WHERE r.session_id = t1.request_session_id) AS [waiter_stmt],					-- statement blocked
t2.blocking_session_id AS [blocker sid],										-- spid of blocker
(SELECT [text] FROM sys.sysprocesses AS p										-- get sql for blocker
CROSS APPLY sys.dm_exec_sql_text(p.[sql_handle]) 
WHERE p.spid = t2.blocking_session_id) AS [blocker_batch]
FROM sys.dm_tran_locks AS t1 WITH (NOLOCK)
INNER JOIN sys.dm_os_waiting_tasks AS t2 WITH (NOLOCK)
ON t1.lock_owner_address = t2.resource_address OPTION (RECOMPILE);
------


-- Individual File Sizes and space available for current database  (Query 18) (File Sizes and Space)
SELECT f.name AS [File Name] , f.physical_name AS [Physical Name], 
CAST((f.size/128.0) AS DECIMAL(15,2)) AS [Total Size in MB],
CAST(f.size/128.0 - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int)/128.0 AS DECIMAL(15,2)) 
AS [Available Space In MB], f.[file_id], fg.name AS [Filegroup Name],
f.is_percent_growth, f.growth, fg.is_default, fg.is_read_only, 
fg.is_autogrow_all_files
FROM sys.database_files AS f WITH (NOLOCK) 
LEFT OUTER JOIN sys.filegroups AS fg WITH (NOLOCK)
ON f.data_space_id = fg.data_space_id
ORDER BY f.[file_id] OPTION (RECOMPILE);


-- Log space usage for current database  (Query 19) (Log Space Usage)
SELECT DB_NAME(lsu.database_id) AS [Database Name], db.recovery_model_desc AS [Recovery Model],
		CAST(lsu.total_log_size_in_bytes/1048576.0 AS DECIMAL(10, 2)) AS [Total Log Space (MB)],
		CAST(lsu.used_log_space_in_bytes/1048576.0 AS DECIMAL(10, 2)) AS [Used Log Space (MB)], 
		CAST(lsu.used_log_space_in_percent AS DECIMAL(10, 2)) AS [Used Log Space %],
		CAST(lsu.log_space_in_bytes_since_last_backup/1048576.0 AS DECIMAL(10, 2)) AS [Used Log Space Since Last Backup (MB)],
		db.log_reuse_wait_desc		 
FROM sys.dm_db_log_space_usage AS lsu WITH (NOLOCK)
INNER JOIN sys.databases AS db WITH (NOLOCK)
ON lsu.database_id = db.database_id
OPTION (RECOMPILE);
------


-- Status of last VLF for current database  (Query 20) (Last VLF Status)
SELECT TOP(1) DB_NAME(li.database_id) AS [Database Name], li.[file_id],
               li.vlf_size_mb, li.vlf_sequence_number, li.vlf_active, li.vlf_status
FROM sys.dm_db_log_info(DB_ID()) AS li 
ORDER BY vlf_sequence_number DESC OPTION (RECOMPILE);


-- Get database scoped configuration values for current database (Query 21) (Database-scoped Configurations)
SELECT configuration_id, name, [value] AS [value_for_primary]
FROM sys.database_scoped_configurations WITH (NOLOCK) OPTION (RECOMPILE);
------

-- Get most frequently executed queries for this database (Query 24) (Query Execution Counts)
SELECT TOP(50) LEFT(t.[text], 50) AS [Short Query Text], qs.execution_count AS [Execution Count],
qs.total_logical_reads AS [Total Logical Reads],
qs.total_logical_reads/qs.execution_count AS [Avg Logical Reads],
qs.total_worker_time AS [Total Worker Time],
qs.total_worker_time/qs.execution_count AS [Avg Worker Time], 
qs.total_elapsed_time AS [Total Elapsed Time],
qs.total_elapsed_time/qs.execution_count AS [Avg Elapsed Time], 
qs.creation_time AS [Creation Time]
--,t.[text] AS [Complete Query Text], qp.query_plan AS [Query Plan] -- uncomment out these columns if not copying results to Excel
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp 
WHERE t.dbid = DB_ID()
ORDER BY qs.execution_count DESC OPTION (RECOMPILE);

--Get the currently running queries
SELECT sqltext.TEXT,
req.session_id,
req.status,
req.command,
req.cpu_time,
req.total_elapsed_time
FROM sys.dm_exec_requests req
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext


-- Get top total worker time queries for this database (Query 25) (Top Worker Time Queries)
-- Helps you find the most expensive queries from a CPU perspective for this database
-- Can also help track down parameter sniffing issues		
SELECT TOP(50) DB_NAME(t.[dbid]) AS [Database Name], 
REPLACE(REPLACE(LEFT(t.[text], 50), CHAR(10),''), CHAR(13),'') AS [Short Query Text],  
qs.total_worker_time AS [Total Worker Time], qs.min_worker_time AS [Min Worker Time],
qs.total_worker_time/qs.execution_count AS [Avg Worker Time], 
qs.max_worker_time AS [Max Worker Time], 
qs.min_elapsed_time AS [Min Elapsed Time], 
qs.total_elapsed_time/qs.execution_count AS [Avg Elapsed Time], 
qs.max_elapsed_time AS [Max Elapsed Time],
qs.min_logical_reads AS [Min Logical Reads],
qs.total_logical_reads/qs.execution_count AS [Avg Logical Reads],
qs.max_logical_reads AS [Max Logical Reads], 
qs.execution_count AS [Execution Count], qs.creation_time AS [Creation Time]
--,t.[text] AS [Query Text], qp.query_plan AS [Query Plan] -- uncomment out these columns if not copying results to Excel
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
WHERE t.dbid = DB_ID() 
ORDER BY qs.total_worker_time DESC OPTION (RECOMPILE);

-- Get top total logical reads queries for this database (Query 26) (Top Logical Reads Queries) 
-- Helps you find the most expensive queries from a memory perspective for this database
-- Can also help track down parameter sniffing issues   
SELECT TOP(50) DB_NAME(t.[dbid]) AS [Database Name],
REPLACE(REPLACE(LEFT(t.[text], 50), CHAR(10),''), CHAR(13),'') AS [Short Query Text], 
qs.total_logical_reads AS [Total Logical Reads],
qs.min_logical_reads AS [Min Logical Reads],
qs.total_logical_reads/qs.execution_count AS [Avg Logical Reads],
qs.max_logical_reads AS [Max Logical Reads],   
qs.min_worker_time AS [Min Worker Time],
qs.total_worker_time/qs.execution_count AS [Avg Worker Time], 
qs.max_worker_time AS [Max Worker Time], 
qs.min_elapsed_time AS [Min Elapsed Time], 
qs.total_elapsed_time/qs.execution_count AS [Avg Elapsed Time], 
qs.max_elapsed_time AS [Max Elapsed Time],
qs.execution_count AS [Execution Count], qs.creation_time AS [Creation Time]
--,t.[text] AS [Complete Query Text], qp.query_plan AS [Query Plan] -- uncomment out these columns if not copying results to Excel
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS t 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
WHERE t.dbid = DB_ID()  
ORDER BY qs.total_logical_reads DESC OPTION (RECOMPILE);

-- Lists the top statements by average input/output usage for the current database  (Query 34) (Top IO Statements)
-- Helps you find the most expensive statements for I/O by SP
SELECT TOP(50) OBJECT_NAME(qt.objectid, dbid) AS [SP Name],
(qs.total_logical_reads + qs.total_logical_writes) /qs.execution_count AS [Avg IO], qs.execution_count AS [Execution Count],
SUBSTRING(qt.[text],qs.statement_start_offset/2, 
	(CASE 
		WHEN qs.statement_end_offset = -1 
	 THEN LEN(CONVERT(nvarchar(max), qt.[text])) * 2 
		ELSE qs.statement_end_offset 
	 END - qs.statement_start_offset)/2) AS [Query Text]	
FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt
WHERE qt.[dbid] = DB_ID()
ORDER BY [Avg IO] DESC OPTION (RECOMPILE);
------


-- Possible Bad NC Indexes (writes > reads)  (Query 35) (Bad NC Indexes)
-- Look for indexes with high numbers of writes and zero or very low numbers of reads
-- Consider your complete workload, and how long your instance has been running
-- Investigate further before dropping an index!
SELECT OBJECT_NAME(s.[object_id]) AS [Table Name], i.name AS [Index Name], i.index_id, 
i.is_disabled, i.is_hypothetical, i.has_filter, i.fill_factor,
user_updates AS [Total Writes], user_seeks + user_scans + user_lookups AS [Total Reads],
user_updates - (user_seeks + user_scans + user_lookups) AS [Difference]
FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
ON s.[object_id] = i.[object_id]
AND i.index_id = s.index_id
WHERE OBJECTPROPERTY(s.[object_id],'IsUserTable') = 1
AND s.database_id = DB_ID()
AND user_updates > (user_seeks + user_scans + user_lookups)
AND i.index_id > 1
ORDER BY [Difference] DESC, [Total Writes] DESC, [Total Reads] ASC OPTION (RECOMPILE);

-- Missing Indexes for current database by Index Advantage  (Query 36) (Missing Indexes)
-- Look at index advantage, last user seek time, number of user seeks to help determine source and importance
-- SQL Server is overly eager to add included columns, so beware
-- Do not just blindly add indexes that show up from this query!!!
SELECT DISTINCT CONVERT(decimal(18,2), user_seeks * avg_total_user_cost * (avg_user_impact * 0.01)) AS [index_advantage], 
migs.last_user_seek, mid.[statement] AS [Database.Schema.Table],
mid.equality_columns, mid.inequality_columns, mid.included_columns,
migs.unique_compiles, migs.user_seeks, migs.avg_total_user_cost, migs.avg_user_impact,
OBJECT_NAME(mid.[object_id]) AS [Table Name], p.rows AS [Table Rows]
FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK)
ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK)
ON mig.index_handle = mid.index_handle
INNER JOIN sys.partitions AS p WITH (NOLOCK)
ON p.[object_id] = mid.[object_id]
WHERE mid.database_id = DB_ID() 
ORDER BY index_advantage DESC OPTION (RECOMPILE);

-- Find missing index warnings for cached plans in the current database  (Query 37) (Missing Index Warnings)
-- Note: This query could take some time on a busy instance
-- Helps you connect missing indexes to specific stored procedures or queries
-- This can help you decide whether to add them or not
SELECT TOP(25) OBJECT_NAME(objectid) AS [ObjectName], 
               cp.objtype, cp.usecounts, cp.size_in_bytes, query_plan
FROM sys.dm_exec_cached_plans AS cp WITH (NOLOCK)
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
WHERE CAST(query_plan AS NVARCHAR(MAX)) LIKE N'%MissingIndex%'
AND dbid = DB_ID()
ORDER BY cp.usecounts DESC OPTION (RECOMPILE);


-- Fin the missing index request using the query store
SELECT
    SUM(qrs.count_executions) * AVG(qrs.avg_logical_io_reads) as est_logical_reads,
    SUM(qrs.count_executions) AS sum_executions,
    AVG(qrs.avg_logical_io_reads) AS avg_avg_logical_io_reads,
    SUM(qsq.count_compiles) AS sum_compiles,
    (SELECT TOP 1 qsqt.query_sql_text FROM sys.query_store_query_text qsqt
        WHERE qsqt.query_text_id = MAX(qsq.query_text_id)) AS query_text,    
    TRY_CONVERT(XML, (SELECT TOP 1 qsp2.query_plan from sys.query_store_plan qsp2
        WHERE qsp2.query_id=qsq.query_id
        ORDER BY qsp2.plan_id DESC)) AS query_plan,
    qsq.query_id,
    qsq.query_hash
FROM sys.query_store_query qsq
JOIN sys.query_store_plan qsp on qsq.query_id=qsp.query_id
CROSS APPLY (SELECT TRY_CONVERT(XML, qsp.query_plan) AS query_plan_xml) AS qpx
JOIN sys.query_store_runtime_stats qrs on qsp.plan_id = qrs.plan_id
JOIN sys.query_store_runtime_stats_interval qsrsi on qrs.runtime_stats_interval_id=qsrsi.runtime_stats_interval_id
WHERE    
    qsp.query_plan like N'%<MissingIndexes>%'
    and qsrsi.start_time >= DATEADD(HH, -24, SYSDATETIME())
GROUP BY qsq.query_id, qsq.query_hash
ORDER BY est_logical_reads DESC
GO



-- Breaks down buffers used by current database by object (table, index) in the buffer cache  (Query 38) (Buffer Usage)
-- Note: This query could take some time on a busy instance
-- Tells you what tables and indexes are using the most memory in the buffer cache
-- It can help identify possible candidates for data compression
SELECT OBJECT_NAME(p.[object_id]) AS [Object Name], p.index_id, 
CAST(COUNT(*)/128.0 AS DECIMAL(10, 2)) AS [Buffer size(MB)],  
COUNT(*) AS [BufferCount], p.[Rows] AS [Row Count],
p.data_compression_desc AS [Compression Type]
FROM sys.allocation_units AS a WITH (NOLOCK)
INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK)
ON a.allocation_unit_id = b.allocation_unit_id
INNER JOIN sys.partitions AS p WITH (NOLOCK)
ON a.container_id = p.hobt_id
WHERE b.database_id = CONVERT(int, DB_ID())
AND p.[object_id] > 100
AND OBJECT_NAME(p.[object_id]) NOT LIKE N'plan_%'
AND OBJECT_NAME(p.[object_id]) NOT LIKE N'sys%'
AND OBJECT_NAME(p.[object_id]) NOT LIKE N'xml_index_nodes%'
GROUP BY p.[object_id], p.index_id, p.data_compression_desc, p.[Rows]
ORDER BY [BufferCount] DESC OPTION (RECOMPILE);
------


-- Look at most frequently modified indexes and statistics (Query 42) (Volatile Indexes)
-- This helps you understand your workload and make better decisions about 
-- things like data compression and adding new indexes to a table
SELECT o.[name] AS [Object Name], o.[object_id], o.[type_desc], s.[name] AS [Statistics Name], 
       s.stats_id, s.no_recompute, s.auto_created, s.is_incremental, s.is_temporary,
	   sp.modification_counter, sp.[rows], sp.rows_sampled, sp.last_updated
FROM sys.objects AS o WITH (NOLOCK)
INNER JOIN sys.stats AS s WITH (NOLOCK)
ON s.object_id = o.object_id
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
WHERE o.[type_desc] NOT IN (N'SYSTEM_TABLE', N'INTERNAL_TABLE')
AND sp.modification_counter > 0
ORDER BY sp.modification_counter DESC, o.name OPTION (RECOMPILE);





-- Get Table names, row counts, and compression status for clustered index or heap  (Query 39) (Table Sizes)
-- Gives you an idea of table sizes, and possible data compression opportunities
SELECT OBJECT_NAME(object_id) AS [ObjectName], 
SUM(Rows) AS [RowCount], data_compression_desc AS [CompressionType]
FROM sys.partitions WITH (NOLOCK)
WHERE index_id < 2 --ignore the partitions from the non-clustered index if any
AND OBJECT_NAME(object_id) NOT LIKE N'sys%'
AND OBJECT_NAME(object_id) NOT LIKE N'queue_%' 
AND OBJECT_NAME(object_id) NOT LIKE N'filestream_tombstone%' 
AND OBJECT_NAME(object_id) NOT LIKE N'fulltext%'
AND OBJECT_NAME(object_id) NOT LIKE N'ifts_comp_fragment%'
AND OBJECT_NAME(object_id) NOT LIKE N'filetable_updates%'
AND OBJECT_NAME(object_id) NOT LIKE N'xml_index_nodes%'
AND OBJECT_NAME(object_id) NOT LIKE N'sqlagent_job%'  
AND OBJECT_NAME(object_id) NOT LIKE N'plan_persist%'  
GROUP BY object_id, data_compression_desc
ORDER BY SUM(Rows) DESC OPTION (RECOMPILE);



-- When were Statistics last updated on all indexes?  (Query 41) (Statistics Update)
-- Helps discover possible problems with out-of-date statistics
-- Also gives you an idea which indexes are the most active

-- sys.stats (Transact-SQL)
-- https://msdn.microsoft.com/en-us/library/ms177623.aspx

SELECT SCHEMA_NAME(o.Schema_ID) + N'.' + o.[NAME] AS [Object Name], o.[type_desc] AS [Object Type],
      i.[name] AS [Index Name], STATS_DATE(i.[object_id], i.index_id) AS [Statistics Date], 
      s.auto_created, s.no_recompute, s.user_created, s.is_incremental, s.is_temporary,
	  st.row_count, st.used_page_count
FROM sys.objects AS o WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
ON o.[object_id] = i.[object_id]
INNER JOIN sys.stats AS s WITH (NOLOCK)
ON i.[object_id] = s.[object_id] 
AND i.index_id = s.stats_id
INNER JOIN sys.dm_db_partition_stats AS st WITH (NOLOCK)
ON o.[object_id] = st.[object_id]
AND i.[index_id] = st.[index_id]
WHERE o.[type] IN ('U', 'V')
AND st.row_count > 0
ORDER BY STATS_DATE(i.[object_id], i.index_id) DESC OPTION (RECOMPILE);

SELECT CURRENT_TIMESTAMP;
--- Index Read/Write stats (all tables in current DB) ordered by Reads  (Query 44) (Overall Index Usage - Reads)
-- Show which indexes in the current database are most active for Reads
SELECT OBJECT_NAME(i.[object_id]) AS [ObjectName], i.[name] AS [IndexName], i.index_id, 
       s.user_seeks, s.user_scans, s.user_lookups,
	   s.user_seeks + s.user_scans + s.user_lookups AS [Total Reads], 
	   s.user_updates AS [Writes],  
	   i.[type_desc] AS [Index Type], i.fill_factor AS [Fill Factor], i.has_filter, i.filter_definition, 
	   s.last_user_scan, s.last_user_lookup, s.last_user_seek
FROM sys.indexes AS i WITH (NOLOCK)
LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
ON i.[object_id] = s.[object_id]
AND i.index_id = s.index_id
AND s.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.[object_id],'IsUserTable') = 1
ORDER BY s.user_seeks + s.user_scans + s.user_lookups DESC OPTION (RECOMPILE); -- Order by reads



--- Index Read/Write stats (all tables in current DB) ordered by Writes  (Query 45) (Overall Index Usage - Writes)
-- Show which indexes in the current database are most active for Writes
SELECT OBJECT_NAME(i.[object_id]) AS [ObjectName], i.[name] AS [IndexName], i.index_id,
	   s.user_updates AS [Writes], s.user_seeks + s.user_scans + s.user_lookups AS [Total Reads], 
	   i.[type_desc] AS [Index Type], i.fill_factor AS [Fill Factor], i.has_filter, i.filter_definition,
	   s.last_system_update, s.last_user_update
FROM sys.indexes AS i WITH (NOLOCK)
LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
ON i.[object_id] = s.[object_id]
AND i.index_id = s.index_id
AND s.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.[object_id],'IsUserTable') = 1
ORDER BY s.user_updates DESC OPTION (RECOMPILE);						 -- Order by writes


-- Get database automatic tuning options (Query 54) (Automatic Tuning Options)
-- sys.database_automatic_tuning_options (Transact-SQL)
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-automatic-tuning-options-transact-sql
SELECT [name], desired_state_desc, actual_state_desc, reason_desc
FROM sys.database_automatic_tuning_options WITH (NOLOCK)
OPTION (RECOMPILE);



