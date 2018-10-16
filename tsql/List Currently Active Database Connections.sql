--Database Connections Using DMVs in SQL Server 2014
--=============================================
--Database Connections Using DMVs
--=============================================
SELECT DB_NAME(eS.database_id) AS the_database
	, eS.is_user_process
	, COUNT(eS.session_id) AS total_database_connections
FROM sys.dm_exec_sessions eS 
GROUP BY DB_NAME(eS.database_id)
	, eS.is_user_process
ORDER BY 1, 2;

select * from sys.databases
select * from sys.dm_exec_sessions where host_name is not null and database_id=5 --Specify the database id that you want to run this query against 
and original_login_name not in ('EXT09@acuitysso.com','NT AUTHORITY\SYSTEM')

--Database Connections Using sysprocesses in SQL Server 2005 - 2014
--=============================================
--Database Connections Using sys.sysprocesses
--=============================================
SELECT DB_NAME(sP.dbid) AS the_database
	, COUNT(sP.spid) AS total_database_connections
FROM sys.sysprocesses sP
GROUP BY DB_NAME(sP.dbid)
ORDER BY 1;

-- Database Connections Using DMVs in SQL Server 2005-2012
--=============================================
--Database Connections Using DMVs Pre-SQL 2014
--=============================================
SELECT DB_NAME(ST.dbid) AS the_database
	, COUNT(eC.connection_id) AS total_database_connections
FROM sys.dm_exec_connections eC 
	CROSS APPLY sys.dm_exec_sql_text (eC.most_recent_sql_handle) ST
	LEFT JOIN sys.dm_exec_sessions eS 
		ON eC.most_recent_session_id = eS.session_id
GROUP BY DB_NAME(ST.dbid)
ORDER BY 1;

--Database Connections Using Performance Counters
--=====================================================
--Database Connections Using dm_os_performance_counters
--=====================================================
SELECT oPC.cntr_value AS connection_count
FROM sys.dm_os_performance_counters oPC
WHERE 
	(
		oPC.[object_name] = 'SQLServer:General Statistics'
			AND oPC.counter_name = 'User Connections'
	)
ORDER BY 1;


--List Database Connections
SELECT DB_NAME(dbid) as DBName,
       COUNT(dbid) as NumberOfConnections      
FROM sys.sysprocesses
WHERE dbid > 0
GROUP BY dbid, loginame

--List database connections with Login Name
SELECT DB_NAME(dbid) AS DBName,
COUNT(dbid) AS NumberOfConnections,
loginame
FROM    sys.sysprocesses
GROUP BY dbid, loginame
ORDER BY DB_NAME(dbid)



--List number of connections on a database
select a.dbid,b.name, count(a.dbid) as TotalConnections
from sys.sysprocesses a
inner join sys.databases b on a.dbid = b.database_id
where b.name='master'  --Specify database name
group by a.dbid, b.name

--List currently running requests
SELECT
    der.session_id
   ,est.TEXT AS QueryText
   ,der.status
   ,der.blocking_session_id
  ,der.cpu_time
  ,der.total_elapsed_time
FROM sys.dm_exec_requests AS der
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS est


-- Get a count of SQL connections by IP address (Query 10) (Connection Counts by IP Address)    
SELECT ec.client_net_address, es.[program_name], es.[host_name], es.login_name, 
COUNT(ec.session_id) AS [connection count] 
FROM sys.dm_exec_sessions AS es WITH (NOLOCK) 
INNER JOIN sys.dm_exec_connections AS ec WITH (NOLOCK) 
ON es.session_id = ec.session_id 
GROUP BY ec.client_net_address, es.[program_name], es.[host_name], es.login_name  
ORDER BY ec.client_net_address, es.[program_name] OPTION (RECOMPILE);


select @@servername as server, count(distinct usr) as users, count(*) as processes from
( select sp.loginame as usr, sd.name as db
from sysprocesses sp join sysdatabases sd on sp.dbid = sd.dbid ) as db_usage

select usr, count(distinct db) as dbs, count(*) as processes from
( select sp.loginame as usr, sd.name as db
from sysprocesses sp join sysdatabases sd on sp.dbid = sd.dbid ) as db_usage
group by usr
order by usr

select db, usr, count(*) as processes from
( select sp.loginame as usr, sd.name as db
from sysprocesses sp join sysdatabases sd on sp.dbid = sd.dbid ) as db_usage
where db like('%')
group by db, usr
order by db, usr








