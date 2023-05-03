#!/bin/bash

#
# Project pre-provisioning Salt Master and Minions.
# Run this as part of the README.md getting started steps.
# Run this as root user on a fresh machine.
#
export MINION_ID=${MINION_ID:=$1}  # Look for first argument by default

export MINION_SHOULD_INSTALL=${MINION_SHOULD_INSTALL:=true}
export MINION_SALTENV=${MINION_SALTENV:="base"}
export MINION_PILLARENV=${MINION_PILLARENV:="base"}

export MASTER_SHOULD_INSTALL=${MASTER_SHOULD_INSTALL:=true}
export MASTER_CONFIG=${MASTER_CONFIG:="dev"}
export MASTER_IP=${MASTER_IP:="127.0.0.1"}

export PROJECT_UID=${PROJECT_UID:=1234}
export PROJECT_USERNAME=${PROJECT_USERNAME:="project"}
export PROJECT_HOME=${PROJECT_HOME:="/project"}

export PROJECT_SALT_HOME="${PROJECT_HOME}/devops"
export PROJECT_SALT_DEVELOPMENT_HOME="${PROJECT_SALT_HOME}/development"

SALT_VERSION=${SALT_VERSION:="v3006.0"}

USER_PUB_KEY=${USER_PUB_KEY:=""}

SSH_PORT=${SSH_PORT:=3339}
SSH_CONFIG=$(cat <<-END
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 2m
PermitRootLogin no
StrictModes yes
MaxAuthTries 6
MaxSessions 10
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
END
)

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
    if [[ -z ${USER_PUB_KEY} ]]; then
        echo "Error. Missing user pub key, set USER_PUB_KEY env var"
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
    adduser --gecos "${PROJECT_USERNAME}" --uid ${PROJECT_UID} --home ${PROJECT_HOME} --disabled-password ${PROJECT_USERNAME}

    echo ">>> Generate ssh keys in ${PROJECT_HOME}/.ssh/"
    echo ">>> This is going to be overriden by non-dev envs!"
    sudo -u ${PROJECT_USERNAME} ssh-keygen -b 2048 -t rsa -f ${PROJECT_HOME}/.ssh/id_rsa -q -P ""

    echo ">>> Append user pub key to ${PROJECT_HOME}.ssh/authorized_keys"
    echo "${USER_PUB_KEY}" >> "${PROJECT_HOME}/.ssh/authorized_keys"

    echo ""
    sudo -u ${PROJECT_USERNAME} cat ${PROJECT_HOME}/.ssh/id_rsa.pub
    echo ""

    echo "Add the above ${PROJECT_USERNAME} user's public key to your Bitbucket and GitHub accounts."

    echo "Did you add it? (ignore for minion prod envs)"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) echo "Added!"; break;;
            No ) echo "OK, you know what you are doing!"; break;;
        esac
    done

    echo "Now is the time to run in another shell clone.sh (ignore for minion prod envs)"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) echo "Ran clone.sh from my salt repo!"; break;;
            No ) echo "OK, you know what you are doing!"; break;;
        esac
    done
}

function install_packages() {
    echo ">>> Bootstrap SaltStack with Python3"
    # wget -O bootstrap-salt.sh https://bootstrap.saltstack.com

    echo ">>> SKIP downloading the official bootstrap - they have issues at the moment, using an old bootstrap script"
    wget -O bootstrap-salt.sh https://raw.githubusercontent.com/sensidev/sensix-bootstrap/main/bootstrap-salt.sh

    # https://github.com/saltstack/salt-bootstrap
    OPTIONS="-PD"  # Default, install Master and Minion

    if [[ "${MASTER_SHOULD_INSTALL}" = true ]]; then
        OPTIONS="${OPTIONS}M"
    fi

    if [[ "${MINION_SHOULD_INSTALL}" = false ]]; then
        OPTIONS="${OPTIONS}N"
    fi

    echo ">>> Install apt packages required for SaltStack"
    apt-get install -y git libgit2-dev python3-pip

    echo ">>> Install SaltStack version ${SALT_VERSION} by bootstrapping with options ${OPTIONS}"
    sh bootstrap-salt.sh ${OPTIONS} -x python3 git "${SALT_VERSION}"
    check_error $? "Could not install SaltStack"

    echo ">>> Install pip packages required for SaltStack"
    pip3 install pygit2==1.7.2

    echo ">>> Downgrade some packages (as a workaround for now) Is this still necessary?"
    pip3 install markupsafe==2.0.1 jinja2==3.0.3 pyzmq==20.0.0

    echo ">>> Installed SaltStack versions report"
    salt --versions-report
}

function config_sshd() {
    echo ">>> Config sshd"
    echo "${SSH_CONFIG}" > /etc/ssh/sshd_config.d/base.conf

    echo ">>> Config sshd Port: ${SSH_PORT}"
    echo "Port ${SSH_PORT}" > /etc/ssh/sshd_config.d/port.conf

    echo ">>> Restart sshd service"
    systemctl restart sshd
    check_error $? "Could not restart sshd"
}

function install_fail2ban {
    echo ">>> Install fail2ban"
    apt-get install -y fail2ban

    echo ">>> Config sshd Port: ${SSH_PORT}"
    echo -e "[ssh]\nport= ${SSH_PORT}" > /etc/fail2ban/jail.d/ssh_port.conf

    echo ">>> Restart fail2ban service"
    systemctl restart fail2ban
    check_error $? "Could not start fail2ban"
}

function check_salt_master_setup() {
    if [[ "${MASTER_SHOULD_INSTALL}" = true ]]; then
        if [ -z "${MASTER_CONFIG}" ]; then
            echo "Error. No Master config file provided! Did you clone the salt repos first?"
            echo "Options are filenames without extensions, listed in salt/masters within git salt repo"
            exit 2
        fi
        if [[ ! -f "${PROJECT_SALT_DEVELOPMENT_HOME}/salt/masters/${MASTER_CONFIG}.yml" ]]; then
            echo "Error. No Master config file exists at ${PROJECT_SALT_DEVELOPMENT_HOME}/salt/masters/${MASTER_CONFIG}.yml"
            exit 3
        fi
    fi
}

function config_salt_master() {
    if [[ "${MASTER_SHOULD_INSTALL}" = true ]]; then
        check_salt_master_setup

        echo ">>> Ensure salt master.d conf dir wrapper"
        mkdir -p /etc/salt/master.d

        echo ">>> Master config - /etc/salt/master.d/${MASTER_CONFIG}.conf"
        ln -sf "${PROJECT_SALT_DEVELOPMENT_HOME}/salt/masters/${MASTER_CONFIG}.yml" "/etc/salt/master.d/${MASTER_CONFIG}.conf"
        check_error $? "Could not create salt master config symlink"

        echo ">>> Master config interface IP"
        echo "interface: ${MASTER_IP}" > /etc/salt/master.d/interface.conf

        echo ">>> Salt Master service restart"
        systemctl restart salt-master
        check_error $? "Could not start salt master"
        sleep 2
    fi
}

function config_salt_minion() {
    if [[ "${MINION_SHOULD_INSTALL}" = true ]]; then
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
        check_error $? "Could not start salt minion"
        sleep 2
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
install_packages
create_project_user
install_fail2ban
config_sshd
config_salt_master
config_salt_minion
print_end_message
