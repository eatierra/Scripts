USE [msdb]
GO
 
;WITH [MostRecentBackupStatus_CTE]
AS
(
    SELECT  bsfull.[server_name] ,
            bsfull.[database_name] ,
            bsfull.[backup_finish_date] AS [last_full_backup] ,
            bsdiff.[backup_finish_date] AS [last_diff_backup] ,
            bstlog.[backup_finish_date] AS [last_tran_backup] ,
            DATEDIFF(dd, bsfull.[backup_finish_date], CURRENT_TIMESTAMP) AS [days_since_full_backup] ,
            DATEDIFF(dd, bsdiff.[backup_finish_date], CURRENT_TIMESTAMP) AS [days_since_diff_backup] ,
            DATEDIFF(hh, bstlog.[backup_finish_date], CURRENT_TIMESTAMP) AS [hours_since_tranlog_backup] ,
            ( SELECT    [physical_device_name]
              FROM      [msdb]..[backupmediafamily] bmf
              WHERE     bmf.[media_set_id] = bsfull.[media_set_id]
            ) AS [full_backup_location] ,
            ( SELECT    [physical_device_name]
              FROM      [msdb]..[backupmediafamily] bmf
              WHERE     bmf.[media_set_id] = bsdiff.[media_set_id]
            ) AS [diff_backup_location] ,
            ( SELECT    [physical_device_name]
              FROM      [msdb]..[backupmediafamily] bmf
              WHERE     bmf.[media_set_id] = bstlog.[media_set_id]
            ) AS [tlog_backup_location]
    FROM    [msdb]..[backupset] AS bsfull
            LEFT JOIN [msdb]..[backupset] AS bstlog ON bstlog.[database_name] = bsfull.[database_name]
                                                       AND bstlog.[server_name] = bsfull.[server_name]
                                                       AND bstlog.[type] = 'L'
                                                       AND bstlog.[backup_finish_date] = ( (SELECT  MAX([backup_finish_date])
                                                                                            FROM    [msdb]..[backupset] b2
                                                                                            WHERE   b2.[database_name] = bsfull.[database_name]
                                                                                                    AND b2.[server_name] = bsfull.[server_name]
                                                                                                    AND b2.[type] = 'L') )
            LEFT JOIN [msdb]..[backupset] AS bsdiff ON bsdiff.[database_name] = bsfull.[database_name]
                                                       AND bsdiff.[server_name] = bsfull.[server_name]
                                                       AND bsdiff.[type] = 'I'
                                                       AND bsdiff.[backup_finish_date] = ( (SELECT  MAX([backup_finish_date])
                                                                                            FROM    [msdb]..[backupset] b2
                                                                                            WHERE   b2.[database_name] = bsfull.[database_name]
                                                                                                    AND b2.[server_name] = bsfull.[server_name]
                                                                                                    AND b2.[type] = N'I') )
    WHERE   bsfull.[type] = N'D'
            AND bsfull.[backup_finish_date] = ( (SELECT MAX([backup_finish_date])
                                                 FROM   [msdb]..[backupset] b2
                                                 WHERE  b2.[database_name] = bsfull.[database_name]
                                                        AND b2.[server_name] = bsfull.[server_name]
                                                        AND b2.[type] = N'D') )
            AND EXISTS ( SELECT [name]
                         FROM   [master].[sys].[databases]
                         WHERE  [name] = bsfull.[database_name] )
            AND bsfull.[database_name] <> N'tempdb'
)
SELECT  c.[server_name] ,
        c.[database_name] ,
        d.[recovery_model_desc] ,
        c.[last_full_backup] ,
        c.[last_diff_backup] ,
        c.[last_tran_backup] ,
        c.[days_since_full_backup] ,
        c.[days_since_diff_backup] ,
        c.[hours_since_tranlog_backup] ,
        c.[full_backup_location] ,
        c.[diff_backup_location] ,
        c.[tlog_backup_location]
FROM    [MostRecentBackupStatus_CTE] c
        INNER JOIN [master].[sys].[databases] d ON c.[database_name] = d.[name];
GO