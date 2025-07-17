#!/usr/bin/env python3
from aws_cdk import Environment
from aws_cdk import App
from s3_stack.o2_arena_cdk_s3_stack import O2ArenaS3Stack
from lambda_firehose_stack.o2_arena_cdk_lambda_firehose_stack import O2ArenaLambdaFirehoseStack

""" Config settings:
    The hard-coded values can be input parameters or pulled from config files,
    once the code is released to production.
"""
input_params = dict([
    ('aws_account_id','443370692694'),
    ('aws_region', 'us-west-1'),
    ('db_secret_arn_nosuffix','arn:aws:secretsmanager:us-west-1:443370692694:secret:db_credentials_11'),
  ])

# AWS Settings
app = App()
env_oregon = Environment(account=input_params['aws_account_id'], region=input_params['aws_region'])

# Stacks definition
s3_stack = O2ArenaS3Stack(app, "o2-arena-s3-stack", 
                                input_metadata=input_params, 
                                env=env_oregon)

lambda_firehose_stack = O2ArenaLambdaFirehoseStack(app, "o2-arena-lambda-firehose-stack", 
                                input_metadata=input_params,
                                input_s3_bucket_arn=s3_stack.bucket.bucket_arn,
                                env=env_oregon)

app.synth()
