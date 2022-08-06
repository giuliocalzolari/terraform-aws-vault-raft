import os
import boto3
import json
import base64
import time
import traceback
import urllib3
from datetime import datetime
from urllib.parse import urlsplit
from botocore.exceptions import ClientError


urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
retries = urllib3.util.Retry(
    connect=5,
    total=3,
    status_forcelist=(413, 429, 500, 502, 504),
    )
http = urllib3.PoolManager(cert_reqs='CERT_NONE', assert_hostname=False, retries=retries)

class VaultHelper(object):

    def __init__(self):
        self.base_url = os.environ['VAULT_ADDR']
        self.port = os.environ.get('VAULT_PORT', '8200')
        self.schema = os.environ.get('VAULT_SCHEMA', 'https')
        self.headers = {}

    def headers_to_go_style(self, headers):
        retval = {}
        for k, v in headers.items():
            if isinstance(v, bytes):
                retval[k] = [str(v, 'ascii')]
            else:
                retval[k] = [v]
        return retval

    def _encode_for_payload(self, data):
        return  str(base64.b64encode(data.encode('ascii')), 'ascii')

    def generate_vault_request(self):
        session = boto3.session.Session()
        client = session.client('sts')
        endpoint = client._endpoint
        operation_model = client._service_model.operation_model('GetCallerIdentity')
        request_dict = client._convert_to_request_dict({}, operation_model)

        aws_iam_server_id = urlsplit(self.base_url).netloc.split(':')[0]
        request_dict['headers']['X-Vault-AWS-IAM-Server-ID'] = aws_iam_server_id
        request = endpoint.create_request(request_dict, operation_model)

        headers = self.headers_to_go_style(dict(request.headers))
        return {
            'iam_http_request_method': request.method,
            'iam_request_url': self._encode_for_payload(request.url),
            'iam_request_body': self._encode_for_payload(request.body),
            'iam_request_headers': self._encode_for_payload(json.dumps(headers)),
            'role': os.environ['VAULT_ROLE'],
        }

    def raft_config(self):
        url = '{}/v1/sys/storage/raft/configuration'.format(self.base_url)
        # print(url)
        data=self.generate_vault_request()
        r = http.request('GET',url,
                body=json.dumps(data),
                headers=self.headers
            )
        if r.status >= 300:
            print('got reply {} on raft_config'.format(r.status))
            print(r.data)
        res = json.loads(r.data.decode('utf-8'))
        srv = res['data']['config']['servers']
        # print(json.dumps(srv, indent=4, sort_keys=True))
        return srv


    def auth(self):
        data=self.generate_vault_request()
        url = '{}/v1/auth/aws/login'.format(self.base_url)
        print(f'auth to {url}')
        r = http.request('POST', url, body=json.dumps(data))
        if r.status >= 300:
            print('got reply {} on auth'.format(r.status))
            print(r.data)
        res = json.loads(r.data.decode('utf-8'))
        os.environ['VAULT_TOKEN'] = res['auth']['client_token']
        self.headers['X-Vault-Token'] = os.environ['VAULT_TOKEN']


def complete_lifecycle_action(event, lifecycle_action_result):
    instance_id = event['detail']['EC2InstanceId']
    try:
        boto3.client('autoscaling').complete_lifecycle_action(
            LifecycleHookName=event['detail']['LifecycleHookName'],
            AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
            InstanceId=instance_id,
            LifecycleActionResult=lifecycle_action_result,
        )
        print(
            'Lifecycle hook {}ed for: {}'.format(
                lifecycle_action_result, instance_id
            )
        )
    except ClientError as err:
        print(
            'Error completing life cycle hook for instance {}: {}'.format(
                instance_id, err.response['Error']
            )
        )






def lambda_handler(event, context):
    try:
        vc = VaultHelper()
        vc.auth()
        srvs = vc.raft_config()
        instance_id = event['detail']['EC2InstanceId']
        print('searching for node_id: {}'.format(instance_id))
        for s in srvs:
            if s['node_id'] == instance_id:
                if s['leader']:
                    print('terminating leader node_id: {}'.format(instance_id))
                    url = '{}://{}:{}/v1/sys/step-down'.format(vc.schema, s['address'].split(':')[0], vc.port)
                    r = http.request('PUT', url,headers=vc.headers)
                    if r.status != 204:
                        print('got {} on step down action'.format(r.status))
                        print(r.data)
                        complete_lifecycle_action(event, lifecycle_action_result='ABANDON')
                else:
                    print('terminating slave node_id: {}'.format(instance_id))


                # Remove peer 3 times
                for i in range(3):
                    print('[{}]removing node_id: {}'.format(i, instance_id))
                    url = '{}/v1/sys/storage/raft/remove-peer'.format(vc.base_url)
                    r = http.request('POST', url,
                        body=json.dumps({'server_id': instance_id}),
                        headers=vc.headers
                    )
                    if r.status == 204:
                        complete_lifecycle_action(event, lifecycle_action_result='CONTINUE')
                        return True
                    else:
                        print('got reply {} on remove-peer'.format(r.status))
                        print(r.data)
                    time.sleep(1)

                print('node removal failed')
                complete_lifecycle_action(event, lifecycle_action_result='ABANDON')
    except:
        print('generic error')
        print(traceback.print_exc())
        print(event)
        complete_lifecycle_action(event, lifecycle_action_result='ABANDON')





if __name__ == '__main__':
    event = {
        'version': '0',
        'id': '4c23ad28-6283-af18-2b1a-109485a38df5',
        'detail-type': 'EC2 Instance-terminate Lifecycle Action',
        'source': 'aws.autoscaling',
        'account': '541826535849',
        'time': '2022-02-08T10:39:21Z',
        'region': 'eu-west-1',
        'resources': ['arn:aws:autoscaling:eu-west-1:541826535849:autoScalingGroup:4de41d00-9d76-4725-9bec-2d8553461647:autoScalingGroupName/uat-vault-asg'],
        'detail': {
            'LifecycleActionToken': 'dd1b7f94-b1fd-4cd5-8e86-7e365aa24b78',
            'AutoScalingGroupName': 'uat-vault-asg',
            'LifecycleHookName': 'ec2terminate',
            'EC2InstanceId': 'i-08b117ca3ede087c6',
            'LifecycleTransition': 'autoscaling:EC2_INSTANCE_TERMINATING',
            'Origin': 'AutoScalingGroup',
            'Destination': 'EC2'
            }
        }

    # vc.raft_config()
    lambda_handler(event, '')
