import json
import sys
import requests
import time
import datetime as dt
import uuid
import os
import boto3

class OfflineHelper(object):
    def __init__(self):
        self.is_online = True
        self.hb = ''

    def offline(self):
        if self.hb == '':
            self.hb = time.time()
        self.is_online = False

    def online(self):
        if self.hb != '':
            print('offline for {:.2f} seconds'.format(time.time() - self.hb))
            self.hb = ''
        self.is_online = True



def main():  # sourcery skip: use-assigned-variable
    topology = {}
    nodes = []
    leader = ''
    leader_id = ''
    BASE= os.environ['VAULT_ADDR']
    url = BASE + '/v1/kv/data/demo1'
    hdr = { 'X-Vault-Token' : os.environ['VAULT_TOKEN']}
    t = dt.datetime.now()
    session = requests.Session()
    state = OfflineHelper()
    req = 0
    while True:
        start = time.time()
        try:
            r = session.get(BASE + '/v1/sys/storage/raft/configuration', headers=hdr,timeout=0.5)
            req += 1
            state.online()
            if r.status_code != 200:
                print('error on raft_config')
                print(r.status_code)
                # sys.exit(1)
            new_topology = r.json()['data']['config']['servers']
            if new_topology != topology:
                print('change of topology')
                print(json.dumps(new_topology, indent=4, sort_keys=True))
                topology = new_topology
                new_nodes = []
                new_leader = ''
                new_leader_id = ''
                for n in new_topology:
                    new_nodes.append(n['address'])
                    if n['leader'] == True:
                        new_leader = n['address']
                        new_leader_id = n['node_id']
                print('old node: {} '.format(nodes))
                print('new node: {} '.format(new_nodes))
                print('')
                nodes = new_nodes
                if leader != new_leader:
                    print(' !!! NEW Leader  is promoted:{} - {} the old was: {} - {}'.format(new_leader, new_leader_id, leader, leader_id))
                    leader = new_leader
                    leader_id = new_leader_id
                    print('')

        except requests.exceptions.RequestException as e:
            state.offline()
            print(' # timeout on topology')


        # sys.exit(0)
        u = str(uuid.uuid4())
        j = {
            'data' : {
                'demopy': u
            }
        }
        error = False
        try:
            r = session.post(url, json=j, headers=hdr,timeout=0.5)
            req += 1
            state.online()
            if r.status_code != 200:
                print('error on write')
                print(r.text)
                print(r.status_code)
                # sys.exit(1)
        except requests.exceptions.RequestException as e:
            print(' # timeout on write')
            state.offline()
            error = True

        try:
            r = session.get(url, headers=hdr,timeout=0.5)
            req += 1
            state.online()
            if r.status_code != 200:
                print('error on read')
                print(r.status_code)
                # sys.exit(1)
        except requests.exceptions.RequestException as e:
            print(' # timeout on read')
            error = True
            state.offline()

        if error == False:
            if r.json()['data']['data']['demopy'] != u:
                print('WRITE not consistent')
        # print(r.json()["data"]["data"]["demopy"])

        delta = dt.datetime.now()-t
        if delta.seconds >= 60:
            today = dt.datetime.today().strftime('%Y-%m-%d-%H:%M:%S')
            print("[{}] Don't worry I'm still running!!! req: {}".format(today, req))
            t = dt.datetime.now()

        end = time.time()
        # print(end - start)
        # break


if __name__ == '__main__':
    try:
        ssm = boto3.client('ssm')
        parameter = ssm.get_parameter(Name='/vault/uat/root/token', WithDecryption=True)
        print('export VAULT_TOKEN={}'.format(parameter['Parameter']['Value']))
        os.environ['VAULT_TOKEN'] = parameter['Parameter']['Value']
        print('export VAULT_ADDR={}'.format(os.environ['VAULT_ADDR']))
        main()
    except KeyboardInterrupt:
        print ('Interrupted')
        sys.exit(0)
