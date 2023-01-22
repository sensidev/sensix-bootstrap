#!/bin/bash

#
# Sensix pre-provisioning Salt Master and Minions.
# Run this as part of the README.md getting started steps.
# Run this as root user on a fresh machine.
#

MINION_ONLY=${MINION_ONLY:=0}
MINION_ID=${MINION_ID:=$1}  # Look for first argument by default
MINION_SALTENV=${MINION_SALTENV:="base"}
MINION_PILLARENV=${MINION_PILLARENV:="base"}

MASTER_ONLY=${MASTER_ONLY:=0}
MASTER_TYPE=${MASTER_TYPE:="dev"}
MASTER_IP=${MASTER_IP:="127.0.0.1"}

PROJECT_UID=${PROJECT_UID:=1234}
PROJECT_USERNAME=${PROJECT_USERNAME:=project}
PROJECT_HOME=${PROJECT_HOME:=/project}
PROJECT_SALT_GIT_REPO=${PROJECT_SALT_GIT_REPO:=git@bitbucket.org:account/myrepo.git}
PROJECT_SALT_GIT_DEV_BRANCH=${PROJECT_SALT_GIT_DEV_BRANCH:=develop}
PROJECT_SALT_GIT_PROD_BRANCH=${PROJECT_SALT_GIT_PROD_BRANCH:=master}

SALT_VERSION=${SALT_VERSION:="3005.1"}
SSH_PORT=${SSH_PORT:=3339}

USER_PUB_KEY=${USER_PUB_KEY:=""}

function check_error() {
    # Function. Parameter 1 is the return code
    # Para. 2 is text to display on failure.
    if [[ "${1}" -ne "0" ]]; then
        echo "[ERROR] # ${1} : ${2}"
        # as a bonus, make our script exit with the right error code.
        exit "${1}"
    fi
}

function check_setup() {
    if [ -z "${MASTER_TYPE}" ]; then
        echo "No Master type provided! Options are filenames without extensions listed in salt/masters"
        exit 1
    fi

    if [[ -z ${USER_PUB_KEY} ]]; then
        echo "Missing user pub key, set USER_PUB_KEY env var"
        exit 1
    fi
}

function upgrade_system() {
    echo ">>> Upgrade system"
    apt-get update
    apt-get upgrade -y
    apt-get autoremove -y
}

function create_project_user() {
    echo ">>> Create project user"
    adduser --gecos "Sensix" --uid ${PROJECT_UID} --home ${PROJECT_HOME} --disabled-password ${PROJECT_USERNAME}

    echo ">>> Generate ssh keys in ${PROJECT_HOME}/.ssh/"
    sudo -u ${PROJECT_USERNAME} ssh-keygen -b 2048 -t rsa -f ${PROJECT_HOME}/.ssh/id_rsa -q -P ""

    echo ">>> Append user pub key to ${PROJECT_HOME}.ssh/authorized_keys"
    echo "${USER_PUB_KEY}" | sudo -u ${PROJECT_USERNAME} tee -a ${PROJECT_HOME}.ssh/authorized_keys

    echo ""
    sudo -u ${PROJECT_USERNAME} cat ${PROJECT_HOME}/.ssh/id_rsa.pub
    echo ""

    echo "Add the above ${PROJECT_USERNAME} user's public key to your Bitbucket and GitHub accounts."

    echo "Did you add it? (ignore for prod envs)"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) echo "Good!"; break;;
            No ) echo "OK, you know what you are doing!"; break;;
        esac
    done
}

function install_packages() {
    echo ">>> Bootstrap SaltStack with Python3"
    wget -O bootstrap-salt.sh https://bootstrap.saltstack.com

    # https://github.com/saltstack/salt-bootstrap
    OPTIONS="-MPD"  # Default, install Master and Minion

    if [[ ! ${MASTER_ONLY} -eq 0 ]]; then
        echo ">>> Install SaltStack Master Only"
        OPTIONS="-MNPD"
    fi

    if [[ ! ${MINION_ONLY} -eq 0 ]]; then
        echo ">>> Install SaltStack Minion Only"
        OPTIONS="-PD"
    fi

    echo ">>> Install apt packages required for SaltStack"
    apt-get install -y git libgit2-dev python3-pip

    echo ">>> Install SaltStack"
    sh bootstrap-salt.sh ${OPTIONS} -x python3 git "${SALT_VERSION}"

    echo ">>> Install pip packages required for SaltStack"
    pip3 install pygit2==1.7.2

    echo ">>> Downgrade some packages (as a workaround for now) Is this still necessary?"
    pip3 install markupsafe==2.0.1 jinja2==3.0.3 pyzmq==20.0.0

    echo ">>> Installed SaltStack versions report"
    salt --versions-report
}

function config_sshd() {
    echo ">>> Config sshd"
    cp configs/sshd.conf /etc/ssh/sshd_config.d/base.conf

    echo ">>> Config sshd Port: ${SSH_PORT}"
    echo "Port ${SSH_PORT}" > /etc/ssh/sshd_config.d/port.conf

    echo ">>> Restart sshd service"
    systemctl restart sshd
}

function install_fail2ban {
    echo ">>> Install fail2ban"
    apt-get install -y fail2ban

    echo ">>> Config sshd Port: ${SSH_PORT}"
    echo -e "[ssh]\nport= ${SSH_PORT}" > /etc/fail2ban/jail.d/ssh_port.conf

    echo ">>> Restart fail2ban service"
    systemctl restart fail2ban
}

function config_salt_master() {
    if [[ ${MINION_ONLY} -eq 0 ]]; then
        echo ">>> Ensure salt master.d conf dir wrapper"
        mkdir -p /etc/salt/master.d

        echo ">>> Master config"
        cat "salt/masters/${MASTER_TYPE}.yml" | envsubst > "/etc/salt/master.d/${MASTER_TYPE}.conf"

        echo ">>> Master config interface IP"
        echo "interface: ${MASTER_IP}" > /etc/salt/master.d/interface.conf

        echo ">>> Salt Master service restart"
        systemctl restart salt-master
        sleep 2
    fi
}

function config_salt_minion() {
    if [[ ${MASTER_ONLY} -eq 0 ]]; then
        if [ -z "${MINION_ID}" ]; then
            echo "No minion ID provided!"
            exit 1
        fi

        echo ">>> Ensure salt minion.d conf dir wrapper"
        mkdir -p /etc/salt/minion.d

        echo ">>> Minion config id: ${MINION_ID}"
        echo "id: ${MINION_ID}" > /etc/salt/minion.d/id.conf

        echo ">>> Minion config saltenv: ${MINION_SALTENV}"
        echo "saltenv: ${MINION_SALTENV}" > /etc/salt/minion.d/saltenv.conf

        echo ">>> Minion config pillarenv: ${MINION_PILLARENV}"
        echo "pillarenv: ${MINION_PILLARENV}" > /etc/salt/minion.d/pillarenv.conf

        echo ">>> Minion config master IP: ${MASTER_IP}"
        echo "master: ${MASTER_IP}" > /etc/salt/minion.d/master.conf

        echo ">>> Salt Minion service restart"
        systemctl restart salt-minion
        sleep 2
    fi
}

function clone_repos() {
    if [ "${MASTER_TYPE}" = "dev" ]; then
        echo ">>> Clone all git repos, for development"
        salt "${MINION_ID}" state.apply envs.repos pillar='{"force_git_repos":True}'

        check_error $? "Make sure you allow git repo access to your ssh key from ${PROJECT_HOME}/.ssh/*"
    fi
}

function print_end_message {
    echo "You're all set! Start provisioning with SaltStack"
    echo "Apply all salt states from the master:"

    echo ""
    echo "sudo salt '*' state.apply"
    echo ""

    echo "Important!"
    echo "Please test you can ssh into this VPS, on ssh port ${SSH_PORT}, with your own private key"
    echo "Do this before ending the current ssh session."
    echo "This is to avoid being locked up."
}

check_setup
upgrade_system
create_project_user
install_packages
install_fail2ban
config_sshd
config_salt_master
config_salt_minion
clone_repos
print_end_message
