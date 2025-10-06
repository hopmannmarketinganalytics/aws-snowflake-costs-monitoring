import os
import json
import boto3
import snowflake.connector
from datetime import date, timedelta
from cryptography.hazmat.primitives import serialization
import logging
from decimal import Decimal

ssm = boto3.client("ssm")
logger= logging.getLogger()
logger.setLevel(logging.INFO)

def get_param(name, with_decryption=True):
    return ssm.get_parameter(Name=name, WithDecryption=with_decryption)["Parameter"]["Value"]

def lambda_handler(event, context):
    snowflake_limit = float(os.environ["THRESHOLD_COST"])
    topic_arn = os.environ["SNS_TOPIC_ARN"]
    param_name = os.environ["SSM_PARAM_NAME"]
    environment = os.environ["ENVIRONMENT"]

    # Fetch JSON credentials from Parameter Store
    response = ssm.get_parameter(Name=param_name, WithDecryption=True)
    creds = json.loads(response["Parameter"]["Value"])
    private_key = serialization.load_pem_private_key(
        creds["private_key"].encode("utf-8"),
        password=None
    )

    conn = snowflake.connector.connect(
        user=creds["user"],
        account=creds["account"],
        warehouse=creds["warehouse"],
        role=creds["role"],
        private_key=private_key,
    )

    cur = conn.cursor()
    cur.execute(f"USE WAREHOUSE {creds['warehouse']}")

    # Determine first day of current month
    today = date.today()
    first_day_of_month = today.replace(day=1)
    year_month = first_day_of_month.strftime("%Y-%m")

    cur.execute(f"""
        SELECT
        SUM(CREDITS_USED) AS total_credits
        FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
        WHERE DATE_TRUNC('month', START_TIME)::DATE = '{first_day_of_month}'
        """)
    result = cur.fetchone()
    credits_used = result[0] or 0

    logging.info (f"Credits used are {credits_used} for this month {first_day_of_month}")

    cost_usd = float(credits_used) * 2.60
    threshold = float(snowflake_limit) * 1.30

    if cost_usd > threshold:
        sns = boto3.client("sns")
        sns.publish(
            TopicArn=topic_arn,
            Subject=f"Snowflake cost alert for {environment} environment",
            Message=f"Snowflake cost for {year_month} month is ${cost_usd:.2f}, exceeding threshold ${threshold:.2f}."
        )

    cur.close()
    conn.close()

