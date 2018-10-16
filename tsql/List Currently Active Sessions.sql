--List currently active sessions
USE master
go
SELECT
     sdes.session_id
    ,sdes.login_time
    ,sdes.last_request_start_time
    ,sdes.last_request_end_time
    ,sdes.is_user_process
    ,sdes.host_name
    ,sdes.program_name
    ,sdes.login_name
    ,sdes.status

    ,sdec.num_reads
    ,sdec.num_writes
    ,sdec.last_read
    ,sdec.last_write
    ,sdes.reads
    ,sdes.logical_reads
    ,sdes.writes

    ,sdest.DatabaseName
    ,sdest.ObjName
    ,sdes.client_interface_name
    ,sdes.nt_domain
    ,sdes.nt_user_name
    ,sdec.client_net_address
    ,sdec.local_net_address
    ,sdest.Query
    ,KillCommand  = 'Kill '+ CAST(sdes.session_id  AS VARCHAR)
FROM sys.dm_exec_sessions AS sdes

INNER JOIN sys.dm_exec_connections AS sdec
        ON sdec.session_id = sdes.session_id

CROSS APPLY (

    SELECT DB_NAME(dbid) AS DatabaseName
        ,OBJECT_NAME(objectid) AS ObjName
        ,COALESCE((
            SELECT TEXT AS [processing-instruction(definition)]
            FROM sys.dm_exec_sql_text(sdec.most_recent_sql_handle)
            FOR XML PATH('')
                ,TYPE
            ), '') AS Query

    FROM sys.dm_exec_sql_text(sdec.most_recent_sql_handle)

) sdest
WHERE sdes.session_id <> @@SPID
  AND sdest.DatabaseName ='master'
--ORDER BY sdes.last_request_start_time DESC


SELECT   
    c.session_id, c.net_transport, c.encrypt_option,   
    c.auth_scheme, s.host_name, s.program_name,   
    s.client_interface_name, s.login_name, s.nt_domain,   
    s.nt_user_name, s.original_login_name, c.connect_time,   
    s.login_time   
FROM sys.dm_exec_connections AS c  
JOIN sys.dm_exec_sessions AS s  
    ON c.session_id = s.session_id  


--Get the currently running queries
SELECT sqltext.TEXT,
req.session_id,
req.status,
req.command,
req.cpu_time,
req.total_elapsed_time
FROM sys.dm_exec_requests req
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext