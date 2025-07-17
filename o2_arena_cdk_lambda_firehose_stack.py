from aws_cdk import (
    Stack,
    aws_lambda as _lambda,
    aws_lambda_python_alpha as _alambda,
    aws_ec2 as ec2,
    aws_s3 as s3,
    aws_kinesisfirehose_alpha as firehose,
    aws_kinesisfirehose_destinations_alpha as destinations,
    aws_iot_alpha as iot,
    aws_iot_actions_alpha as actions,
    aws_secretsmanager as secretsmanager,
    Duration, Size,
)
from constructs import Construct


class O2ArenaLambdaFirehoseStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, input_metadata, input_s3_bucket_arn, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        # Create function in existing VPC
        lambda_fn = _alambda.PythonFunction(
            self,
            "lambda_fn",
            entry="./lambda_firehose_stack/",
            runtime=_lambda.Runtime.PYTHON_3_9,
            index="lambda_function.py",
            handler="lambda_handler",
            timeout=Duration.seconds(30)
        )

        # Add DB secret, through OS variables to Lambda function:
        db_secret_name = input_metadata['db_secret_arn_nosuffix'].split(':')[-1]
        lambda_fn.add_environment(key='db_secret_name', value=db_secret_name)
        lambda_fn.add_environment(key='region_name', value=input_metadata['aws_region'])

        # Add permissions, so Lambda can decrypt DB credentials
        db_secret = secretsmanager.Secret.from_secret_attributes(self, 'db-secret',
                        secret_partial_arn=input_metadata['db_secret_arn_nosuffix'])

        # Grand read permission on Secret, to our Lambda fn
        db_secret.grant_read(lambda_fn) 

        # Lambda as Transformer / Firehose Processor
        lambda_processor = firehose.LambdaFunctionProcessor(lambda_fn,
                                buffer_interval=Duration.minutes(1),
                                buffer_size=Size.mebibytes(1),
                                retries=3
                            )

        # Fetch S3 bucket
        s3_bucket = s3.Bucket.from_bucket_attributes(self, "FirehoseBucket", bucket_arn=input_s3_bucket_arn)

        # Build Firehose Delivery Stream
        firehose_delivery = firehose.DeliveryStream(self, "DeliveryStream",
                                destinations=[destinations.S3Bucket(s3_bucket,
                                    logging=True,
                                    processor=lambda_processor,
                                    compression=destinations.Compression.GZIP,
                                    data_output_prefix="o2-arena-motion",
                                    error_output_prefix="errors",
                                    buffering_interval=Duration.minutes(1),
                                    buffering_size=Size.mebibytes(1)
                                )]
                            )

        # IoT Rule
        topic_rule = iot.TopicRule(self, "TopicRule",
                        sql=iot.IotSql.from_string_as_ver20160323("SELECT * FROM '/iot-o2-arena-motion'"),
                        actions=[
                            actions.FirehosePutRecordAction(firehose_delivery,
                                # Disabling batch_mode, due possible bug https://github.com/aws/aws-cdk/issues/19501
                                batch_mode=False,
                                record_separator=actions.FirehoseRecordSeparator.NEWLINE
                            )
                        ]
                    )
