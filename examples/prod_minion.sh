export SALT_VERSION="3005.1"  # Or change it to your needs, we'll use git salt bootstrap to install SaltStack.

export USER_PUB_KEY="YOUR-OWN-PUBLIC-KEY"  # Use your own public key, you previously created on your local machine.

export MINION_SHOULD_INSTALL=true
export MINION_ID=minion1  # Choose what is appropriate for you, check top.sls files to figure out.
export MINION_SALTENV=base  # We lock each minion with a specific saltenv and pillarenv, choose `base` default salt env if you don't use salt envs.
export MINION_PILLARENV=base

export MASTER_SHOULD_INSTALL=false  # We don't need any master on this VPS machine, just the salt minion.
export MASTER_IP=1.2.3.4  # Choose the master's IP address, and make sure ports 4505, 4506 are available on the master

export PROJECT_UID=1234
export PROJECT_USERNAME=project
export PROJECT_HOME=/project

export SSH_PORT=3198  # Use a different ssh port and remember it to configure your `~/.ssh/config`