# Set up query-able Spinnaker API logs with AWS CloudTrail + Amazon Athena

Spinnaker operators deploying to AWS often need visibility into what APIs Spinnaker is calling and with what effect. This repository documents how to instrument and query your API logs using Amazon S3, AWS CloudTrail, and Amazon Athena. The end goal is the ability to run SQL queries against Spinnaker's activity in AWS for debugging or operational purposes.

**NOTE:** This repository exists mostly for testing purposes and should not be considered authoritative over the offical AWS docs. Content will grow and change over time.

<!-- toc -->

- [Requirements](#Requirements)
- [Getting started](#getting-started)
- [Creating a trail](#creating-a-trail)
- [Creating a table in Athena](#creating-a-table-in-athena)
- [Query Spinnaker calls](#query-spinnaker-calls)
- [Graphing CloudTrail activity](#graphing-cloudtrail-activity)
- [Pricing](#pricing)

<!-- tocstop -->

### Requirements
* A Spinnaker installation deploying to one or more AWS regions where AWS CloudTrail and Amazon Athena are available. (Should be pretty much everywhere, but to confirm you can find your region [here for AWS CloudTrail](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-supported-regions.html) and [here for Amazon Athena](https://docs.aws.amazon.com/es_en/general/latest/gr/athena.html)).
  * NOTE: technically Athena only needs query the S3 bucket where the trail is placing logs, but having the trail and its Athena table in the same region lets you take advantage of some AWS console niceties.
* Minimally one Amazon S3 bucket to store CloudTrail logs and associated Athena query output (can also be stored separately in two buckets).
* Permissions to create & modify the above resources. 
* For queries: the Amazon Resource Name (ARN) of the IAM role(s) used by Spinnaker to deploy into your account.

### Created resources
At the end of these steps you should have the following resources:
* A CloudTrail trail in the region(s) of your choice. 
* An S3 bucket that holds the CloudTrail logs.
* An Amazon Athena table which references the logs and can be queried with SQL.
* An S3 bucket that contains query output. 


## Getting started

For this example, I want to query the activity of a Spinnaker instance that assumes the IAM role `SpinnakerManagedCA` and deploys to Amazon ECS in the `ca-central-1` region. I also have an S3 bucket called `aws-athena-spinnaker-ca-central-1` which I created to house my CloudTrail logs.

## Creating a trail

### AWS Console instructions
1. Navigate the AWS CloudTrail console in `ca-central-1` (or the region where Spinnaker is deploying your resoruces).
2. Click "View trails", then "Create trail".
3. Give the new trail a name. I call mine `spinnaker-dev-instance`.
4. Select "No" for whether the trail applies to all regions. 
  * (If your Spinnaker install is deploying to multiple regions and you want to capture them all in one trail/table, you can select "Yes".)
5. Leave 'Management' and 'Insight' event defaults as-is. These can be edited later if desired.
6. Under 'Storage location' select whether to create a new bucket or use an existing one. I have one already, so I select "No", and find and select my `aws-athena-spinnaker-ca-central-1` bucket.
7. Apply tags as desired.
8. Click "Create".

After the trail is created, it should just take a minute or two for your CloudTrail logs start appearing in the specified S3 bucket under the path `AWSLogs/[ACCOUNT_NUM]/CloudTrail/[REGION]/[YEAR]/[MONTH]/[DAY]/`

> IMAGE TBD

### Command line instructions
* TBD

## Creating a table in Athena

### AWS Console instructions
Querying AWS CloudTrail logs is a common enough use case that there's a console shortcut which will do most setup automatically.

1. In the CloudTrail console where you created the trail, navigate to "Event history".
2. Click "Run advanced queries in Amazon Athena".
3. In the modal "Storage location", select the bucket which contains the logs from our newly created trail, `aws-athena-spinnaker-ca-central-1`. 
4. Click "Create table".
5. Once created, click the button that takes you to the Athena console to run some queries.

### Command line instructions
* TBD


See the full docs on [using Athena to query AWS CloudTrail logs](https://docs.aws.amazon.com/athena/latest/ug/cloudtrail-logs.html) for more info.


## Query Spinnaker calls

After completing the above, you should see a table in the Athena console called `cloudtrail_logs_[BUCKET]`. Before you can run queries, you need to configure a storage location for your query results.

* Click the link in the blue banner to configure your query storage location. (This can be configured in the future under "Settings")
* In "Query result location" type in the S3 bucket address where you want the results to be sent. e.g., `s3://aws-athena-spinnaker-ca-central-1/queries/`
  * For testing, I'm using a folder within the bucket where my logs are housed but you may want to separate them to facilitate diff monitoring/permissions.

Now you're ready to query your Spinnaker API calls!

### Test query: What API calls is Spinnaker actually making?

It can be useful to see how many times Spinnaker called various APIs within a certain timeframe. If you know the ARN of the role Spinnaker is assuming to take actions in your account, you can query the number of calls made within a set time period by that role.

For example, the below query counts the number of different API event (service calls) made by Spinnaker in the last hour, grouped by eventname (API call) and error code.

```
SELECT count(*) AS Total,
         eventname,
         errorcode,
         errormessage
FROM "default"."cloudtrail_logs_aws_athena_spinnaker_ca_central_1"
WHERE useridentity.arn = 'arn:aws:sts::[ACCOUNT_NUM]:assumed-role/SpinnakerManagedCA/Spinnaker'
        AND from_iso8601_timestamp(eventtime) > date_add('hour', -1, now())
GROUP BY  eventname, errorcode, errormessage
ORDER BY  Total desc
```

Enter, format, run your query, and view results in the Athena console:

> IMAGE TBD


## Graphing CloudTrail activity

If you want to visualize Spinnaker's CloudTrail activity, you can configure the trail to send data to Amazon CloudWatch Logs and use 'Insights' to run searches with [CWL Insights query syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html).

1. In the page for your Spinnaker trail, go to the 'CloudWatch Logs' section and click "Configure".
2. The default log group is `CloudTrail/DefaultLogGroup`; you can use this or enter your own. Click "Continue".
3. You'll be redirected to a page for creating an IAM Role that allows CloudTrail to create log streams and put events. Click "Allow" at the bottom of the page. Once the role is created and validated, you'll be redirected to the CloudTrail console.
4. Navigate to the Amazon CloudWatch console, and click on the "Insights" page in the left menu.
5. In the drop-down at top, select the log group you created for your Spinnaker trail.
6. Enter and run a query! Make sure to select the desired timeframe in the menu to the right of the log group field (default is 1 hour).

Here's an example query that seraches for throttling exceptions seen by a 'Spinnaker' role:
```
stats count(*) by eventSource, eventName, awsRegion, errorCode
| filter userIdentity.sessionContext.sessionIssuer.userName like 'Spinnaker'
| filter errorCode like 'ThrottlingException'
```

More information about analyzing log data with CloudWatch Logs insight available in the [official docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html).


## Pricing

Cost incurred by this setup varies by individual footprint/account, but will include:

* S3 storage costs for AWS CloudTrail logs and Amazon Athena query results.
* Certain AWS CloudTrail events older than 90 days.
* Amazon Athena per-query charges by data scanned. 
* If using Amazon CloudWatch Logs Insights, normal CWL log and event rates apply.

More info and price calculators are available on the respective [S3](https://aws.amazon.com/s3/pricing/), [CloudTrail](https://aws.amazon.com/cloudtrail/pricing/), a[Athena](https://aws.amazon.com/athena/pricing/), and [CloudWatch](https://aws.amazon.com/cloudwatch/pricing/) pricing pages.