## Description

This Python function exports data from a MySQL database using the classic
mysqldump(1) command. It is designed to be run as an AWS Lambda function.

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
