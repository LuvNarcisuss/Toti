import argparse,json,re,uuid,urllib.request,urllib.error,os
from pathlib import Path
parser=argparse.ArgumentParser(description="Run authorized disposable guest cloud acceptance against Toti.")
parser.add_argument('--allow-disposable-cloud-data', action='store_true', help='Create two temporary guests and one private note, then permanently clean up those test accounts.')
if not parser.parse_args().allow_disposable_cloud_data:
    parser.error('Explicit authorization is required; pass --allow-disposable-cloud-data only after approval.')
s=(Path(__file__).resolve().parents[2] / 'Toti/Backend/TotiBackendConfiguration.swift').read_text()
base=re.search(r'projectURL = URL\(string: "([^"]+)"',s)[1]
key=re.search(r'publishableKey = "([^"]+)"',s)[1]
accounts=[]
tracking=Path('/tmp/toti-guest-acceptance-accounts.json')
def req(path,payload=None,token=None):
    h={'apikey':key,'Content-Type':'application/json'}
    if token:h['Authorization']='Bearer '+token
    r=urllib.request.Request(base+path,data=None if payload is None else json.dumps(payload).encode(),headers=h)
    try:
        with urllib.request.urlopen(r,timeout=40) as response:return response.status,json.load(response)
    except urllib.error.HTTPError as e:return e.code,json.loads(e.read())
def rpc(account,action,entity,payload,op=None):
    return req('/rest/v1/rpc/toti_mutate',{'p_operation_id':op or str(uuid.uuid4()),'p_action':action,'p_entity_id':entity,'p_payload':payload},account['access_token'])
def check(ok,name,result=None):
    print(('PASS ' if ok else 'FAIL ')+name,flush=True)
    if not ok:
        if isinstance(result,dict):print(json.dumps({k:result[k] for k in ['code','message','error','details','hint'] if k in result}),flush=True)
        raise RuntimeError(name)
try:
    for i in range(2):
        status,a=req('/auth/v1/signup',{})
        check(status==200 and a.get('user',{}).get('is_anonymous') is True,'guest authentication '+str(i+1),a)
        accounts.append(a)
        tracking.write_text(json.dumps([x['user']['id'] for x in accounts]));os.chmod(tracking,0o600)
        status,result=rpc(a,'enroll',a['user']['id'],{'agreement_version':'guest-acceptance-test-not-user-consent'})
        check(status==200,'isolated test account enrollment '+str(i+1),result)
    a,b=accounts
    note=str(uuid.uuid4()); op=str(uuid.uuid4()); payload={'title':'Guest acceptance','body':'Disposable private test content','category':'Ideas','expected_version':0}
    status,receipt=rpc(a,'note.save',note,payload,op)
    check(status==200,'private note save',receipt)
    status,replay=rpc(a,'note.save',note,payload,op)
    check(status==200 and replay==receipt,'same operation replays original receipt',replay)
    status,_=rpc(a,'note.save',note,dict(payload,body='Changed'),op)
    check(status>=400,'changed replay rejected')
    for account,expected in [(a,1),(b,0)]:
        status,page=req('/rest/v1/rpc/toti_read',{'p_kind':'note','p_parent_id':note},account['access_token'])
        check(status==200 and len(page.get('records',[]))==expected,'private note visibility '+('owner' if expected else 'other guest'),page)
    status,_=rpc(b,'note.save',note,payload)
    check(status>=400,'other guest cannot edit private note')
    status,restored=req('/auth/v1/token?grant_type=refresh_token',{'refresh_token':a['refresh_token']})
    check(status==200 and restored['user']['id']==a['user']['id'],'refresh preserves guest identity',restored)
    accounts[0]=restored
finally:
    for a in accounts:
        status,result=req('/functions/v1/toti-delete-account',{'operation_id':str(uuid.uuid4())},a['access_token'])
        print(('PASS ' if status==200 and result.get('status')=='complete' else 'PENDING ')+'disposable guest self-cleanup '+str(status),flush=True)
        if status!=200:print(json.dumps({k:result[k] for k in ['code','message','error','status'] if k in result}),flush=True)
