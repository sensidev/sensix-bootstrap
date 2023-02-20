export SALT_VERSION="3005.1"  # Or change it to your needs, we'll use git salt bootstrap to install SaltStack.

export USER_PUB_KEY="YOUR-OWN-PUBLIC-KEY"  # Use your own public key, you previously created on your local machine.

export MINION_ID=minion1  # Choose what is appropriate for you, check top.sls files to figure out.

export PROJECT_UID=1234
export PROJECT_USERNAME=project
export PROJECT_HOME=/project

export SSH_PORT=3198  # Use a different ssh port and remember it to configure your `~/.ssh/config`