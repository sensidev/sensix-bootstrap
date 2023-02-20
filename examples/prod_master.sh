export SALT_VERSION="3005.1"  # Or change it to your needs, we'll use git salt bootstrap to install SaltStack.

export USER_PUB_KEY="YOUR-OWN-PUBLIC-KEY"  # Use your own public key, you previously created on your local machine.

export MINION_SHOULD_INSTALL=false  # We don't need any minion on this VPS machine, just the salt master.

export MASTER_SHOULD_INSTALL=true
export MASTER_CONFIG=prod  # Expects a `salt/masters/prod.yml` template file to exists in your salt git repo.
export MASTER_IP=0.0.0.0  # Use your VPS public IP or the wildcard to bind to all public interfaces.

export PROJECT_UID=1234
export PROJECT_USERNAME=project
export PROJECT_HOME=/project

# Below vars are almost useless if you use `gitfs` and or `git_pillar` instead of `roots` in your master config.
# In that case, the only reason to make a clone of your salt git repo, is to configure the master.
export PROJECT_SALT_GIT_REPO="git@bitbucket.org:project/project-salt.git"
export PROJECT_SALT_GIT_DEVELOPMENT_BRANCH="develop"  # Used for staging envs. This is also where the master config is actually pulled from.
export PROJECT_SALT_GIT_PRODUCTION_BRANCH="master" # Used for production envs.

export SSH_PORT=3198  # Use a different ssh port and remember it to configure your `~/.ssh/config`