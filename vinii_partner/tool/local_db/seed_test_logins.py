"""LOCAL DEVELOPMENT ONLY: test logins for VINII Partner on the One Local dev database.

Creates one confirmed login per staff role at the pilot restaurant (Mysore Dining Hall),
plus one login that belongs to no restaurant, so every role's screens can be tried:

    owner@pilot.local     org_owner   every tab, can publish the storefront
    admin@pilot.local     org_admin   every tab, can publish the storefront
    manager@pilot.local   manager     every tab, cannot publish   (already made by One Local's seed)
    cashier@pilot.local   biller      Orders, Sell, Menu (view), More
    captain@pilot.local   captain     Sell, hand to guest, Menu (view), More
    kitchen@pilot.local   kitchen     Orders (mark ready), Menu (view), More   (already made by One Local's seed)
    viewer@pilot.local    viewer      Orders (read only), More
    nostaff@pilot.local   none        the "No restaurant yet" screen

All share TEST_PASSWORD below (the same convention as One Local's scripts/db.py local seed).
Safe to re-run: existing logins are reused and their role is reset.

    python3 tool/local_db/seed_test_logins.py

It refuses to run unless the Supabase API is on this machine, and never touches production.
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

ONE_LOCAL_DIR = os.environ.get('ONE_LOCAL_DIR', '/Users/lohit/agentic-os-coder/One Local Mobile App /OL-ui')
DB_CONTAINER = 'supabase_db_onelocal-dev'
ORG_SLUG = 'mysore-dining-hall'
TEST_PASSWORD = 'pilot-test-123'

LOGINS = [
    ('owner@pilot.local', 'Owner (test)', 'org_owner'),
    ('admin@pilot.local', 'Admin (test)', 'org_admin'),
    ('manager@pilot.local', 'Manager (test)', 'manager'),
    ('cashier@pilot.local', 'Cashier (test)', 'biller'),
    ('captain@pilot.local', 'Captain (test)', 'captain'),
    ('kitchen@pilot.local', 'Kitchen (test)', 'kitchen'),
    ('viewer@pilot.local', 'Viewer (test)', 'viewer'),
    ('nostaff@pilot.local', 'No restaurant (test)', None),
]


def local_status():
    p = subprocess.run(['supabase', 'status', '-o', 'env'], cwd=ONE_LOCAL_DIR, text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit('Local Supabase is not running. Start it: cd "One Local Mobile App /OL-ui" && supabase start')
    vals = {}
    for line in p.stdout.splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            vals[k.strip()] = v.strip().strip('"')
    host = urlparse(vals.get('API_URL', '')).hostname
    if host not in ('127.0.0.1', 'localhost'):
        sys.exit(f'Refusing: Supabase API is {host}, not this machine.')
    return vals


def psql(sql):
    p = subprocess.run(['docker', 'exec', '-i', DB_CONTAINER, 'psql', '-U', 'postgres', '-d', 'postgres',
                        '-v', 'ON_ERROR_STOP=1', '-At', '-c', sql], text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit(p.stderr.strip())
    return p.stdout.strip()


def quote(s):
    return "'" + s.replace("'", "''") + "'"


def create_user(status, email, name):
    api, key = status['API_URL'], status['SERVICE_ROLE_KEY']
    body = json.dumps({'email': email, 'password': TEST_PASSWORD, 'email_confirm': True,
                       'user_metadata': {'full_name': name}}).encode()
    req = urllib.request.Request(f'{api}/auth/v1/admin/users', data=body, method='POST',
                                 headers={'apikey': key, 'Authorization': f'Bearer {key}',
                                          'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)['id']
    except urllib.error.HTTPError as e:
        if e.code in (409, 422):  # already exists: reuse it
            return psql(f'select id from auth.users where email = {quote(email)}')
        raise


def main():
    status = local_status()
    org_id = psql(f'select id from public.organizations where slug = {quote(ORG_SLUG)}')
    if not org_id:
        sys.exit(f'No organization {ORG_SLUG} in the local database. Run One Local: scripts/db.py local-seed')
    print(f'{"login":<24}{"role":<12}result')
    for email, name, role in LOGINS:
        user_id = create_user(status, email, name)
        if role is None:
            psql(f'delete from public.org_users where user_id = {quote(user_id)}')
            print(f'{email:<24}{"-":<12}no restaurant')
            continue
        psql(f"""
            insert into public.org_users (organization_id, user_id, role_id, email, full_name, status)
            select {quote(org_id)}, {quote(user_id)}, r.id, {quote(email)}, {quote(name)}, 'active'
            from public.roles r where r.slug = {quote(role)}
            on conflict (organization_id, user_id)
            do update set role_id = excluded.role_id, full_name = excluded.full_name, status = 'active'
        """)
        print(f'{email:<24}{role:<12}staff at {ORG_SLUG}')
    print('\nPassword for all: see TEST_PASSWORD in this file.')


if __name__ == '__main__':
    main()
