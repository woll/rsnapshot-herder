#!/bin/sh
set -- junk $SSH_ORIGINAL_COMMAND
shift
case $1 in
    sleep)
        /bin/sleep 10
        ;;
    rsnapshot-herder)
	shift
        sudo <path_to_install_dir>/rsnapshot-herder $*
        ;;
    *)
        echo "Command not supported with this ssh key"
        exit 1
        ;;
esac
