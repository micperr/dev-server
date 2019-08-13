#!/usr/bin/env python3

import argparse
import os
import platform
import sys
import subprocess
import dotenv
from colorama import Fore, Style
from ruamel import yaml
import nginx

ENVS_REQUIRED = [
    'SERVER_WORKSPACE_DIR',
    'SERVER_DOMAIN_SUFFIX',
    'MYSQL_ROOT_PASSWORD',
    'POSTGRES_PASSWORD',
    'RABBITMQ_DEFAULT_USER',
    'RABBITMQ_DEFAULT_PASS'
]

ENVS_AUTOGEN = ['SERVER_USER_ID', 'SERVER_GROUP_ID']


def load_envs():
    dotenv.load_dotenv(ENV)


def setenv(key, val):
    dotenv.set_key(ENV, key, val)
    load_envs()


def run(args):
    cmd = args.command

    # BUILD
    if cmd == 'build':
        setenv('SERVER_USER_ID', str(os.getuid()))
        setenv('SERVER_GROUP_ID', str(os.getgid()))
        produce_config_files(args)
        run_docker_compose_command('build')
        print_success('Build has been completed.', _exit=True)
    elif not is_built():
        print_error('Server has not been built. Please run `make build` or `server build`.',
            _exit=True)

    if cmd == 'sites':
        c = nginx.loadf(NGINX_PROXIES_CONF)
        for conf in c.as_dict['conf']:
            print(conf['server'][0]['server_name'])
        sys.exit(0)

    ipcmd = "ps -q --filter network=localhost | xargs docker inspect --format '{{.Name}}\n {{ " \
            ".NetworkSettings.Networks.localhost.IPAddress }}\n' | sed 's#^/##' "
    if cmd == 'status':
        run_docker_command('container ls --filter network=localhost '
                           '--format "table {{.Names}}\t{{.Ports}}\t{{.Status}} "')

        if args.ip:
            run_docker_command(ipcmd)

        sys.exit(0)

    if cmd == 'ip':
        run_docker_command(ipcmd)
        sys.exit(0)

    produce_config_files(args)

    # PRUNE
    if cmd == 'prune':
        run_docker_command('system prune --volumes' if args.volumes else 'system prune')
        print_success('Server has been pruned.', _exit=True)

    # CONFIGURE
    if cmd == 'configure':
        print_success('Server config has been updated.', _exit=True)

    # STOP
    if cmd in ('stop', 'restart'):
        run_docker_compose_command('stop')

    # UP / RESTART
    if cmd in ('up', 'restart'):
        run_docker_compose_command('up -d')

    if cmd == 'refresh':
        run_docker_compose_command('up -d --build')

    # DOWN
    if cmd == 'down':
        run_docker_compose_command(
            'down --volumes --remove-orphans' if args.volumes else 'down --remove-orphans'
        )


def is_built():
    return all(
        [bool(os.getenv(c)) for c in ENVS_AUTOGEN]
    )


def are_envs_provided():
    return all(
        [bool(os.getenv(c)) for c in ENVS_REQUIRED]
    )


def get_missing_envs():
    return [c for c in ENVS_REQUIRED if not os.getenv(c)]


def validate():
    all_dist_files_exist = True
    for filepath in [DOCKER_COMPOSE_TPL, ENV]:
        if not os.path.exists(filepath):
            print_error(f"{filepath} does not exist.")
            all_dist_files_exist = False

    if not all_dist_files_exist:
        print_msg("Run `make install` to fix this.", _exit=True)

    if not are_envs_provided():
        miss = ', '.join(get_missing_envs())
        print_error(f'Missing mandatory configuration values in .env file: {miss}', _exit=True)

    if not os.path.exists(SITES):
        print_error(f"{SITES} does not exist."
            "Please create it and update it according to the following template:"
        )
        with open(ROOT + '/config/dist/sites.yml.dist') as f:
            print_info("\n" + f.read(), _exit=True)


def produce_config_files(args):
    containers_whitelist = args.c if args.command == 'refresh' and args.c else None
    workspace_dir, domain = get_server_env_configs()
    save_docker_composer_config(workspace_dir, containers_whitelist)
    save_nginx_config(workspace_dir, domain)


def get_server_env_configs():
    return os.getenv('SERVER_WORKSPACE_DIR'), os.getenv('SERVER_DOMAIN_SUFFIX')


def run_docker_command(cmd):
    subprocess.run([f"docker {cmd}"], shell=True)


def run_docker_compose_command(cmd):
    cmd = f"docker-compose -f {DOCKER_COMPOSE} --project-directory {ROOT} {cmd}"
    subprocess.run([cmd], shell=True)


def save_nginx_config(workspace_dir, domain_suffix):
    """
    Read sites provided by the user and generate conf files
    for both nginx reversed proxy and nginx behind it
    """
    sites = read_yaml(SITES)
    nginx_proxy_config = ''
    nginx_sites_config = ''

    for site, settings in sites.items():

        webpath = settings['webpath']
        sitetype = settings['type']
        site_webpath_dir = f"{workspace_dir}/{site}/{webpath}"

        if os.path.exists(site_webpath_dir):

            # NGINX servers
            if sitetype not in VALID_CONF_TYPES:
                print_warning(f"Invalid site type '{sitetype}'. Skipping...")
                continue

            domain = (
                f"{site}{domain_suffix}" if domain_suffix[0] == '.'
                else f"{site}.{domain_suffix}"
            )

            with open(NGINX_PROXY_SITE_TPL) as tpl:
                nginx_proxy_config += tpl.read().replace('{$DOMAIN}', domain) + '\n'

            with open(NGINX_SITE_TPL) as tpl:
                tpl = tpl.read()

                replace_it = (
                    ("{$SITE_TYPE}", sitetype),
                    ("{$WEB_PATH}", site_webpath_dir),
                    ("{$SERVER_NAME}", f"{domain} www.{domain}"),
                    ("{$LOG_FILE}", site),
                )

                for s in replace_it:
                    tpl = tpl.replace(*s)

                nginx_sites_config += tpl + '\n'
        else:
            print_warning(f'Project directory "{site_webpath_dir}" doesnt\'t exist. Skipping...')

    with open(NGINX_PROXIES_CONF, 'w') as f:
        f.write(nginx_proxy_config)

    with open(NGINX_SITES_CONF, 'w') as f:
        f.write(nginx_sites_config)


def save_docker_composer_config(workspace_dir, containers_whitelist=None):
    """
    Retrieve docker-compose content and bind volumes
    """
    docker_compose_conf = read_yaml(DOCKER_COMPOSE_TPL)
    volume = (
        f"nfsmount:{workspace_dir}" if platform.system() == 'Darwin'
        else f"{workspace_dir}:{workspace_dir}"
    )

    for config in docker_compose_conf['services'].values():
        if 'volumes' in config and config['volumes'] == '%VOLUMES%':
            config['volumes'] = [volume]

    # Selective build
    if containers_whitelist is not None:
        to_keep = containers_whitelist
        to_remove = []

        for k, f in enumerate(to_keep):
            if f not in docker_compose_conf['services']:
                print_warning(f"Service '{f}' doesnt't exist. Skipping...")
                del to_keep[k]

        for service in docker_compose_conf['services']:
            if service not in to_keep:
                to_remove.append(service)

        for rm in to_remove:
            del docker_compose_conf['services'][rm]

        for k in docker_compose_conf['services']:
            if 'depends_on' in docker_compose_conf['services'][k]:
                del docker_compose_conf['services'][k]['depends_on']

    dump_yaml(
        DOCKER_COMPOSE, docker_compose_conf
    )


def get_available_services():
    dockcom = read_yaml(DOCKER_COMPOSE_TPL)
    return list(dockcom['services'].keys())


def read_yaml(yamlfile, loader=yaml.SafeLoader):
    with open(yamlfile) as f:
        return yaml.load(f, Loader=loader)


def dump_yaml(yamlfile, data):
    with open(yamlfile, 'w') as f:
        yaml.dump(data, f,
                  Dumper=AliasDisabledDumper,
                  default_flow_style=False,
                  indent=4,
                  width=150,
                  block_seq_indent=4)


def print_msg(msg, color=Fore.WHITE, _exit=False, exitcode=0):
    print(color + msg + Style.RESET_ALL)
    if _exit:
        sys.exit(exitcode)


def print_error(msg, _exit=False, exitcode=1):
    print_msg(msg, Fore.RED, _exit, exitcode)


def print_warning(msg, _exit=False, exitcode=1):
    print_msg(msg, Fore.YELLOW, _exit, exitcode)


def print_info(msg, _exit=False, exitcode=0):
    print_msg(msg, Fore.CYAN, _exit, exitcode)


def print_success(msg, _exit=False, exitcode=0):
    print_msg(msg, Fore.GREEN, _exit, exitcode)


def parse_args():
    parser = argparse.ArgumentParser(
        formatter_class=WideFormatter
    )
    sub = parser.add_subparsers(title='Commands', dest='command', required=True)

    sub.add_parser('build',
        description='Build all server\'s containers.',
        formatter_class=WideFormatter)
    sub.add_parser('configure', description='Generate config files and exit')
    sub.add_parser('up', formatter_class=WideFormatter)
    sub.add_parser('restart')
    sub.add_parser('sites', description='Show mounted site domains.')

    sub.add_parser('stop')
    cmd_down = sub.add_parser('down')
    cmd_prune = sub.add_parser('prune')
    cmd_status = sub.add_parser('status')
    cmd_status.add_argument('--ip', help='Show IPs too', action='store_true')
    sub.add_parser('ip')

    # Commands with build refresh possible
    cmd_refresh = sub.add_parser('refresh',
        description='Refresh (rebuild) containers. Useful after container\'s '
                        'configuration has been altered')
    available_services = ', '.join(
        get_available_services()
    )

    cmd_refresh.add_argument('-c',
                             metavar='container',
                             nargs='*',
                             help='Limit containers to be refreshed. Whitelisting possible with following values: '
                             f'{Fore.GREEN}{available_services}{Style.RESET_ALL}. / all if empty')

    # Down command
    cmd_down.add_argument('--volumes', action='store_true', help='Remove named volumes declared in the `volumes` '
                                                                 'section of the Compose file and anonymous volumes'
                                                                 ' attached to containers')
    cmd_prune.add_argument('--volumes', action='store_true', help='Prune volumes too')

    # Build command
    # cmd_build.add_argument(
    #     '--workspace-dir',
    #     required=True,
    #     type=str,
    #     help='Workspace mount path for volume (this path remains identical inside docker\'s container).')

    # cmd_build.add_argument(
    #     '--domain-suffix',
    #     type=str,
    #     default="localhost",
    #     help='Url domain suffix. Defaults to ".localhost"')

    return parser.parse_args()


class AliasDisabledDumper(yaml.RoundTripDumper):  # pylint: disable=too-many-ancestors
    def ignore_aliases(self, _data):
        return True


class WideFormatter(argparse.HelpFormatter):
    def __init__(self, prog, indent_increment=2, max_help_position=100, width=80):
        super().__init__(prog, indent_increment, max_help_position, width)


if __name__ == '__main__':

    ROOT = sys.path[0]
    ENV = ROOT + '/.env'
    load_envs()

    DOCKER_COMPOSE = ROOT + '/config/docker-compose.yml'
    DOCKER_COMPOSE_TPL = ROOT + '/config/docker-compose.template.yml'
    NGINX_PROXY_SITE_TPL = ROOT + '/containers/nginx-proxy/_proxy.conf.tpl'
    NGINX_PROXIES_CONF = ROOT + '/containers/nginx-proxy/conf.d/1.proxy.conf'
    NGINX_SITE_TPL = ROOT + '/containers/nginx/_site.conf.tpl'
    NGINX_SITES_CONF = ROOT + '/containers/nginx/conf.d/sites.conf'
    VALID_CONF_TYPES = [
        sitetype[:-5] for sitetype in os.listdir(ROOT + '/containers/nginx/conf.d/sitetypes')
    ]

    SITES = os.getenv('SERVER_WORKSPACE_DIR', default='') + '/.sites.yml'

    validate()

    run(
        parse_args()
    )
