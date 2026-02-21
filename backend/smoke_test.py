import requests
base='http://127.0.0.1:8000'
# Register (ignore if exists)
try:
    r=requests.post(base+'/register', json={'email':'smoketest@example.com','password':'testpass'})
    print('register', r.status_code, r.text)
except Exception as e:
    print('register error', e)
# Login
r=requests.post(base+'/login', data={'username':'smoketest@example.com','password':'testpass'})
print('login', r.status_code, r.text)
if r.status_code!=200:
    raise SystemExit('login failed')
token=r.json()['access_token']
headers={'Authorization':f'Bearer {token}'}
# GET consent
r=requests.get(base+'/social/consent')
print('consent GET', r.status_code, r.json())
# POST consent
r=requests.post(base+'/social/consent', json={'accepted':True}, headers=headers)
print('consent POST', r.status_code, r.text)
# Upload content
items=[{'type':'post','text':'I feel a bit sad today.'},{'type':'caption','text':'loving life'},{'type':'screenshot','screenshot_base64':'abc123'}]
r=requests.post(base+'/social/upload', json={'items':items}, headers=headers)
print('upload', r.status_code, r.text)
# Delete data
r=requests.post(base+'/social/delete-data', headers=headers)
print('delete-data', r.status_code, r.text)
