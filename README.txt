## Description

This Python function exports data from a MySQL database using the classic
mysqldump(1) command. It is designed to be run as an AWS Lambda function and
load config from Parameter Store.

## Test

```
DEBUG=1 python3 src/index.py
```

## Build

```
docker build -t mysql_export src
docker run --rm mysql_export cat /build/release.zip > build\release.zip
```

## Deploy

```
terraform apply -target=aws_lambda_function.mysql_export
```

## Config

```
aws ssm put-parameter \
 --name /dev/env.json \
 --type SecureString \
 --value '{"MYSQL_USERNAME":"myapp","MYSQL_PASSWORD":"secret","MYSQL_HOSTNAME":"myapp-dev.rds.amazon.com","MYSQL_DATABASE":"myapp"}'
```

## Run

```
aws lambda invoke \
 --function-name mysql_export \
 --invocation-type RequestResponse \
 --log-type Tail \
 --payload '{"APP_ENV":"dev"}' \
 result.json
```

## Bugs

 - Uses /tmp, vulnerable to 500 MiB limit.
