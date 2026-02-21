import requests
print('calling /register')
r=requests.post('http://127.0.0.1:8000/register', json={'email':'smoketest2@example.com','password':'testpass'})
print('status', r.status_code)
print(r.text)
