-- Errors seen in previous hour
SELECT eventtime,
         eventsource,
         eventname,
         errorcode,
         errormessage,
         requestparameters
FROM "default"."cloudtrail_logs_[CLOUDTRAIL_BUCKET_NAME]"
WHERE useridentity.arn = 'arn:aws:sts::[ACCT_NUM]:assumed-role/[ROLE_NAME]/Spinnaker'
        AND errorcode is NOT null
        AND from_iso8601_timestamp(eventtime) > date_add('hour', -1, now())