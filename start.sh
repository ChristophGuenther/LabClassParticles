#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
# Modified by Manuel Giffels <giffels@gmail.com>

set -e

# Exec the specified command or fall back on bash
if [ $# -eq 0 ]; then
    cmd=bash
else
    cmd=$*
fi

for f in /usr/local/bin/start-notebook.d/*; do
  case "$f" in
    *.sh)
      echo "$0: running $f"; . "$f"
      ;;
    *)
      if [ -x $f ]; then
        echo "$0: running $f"
        $f
      else
        echo "$0: ignoring $f"
      fi
      ;;
  esac
  echo
done
# Handle special flags if we're root
if [ $(id -u) == 0 ] ; then

    # Only attempt to change the jovyan username if it exists
    if id jovyan &> /dev/null ; then
      echo "Set username to: $NB_USER"
      usermod -d /home/$NB_USER -l $NB_USER jovyan
    fi

    # Handle case where provisioned storage does not have the correct
    # permissions by default
    # Ex: default NFS/EFS (no auto-uid/gid)
    if [[ "$CHOWN_HOME" == "1" || "$CHOWN_HOME" == 'yes' ]]; then
        echo "Changing ownership of /home/$NB_USER to $NB_UID:$NB_GID"
        chown $CHOWN_HOME_OPTS $NB_UID:$NB_GID /home/$NB_USER
    fi
    if [ ! -z "$CHOWN_EXTRA" ]; then
        for extra_dir in $(echo $CHOWN_EXTRA | tr ',' ' '); do
            chown $CHOWN_EXTRA_OPTS $NB_UID:$NB_GID $extra_dir
        done
    fi

    # handle home and working directory if the username changed
    if [[ "$NB_USER" != "jovyan" ]]; then
        # changing username, make sure homedir exists
        # (it could be mounted, and we shouldn't create it if it already exists)
        if [[ ! -e "/home/$NB_USER" ]]; then
            echo "Relocating home dir to /home/$NB_USER"
            mv /home/jovyan "/home/$NB_USER"
        fi
        # if workdir is in /home/jovyan, cd to /home/$NB_USER
        if [[ "$PWD/" == "/home/jovyan/"* ]]; then
            newcwd="/home/$NB_USER/${PWD:13}"
            echo "Setting CWD to $newcwd"
            cd "$newcwd"
        fi
    fi

    # Change UID of NB_USER to NB_UID if it does not match
    if [ "$NB_UID" != $(id -u $NB_USER) ] ; then
        echo "Set $NB_USER UID to: $NB_UID"
        usermod -u $NB_UID $NB_USER
    fi

    # Change GID of NB_USER to NB_GID if NB_GID is passed as a parameter
    if [ "$NB_GID" != $(id -g $NB_USER) ] ; then
        echo "Set $NB_USER GID to: $NB_GID"
        groupmod -g $NB_GID -o $(id -g -n $NB_USER)
    fi

    # Enable sudo if requested
    if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == 'yes' ]]; then
        echo "Granting $NB_USER sudo access"
        echo "$NB_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook
    fi

    #Change owner of homedir
    [ stat -c %U /home/$NB_USER == $NB_USER ] || chown $NB_USER /home/$NB_USER
    [ stat -c %g /home/$NB_USER == $NB_GID ] || chgrp $NB_GID /home/$NB_USER

    #Copy over JupyRoot Kernel
    su $NB_USER -c "env PATH=$PATH mkdir -p /home/$NB_USER/.local/share/jupyter"
    su $NB_USER -c "env PATH=$PATH rsync -az /usr/lib64/python3.7/site-packages/JupyROOT/ /home/$NB_USER/.local/share/jupyter"

    # Exec the command as NB_USER
    echo "Execute the command: $cmd"
    exec sudo -E -H -u $NB_USER PATH=$PATH PYTHONPATH=$PYTHONPATH $cmd
else
  if [[ ! -z "$NB_UID" && "$NB_UID" != "$(id -u )" ]]; then
      echo 'Container must be run as root to set $NB_UID'
  fi
  if [[ ! -z "$NB_GID" && "$NB_GID" != "$(id -g)" ]]; then
      echo 'Container must be run as root to set $NB_GID'
  fi
  if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == 'yes' ]]; then
      echo 'Container must be run as root to grant sudo permissions'
  fi
    # Exec the command
    echo "Execute the command: $cmd"
    exec $cmd
fi
