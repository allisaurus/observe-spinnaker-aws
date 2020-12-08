-- Count of diff API calls made in last hour
SELECT count(*) AS Total,
         eventname,
         errorcode,
         errormessage
FROM "default"."cloudtrail_logs_aws_athena_spinnaker_eu_west_1"
WHERE useridentity.arn = 'arn:aws:sts::[ACCOUNT]:assumed-role/[ROLE_NAME]/Spinnaker'
        AND from_iso8601_timestamp(eventtime) > date_add('hour', -1, now())
GROUP BY  eventname, errorcode, errormessage