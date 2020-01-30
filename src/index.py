# Load application config from Parameter Store depending on event['APP_ENV'] and
# export the data from MySQL using mysqldump(1) bundled in working directory,
# compress the export file using gzip and upload it to S3.
#
import os
import re
import sys
import gzip
import time
import json
import hashlib
import subprocess

# sanity check Python version
assert(sys.version_info >= (3,6))

DEBUG = True if os.environ.get('DEBUG') else False

def handler(event, context):

    if DEBUG:
        print(event)

    bucket = os.environ['BUCKET']
    app_env = event['APP_ENV'] # dev, prod, uat, test, ...
    metadata = event.get('METADATA', {}) # optional S3 object metadata

    if app_env != 'local':
      import boto3
      client = boto3.client('ssm')
      response = client.get_parameter(Name=("/%s/env.json" % app_env))
      config = json.loads(response['Parameter']['Value'])
    else:
      config = event

    if DEBUG:
        print(config)

    export_file = 'export-' if app_env == 'prod' else app_env + '-export-'
    export_file += str(int(time.time()))
    export_file += '.sql.gz'

    params = {
      'p': config['MYSQL_PASSWORD'],
      'u': config['MYSQL_USERNAME'],
      'h': config['MYSQL_HOSTNAME'],
      'd': config['MYSQL_DATABASE'],
      'k': export_file,
      'f': '/tmp/' + export_file,
    }

    mysqldump = subprocess.Popen(
      "./mysqldump --hex-blob -p%(p)s -u %(u)s -h %(h)s %(d)s" % params,
      shell=True,
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
    )

    with gzip.open(params['f'], 'w') as f:
      while True:
        line = mysqldump.stdout.readline()
        if not line : break
        f.write(line)

    # wait for subprocess to finish then check return code
    mysqldump.stdin.close()
    mysqldump.wait()

    if DEBUG:
        print(mysqldump.stdout.read())
        print(mysqldump.stderr.read())

    if mysqldump.returncode != 0:
      raise Exception("Export failed with exit code %d" % mysqldump.returncode)

    # upload data export to the backups bucket
    if app_env != 'local':
      s3 = boto3.resource('s3')
      s3.Bucket(bucket).put_object(
        Key=params['k'],
        Body=open(params['f'], 'rb'),
        ContentType='application/gzip',
        Metadata=metadata,
      )

    if DEBUG:
        print(params['f'])

    return {
      'BUCKET': bucket,
      'KEY': params['k'],
      'URI': "s3://%s/%s" % (bucket, params['k']),
    }

# Test some sample events if invoked directly (for local development)
if __name__ == '__main__':
    handler(json.load(open('test-local.json', 'r')), {})
