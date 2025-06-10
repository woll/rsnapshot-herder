# How to install and setup rsnapshot-herder

Terminology:
* "Server": The machine where the backups are stored, and where rsnapshot is run
* "Client": A machine to be backed up

Note: This tutorial is based on the server and clients all running MacOS with MacPorts, so some of the example file paths to executables/system files may be different on other OSes. 

1) Install `rsnapshot` on the server

2) Install `rsync` on the client

3) Create a 'backup' user on the client (For security. Instead of using the root user)

4) Turn on ssh access for the 'backup' user on the client

5) To allow the server to run rsync on the client via ssh, without needing a login password, first create a host key on the server.
   Note: I've used `ed25519` because keys using older encryption methods may be rejected by newer OSes (eg more recent MacOS versions)
```
  sudo ssh-keygen -t ed25519 -a 100
```

6) From the server, copy this host key to the client
```
  sudo ssh-copy-id -i /var/root/.ssh/id_ed25519 backup@<client>
```
  or
```
  sudo cat /var/root/.ssh/id_ed25519.pub | ssh backup@<client> 'cat >> /Users/backup/.ssh/authorized_keys
```

7) Check that the server can run a command like `date`on the client as the 'backup' user, without asking for a password:
```
  sudo ssh backup@<client> date
```

8) Repeat steps 5-7 but reversing 'server' and 'client', to allow the 'backup' user on the client to connect to the server without requiring a password: Create a key on the client. Add that key to the 'backup' user's ssh authorized_keys file on the server. Check it works.

9) On the client, create a 'sudoers.d/backup' file (using `sudo visudo -f /etc/sudoers.d/backup` or the command below) for the 'backup' user, to restrict the 'backup' user to run 'rsync' as sudo:
```
  sudo tee /etc/sudoers.d/backup <<<'backup ALL = (root) NOPASSWD: /opt/local/bin/rsync'
```
  Test this logged on as the 'backup' user on the client with:
```
  sudo /opt/local/bin/rsync --version
```
  If that fails, then the main sudoers file on the client might be missing the line: `#includedir /etc/sudoers.d`

10) From the server, test that the sudoers file allows the server to run 'sudo rsync' on the client, but not anything else.
   This should work:
    ```
    sudo ssh backup@<client> sudo /opt/local/bin/rsync --version
    ```
    This should fail:
    ```
    sudo ssh backup@<client> sudo date
    ```

11) On the server create a 'sudoers.d/backup' file that restricts the 'backup' user to only executing rsnaphot-herder as sudo.

12) Improve security by restricting the commands that the 'backup' user can run on the server via ssh. On the server, install the `restrict_commands.sh` script and edit the path to `rsnapshot-herder`. On the server, add a `command` prefix to the 'backup' user's key in the 'backup' users authorized_keys file.
```
command="<path_to>/restrict_commands.sh"<space><key>
```

13) On the server, create an rsnapshot config file for each client. e.g. named `rsnapshot.<client>.conf`
```
sudo cp /opt/local/etc/rsnapshot.conf <your path>/rsnapshot.<client>.conf
```

14) In this client rsnapshot config file, set the snapshot_root (using rsnapshot.conf `<tab>` syntax) to a unique directory for each client. e.g.
```
snapshot_root<tab>/Volumes/BigBackupDisk/rsnapshot-<client>
```

15) Turn on the 'sync_first' mode
```
sync_first<tab>1
```

16) Set the lockfile to be unique for each client
```
lockfile<tab>/<rsnapshot_conf_dir>/rsnapshot-<client>.pid
```

17) Enable the cmd_ssh setting
```
cmd_ssh<tab>/usr/bin/ssh
```

18) Add the following to the rsync_long_args setting:
```
rsync_long_args<tab>--partial --partial-dir=.rsync-partial --rsync-path="sudo /opt/local/bin/rsync" -f'P .rsync-partial' 
```
The 'partial' args make rsync store partial transfers of the file being transferred, so that if the connection is broken (e.g. the user turns off the laptop client) then that part of the file wont need to be transferred again. Without this, rsync may continually try to re-transfer (large) files on each backup run and never succeed in completing a sync.
	The 'rsync-path' makes the rsync on the client run as the root user, so that it can access all the user files to be backed up.

To reduce/limit/prevent-saturation-of the bandwidth for clients with 'slow/expensive' connections, you can also add (choosing an appropriate value for `bwlimit`):
```
--compress --bwlimit=1MiB
```

19) Add a line to set the reverse ssh port (this should be a unique port for each client)
```
ssh_args<tab>-p 1999
```

20) Add a backup line for each client user account to be backed up
```
backup<tab>backup@localhost:<path-to-user1-home-on-client>/      .
backup<tab>backup@localhost:<path-to-user2-home-on-client>/      .
```

21) Install the `rsnapshot-herder` script on the server, and edit the capitalised variables in the `Configuration` section to match your requirements/system.

22) On each client, create a cron entry for the 'backup' user to create a reverse ssh tunnel and run rsnapshot-herder on the server, to try to backup every hour. Once a backup is completed successfully, rsnapshot-herder will not do another backup for that client until required.
Delete/do not use the multiple cron entries (like `rsnapshot daily` etc) that are required when not using the `sync_first` mode of rsnapshot.  
The port before the ':localhost' must match the port specified in step 19.
```
17 * * * * /usr/bin/ssh -fR 1999:localhost:22 backup@<server> sleep ; /usr/bin/ssh backup@<server> "rsnapshot-herder <client>/
```
The `sleep` and `rsnapshot-herder` are interpreted by the `restrict_commands.sh` script, which calls the real commands directly using their full paths.
Each run of `rsnapshot-herder` is independent from the others, so it doesn't actually matter if they run at the same time (apart from overwhelming the server it there's too many clients!).

Notes:
1) On MacOS, if backing-up to an external disk on the server then disable "Ignore ownership on this volume" in Finder for that disk, so that only the correct user (or root) on the server is able to view their files.
2) On MacOS, you probably want to add ` --xattrs` to the `rsync_long_args` in the client rsnapshot config file, so that Macintosh Resource Forks are backed up.
3) You have to decide whether to use the `rsync` option `--numeric-ids` or not. When `--numeric-ids` is set, the user number of the user that owns a file is copied unchanged to the server (where those IDs will refer to different users). If `--numeric-ids'` is unset, then it will translate the IDs using matching usernames on the client and server (so that, if there is a user on the server with the same name as on the client, that user on the server will own the backedup file).
