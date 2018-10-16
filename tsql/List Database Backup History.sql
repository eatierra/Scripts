SELECT s.database_name 'Database',
CASE s.TYPE
WHEN 'D' THEN 'Full'
WHEN 'I' THEN 'Diff'
WHEN 'L' THEN 'Log'
END 'Backup Type',
CONVERT(VARCHAR(20), s.backup_finish_date, 13) 'Backup Completed',
CAST(mf.physical_device_name AS VARCHAR(100)) 'Physical device name',
DATEDIFF(minute, s.backup_start_date, s.backup_finish_date) 'Duration Min',
CAST(ROUND(s.backup_size * 1.0 / ( 1024 * 1024 ), 2) AS NUMERIC(10, 2)) 'Size in MB',
CAST(ROUND(s.compressed_backup_size * 1.0 / ( 1024 * 1024 ), 2) AS NUMERIC(10, 2)) 'Compressed Size in MB',
CASE WHEN LEFT(mf.physical_device_name, 1) = '{' THEN 'SQL VSS Writer'
WHEN LEFT(mf.physical_device_name, 3) LIKE '[A-Za-z]:\%' THEN 'SQL Backup'
WHEN LEFT(mf.physical_device_name, 2) LIKE '\\' THEN 'SQL Backup'
ELSE mf.physical_device_name
END 'Backup tool'
FROM   msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily mf ON s.media_set_id = mf.media_set_id
WHERE  
s.type in ('D') and 
s.backup_finish_date > DATEADD(DAY, -14, GETDATE()) -- Get history for the past 2 days
ORDER BY s.backup_finish_date DESC;