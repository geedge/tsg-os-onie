import requests
import urllib
import json
import time
import logging
import argparse
import os
import subprocess
import hashlib
import shutil

PULP_SERVER_URL_BASE = "http://repo.internal.geedge.net/"
PULP_REPO_HREF = ""
PULP_DIST_HREF = ""

BYTES_OF_256M = 268435456

def orphans_cleanup():
    api_cleanup = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, '/pulp/api/v3/orphans/')

    r = requests.delete(api_cleanup)
    r.raise_for_status()


def wait_until_task_finished(task_url):
    api_task_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_url)
    while True:
        r = requests.get(api_task_url)
        r.raise_for_status()
        state = r.json()['state']

        if state == 'failed' or state == 'cancelled':
            raise Exception("task is cancelled", task_url, state)
        if state == 'completed':
            break

        # wait for task to complete
        time.sleep(1)
    return


def task_created_resource_by_task_url(task_url):
    r = requests.get(urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_url))
    r.raise_for_status()
    return json.loads(r.text)['created_resources'][0]


def artifact_create(path):
    api_url_artifact = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, "/pulp/api/v3/artifacts/")
    with open(path, 'rb') as fp:
        files = {'file': fp}
        r = requests.post(api_url_artifact, files=files)
        r.raise_for_status()

    href = r.json()['pulp_href']
    href_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, href)
    requests.get(href_url).raise_for_status()
    return href


def content_create_from_artifact(artifact_href, pkgname):
    api_url_create_content = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, '/pulp/api/v3/content/file/files/')
    r = requests.post(api_url_create_content, data={
                      'artifact': artifact_href, 'relative_path': pkgname})
    r.raise_for_status()

    task_href = r.json()['task']
    task_full_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_href)
    wait_until_task_finished(task_full_url)

    r = requests.get(task_full_url)
    r.raise_for_status()

    package_href = json.loads(r.text)['created_resources'][0]
    r = requests.get(urllib.parse.urljoin(PULP_SERVER_URL_BASE, package_href))
    r.raise_for_status()
    return package_href


def add_content_to_repo(repo_href, package_hrefs):
    api_url_publish = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, repo_href + 'modify/')
    r = requests.post(api_url_publish, json={
                      'add_content_units': package_hrefs})
    r.raise_for_status()

    # create task and wait for it to complete
    task_href = r.json()['task']
    task_full_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_href)
    wait_until_task_finished(task_full_url)


def publication_repo(repo_href):
    api_url_publish = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, '/pulp/api/v3/publications/file/file/')

    r = requests.post(api_url_publish, json={'repository': repo_href})
    r.raise_for_status()

    # wait the task
    task_href = r.json()['task']
    task_full_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_href)
    wait_until_task_finished(task_full_url)

    # publication
    pub_href = task_created_resource_by_task_url(task_full_url)
    return pub_href


def distribution(pub_href, name, base_path):
    api_url = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, '/pulp/api/v3/distributions/file/file/')

    r = requests.put(
        api_url, json={'name': name, 'base_path': base_path, 'publication': pub_href})
    r.raise_for_status()

    # wait the task
    task_href = r.json()['task']
    task_full_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_href)
    wait_until_task_finished(task_full_url)


def update_distributation_pub(dist_href, pub_href):
    api_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, dist_href)
    r = requests.get(api_url)
    r.raise_for_status()

    dist_base_path = r.json()['base_path']
    dist_name = r.json()['name']

    logging.info('prepare to update dist, name: %s, base_path: %s' %
                 (dist_name, dist_base_path))

    r = requests.put(api_url, json={
                     'base_path': dist_base_path, 'name': dist_name, 'publication': pub_href})
    r.raise_for_status()

    # wait the task
    task_href = r.json()['task']
    task_full_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_href)
    wait_until_task_finished(task_full_url)

    logging.info('update dist successfully, %s', task_href)


def dist_href_lookup_by_name(distname):
    api_url = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, '/pulp/api/v3/distributions/file/file/')

    r = requests.get(api_url)
    r.raise_for_status()
    logging.debug('response: %s', r.json())

    for result in r.json()['results']:
        if (result['name'].strip() == distname):
            return result['pulp_href']

    raise Exception('cannot lookup %s\'s dist href, Not exist.' % distname)


def repo_href_lookup_by_name(reponame):
    api_url = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, '/pulp/api/v3/repositories/file/file/')

    r = requests.get(api_url)
    r.raise_for_status()

    #logging.fatal('response: %s', r.json())

    for result in r.json()['results']:
        if (result['name'] == reponame):
            return result['pulp_href']

    raise Exception('cannot lookup %s\'s repo href, Not exist.' % reponame)

def split_large_file_upload_artifact(filename):
    if os.path.exists('ch'):
        shutil.rmtree('ch')
    os.makedirs('ch')
    api_url_update = urllib.parse.urljoin(
        PULP_SERVER_URL_BASE, "/pulp/api/v3/uploads/")

    splitCommand = 'split --byte=256M -d ' + filename + ' ch/chunk'
    fileSize = os.path.getsize(filename)
    splitstatus, splitret = subprocess.getstatusoutput(splitCommand)
    if splitstatus != 0:
        raise Exception('cannot split large file, name: %s, size: %d, info: %s' % (filename, fileSize, splitret))
    allsize = {'size': fileSize}
    r = requests.post(api_url_update, data = allsize)
    r.raise_for_status()
    upload_href = r.json()['pulp_href']
    upload_href_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, upload_href)
    filelist = sorted(os.listdir('ch'))
    sendbytes = 0
    for i in range(len(filelist)):
        path = 'ch/' + filelist[i]
        with open(path, 'rb') as fp:
            rangeStr = ''
            if i < (len(filelist) - 1):
               # rangeStr = 'bytes ' + sendbytes + '-' + (sendbytes + BYTES_OF_256M - 1) + '/*'
                rangeStr = 'bytes %d-%d/*' %(sendbytes,(sendbytes + BYTES_OF_256M - 1))
                sendbytes = sendbytes + BYTES_OF_256M
            else:
                #rangeStr = 'bytes ' + sendbytes + '-' + (fileSize - 1) + '/*'
                rangeStr = 'bytes %d-%d/*' %(sendbytes,(fileSize - 1))
            headers = {'Content-Range': rangeStr}
            files = {'file': fp}
            r = requests.put(upload_href_url, files=files, headers = headers)
            fp.close()

    sha256data = {'sha256': hashlib.sha256(open(filename, "rb").read()).hexdigest()}
    upload_href_ci_url = urllib.parse.urljoin(upload_href_url, 'commit/')
    r = requests.post(upload_href_ci_url, data = sha256data)
    r.raise_for_status()
    task_href = r.json()['task']
    task_full_url = urllib.parse.urljoin(PULP_SERVER_URL_BASE, task_href)
    wait_until_task_finished(task_full_url)
    href = task_created_resource_by_task_url(task_full_url)
    return href


def main():
    parser = argparse.ArgumentParser(description='Pulp3 FILE upload helper')
    parser.add_argument('repo', type=str)
    parser.add_argument('dist', type=str)
    parser.add_argument('package', type=str, nargs='+')
    parser.add_argument('--pulp-server-url', type=str)
    parser.add_argument('--verbose', default=False, action='store_true')
    args = parser.parse_args()

    if (args.verbose):
        logging.basicConfig(level=logging.DEBUG)

    dist_href = dist_href_lookup_by_name(args.dist)
    repo_href = repo_href_lookup_by_name(args.repo)

    logging.info('dist_href: %s' % dist_href)
    logging.info('repo_href: %s' % repo_href)

    if args.pulp_server_url:
        global PULP_SERVER_URL_BASE
        PULP_SERVER_URL_BASE = args.pulp_server_url

    package_list = []
    for package in args.package:
        if os.path.isfile(package):
            package_list.append(package)
            continue

        for file in os.listdir(package):
            path = os.path.join(package, file)
            if os.path.isfile(path):
                package_list.append(path)

    logging.info('FILES: %s', str(package_list))

    orphans_cleanup()
    package_href_collection = []
    for package_path in package_list:
        package_basename = os.path.basename(package_path)
        artifact_href = ''
        if os.path.getsize(package_path) <= BYTES_OF_256M:
            artifact_href = artifact_create(package_path)
        else:
            artifact_href = split_large_file_upload_artifact(package_path)
        package_href = content_create_from_artifact(
            artifact_href, package_basename)
        package_href_collection.append(package_href)

    add_content_to_repo(repo_href, package_href_collection)
    pub_href = publication_repo(repo_href)
    update_distributation_pub(dist_href, pub_href)


if __name__ == "__main__":
    main()
