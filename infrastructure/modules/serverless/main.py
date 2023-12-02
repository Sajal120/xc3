import boto3
import json
import traceback

def lambda_handler(event, context):
    client = boto3.client('cur', region_name='us-east-1')

    report_definition = {
        'ReportName': 'xc3report1120',
        'TimeUnit': 'DAILY',
        'Format': 'textORcsv',  # Corrected format
        'Compression': 'ZIP',
        'S3Bucket': 'xc3-cur-project-bucket-120',
        'S3Prefix': 'report-xc3report1120',
        'S3Region': 'us-east-1',
        'AdditionalSchemaElements': ['RESOURCES'],
        'ReportVersioning': 'CREATE_NEW_REPORT',           #CREATE_NEW_REPORT or OVERWRITE_REPORT
    }

    try:
        response = client.put_report_definition(ReportDefinition=report_definition)
        return {
            'statusCode': 200,
            'body': json.dumps('CUR report created successfully.')
        }
    except Exception as e:
        error_message = f'Error: {str(e)}\n{traceback.format_exc()}'  # Enhanced error logging
        print(error_message)
        return {
            'statusCode': 500,
            'body': json.dumps(error_message)
        }