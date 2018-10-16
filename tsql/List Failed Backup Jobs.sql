SELECT j.job_id, j.name 
FROM msdb.dbo.sysjobs j
  JOIN msdb.dbo.syscategories c
    ON j.category_id = c.category_id
  JOIN (SELECT h1.job_id, h1.run_status
FROM msdb.dbo.sysjobhistory AS h1
  JOIN (SELECT job_id, MAX(instance_id) AS instance_id
FROM msdb.dbo.sysjobhistory
WHERE step_id = 0
GROUP BY job_id) AS h2
ON h1.job_id = h2.job_id AND h1.instance_id = h2.instance_id) AS h
    ON j.job_id = h.job_id
WHERE j.[enabled] = 1
  AND h.run_status = 0
  AND c.[name] = 'Backups'; 