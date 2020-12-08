-- ECS TaskDefinition reads in last 30 minutes
SELECT count(*) AS Total,
         eventname,
         errorcode,
         errormessage
FROM "default"."cloudtrail_logs_[CLOUDTRAIL_BUCKET_NAME]"
WHERE useridentity.arn = 'arn:aws:sts::[ACCT_NUM]:assumed-role/[ROLE_NAME]/Spinnaker'
        AND from_iso8601_timestamp(eventtime) > date_add('minute', -30, now())
        AND eventname in ('ListTaskDefinitions','DescribeTaskDefinition')
GROUP BY  eventname, errorcode, errormessage
ORDER BY  Total desc