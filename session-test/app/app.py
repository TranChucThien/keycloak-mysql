from flask import Flask, session, redirect, request, jsonify
import os
import requests
import json
import base64
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key')

KEYCLOAK_URL = os.environ.get('KEYCLOAK_URL', 'http://localhost:30080')
REALM = os.environ.get('REALM', 'master')
CLIENT_ID = os.environ.get('CLIENT_ID', 'session-test-client')
CLIENT_SECRET = os.environ.get('CLIENT_SECRET', 'your-client-secret')
REDIRECT_URI = os.environ.get('REDIRECT_URI', 'http://localhost:30500/callback')

def decode_token(token):
    """Decode JWT token payload"""
    try:
        parts = token.split('.')
        if len(parts) != 3:
            return {}
        payload = parts[1]
        # Add padding if needed
        padding = len(payload) % 4
        if padding:
            payload += '=' * (4 - padding)
        decoded = base64.urlsafe_b64decode(payload)
        return json.loads(decoded)
    except Exception as e:
        print(f"Error decoding token: {e}")
        return {}

def is_token_expired(token):
    """Check if token is expired"""
    token_data = decode_token(token)
    if not token_data or 'exp' not in token_data:
        return True
    import time
    return token_data['exp'] < time.time()

@app.route('/')
def index():
    if 'access_token' in session:
        # Check if token expired
        if is_token_expired(session['access_token']):
            session.clear()
            return redirect('/login')
        
        return f'''
        <h1>Session Active</h1>
        <p>Logged in at: {session.get('login_time')}</p>
        <details>
            <summary>Access Token (click to expand)</summary>
            <pre style="word-wrap: break-word; white-space: pre-wrap;">{session['access_token']}</pre>
        </details>
        <br>
        <a href="/userinfo">Get User Info</a> | 
        <a href="/logout">Logout</a>
        '''
    return '<h1>Not Logged In</h1><a href="/login">Login with Keycloak</a>'

@app.route('/login')
def login():
    auth_url = f'{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/auth'
    params = {
        'client_id': CLIENT_ID,
        'redirect_uri': REDIRECT_URI,
        'response_type': 'code',
        'scope': 'openid'
    }
    url = f"{auth_url}?{'&'.join([f'{k}={v}' for k, v in params.items()])}"
    return redirect(url)

@app.route('/callback')
def callback():
    code = request.args.get('code')
    token_url = f'{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token'
    data = {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': REDIRECT_URI,
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET
    }
    resp = requests.post(token_url, data=data)
    tokens = resp.json()
    session['access_token'] = tokens['access_token']
    session['refresh_token'] = tokens.get('refresh_token')
    session['id_token'] = tokens.get('id_token')  # Store id_token for logout
    session['login_time'] = datetime.now().isoformat()
    return redirect('/')

@app.route('/userinfo')
def userinfo():
    if 'access_token' not in session:
        return redirect('/login')
    
    # Check if token expired
    if is_token_expired(session['access_token']):
        session.clear()
        return redirect('/login')
    
    # Decode token to get CIF and branch from custom claims
    token_data = decode_token(session['access_token'])
    
    # Also try to get from userinfo endpoint
    userinfo_url = f'{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/userinfo'
    headers = {'Authorization': f'Bearer {session["access_token"]}'}
    resp = requests.get(userinfo_url, headers=headers)
    
    # If 401, token is invalid/expired
    if resp.status_code == 401:
        session.clear()
        return redirect('/login')
    
    user_data = resp.json()
    
    # Merge token claims with userinfo (token claims take priority)
    cif = token_data.get('cif', user_data.get('cif', ['N/A']))
    branch = token_data.get('branch', user_data.get('branch', ['N/A']))
    
    # Extract first element if list
    cif_display = cif[0] if isinstance(cif, list) and cif else (cif if cif else 'N/A')
    branch_display = branch[0] if isinstance(branch, list) and branch else (branch if branch else 'N/A')
    
    # Format response with CIF and branch
    return f'''
    <h1>User Info</h1>
    <p><strong>Username:</strong> {user_data.get('preferred_username', token_data.get('preferred_username', 'N/A'))}</p>
    <p><strong>Email:</strong> {user_data.get('email', token_data.get('email', 'N/A'))}</p>
    <p><strong>CIF:</strong> {cif_display}</p>
    <p><strong>Branch:</strong> {branch_display}</p>
    <br>
    <a href="/">Back</a> | <a href="/logout">Logout</a>
    <hr>
    <details>
        <summary>Token Claims (from access_token)</summary>
        <pre>{json.dumps(token_data, indent=2)}</pre>
    </details>
    <details>
        <summary>UserInfo Endpoint Response</summary>
        <pre>{json.dumps(user_data, indent=2)}</pre>
    </details>
    '''

@app.route('/logout')
def logout():
    # Get token before clearing session
    id_token = session.get('id_token')
    
    # Clear app session
    session.clear()
    
    # Redirect to Keycloak logout endpoint to invalidate SSO session
    if id_token:
        logout_url = f'{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/logout'
        params = {
            'id_token_hint': id_token,
            'post_logout_redirect_uri': REDIRECT_URI.replace('/callback', '')
        }
        url = f"{logout_url}?{'&'.join([f'{k}={v}' for k, v in params.items()])}"
        return redirect(url)
    
    return redirect('/')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
