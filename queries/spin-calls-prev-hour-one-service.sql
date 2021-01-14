-- all calls made in past hour by a specific AWS service
SELECT count(*) AS Total,
         eventname,
         errorcode,
         errormessage
FROM "default"."cloudtrail_logs_[CLOUDTRAIL_BUCKET_NAME]"
WHERE useridentity.arn = 'arn:aws:sts::[ACCOUNT_ID]:assumed-role/SpinnakerManaged/Spinnaker'
        AND from_iso8601_timestamp(eventtime) > date_add('hour', -1, now())
        AND eventsource like 'elasticloadbalancing.amazonaws.com'  -- swap "elasticloadbalancing" for desired service
GROUP BY  eventname, errorcode, errormessage
ORDER BY  Total desc