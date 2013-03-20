#!/bin/bash

### Install the packages.

# Start the daemon.
/etc/init.d/hibera start

### Create our scripts.
mkdir -p /etc/hibera

# Create our sync script.
cat >/etc/hibera/sync <<EOF
#!/bin/bash
# Synchronize across all files.
# NOTE: We are a sync script, so the
# data will come via stdin. We also 
# never remove files this way for safety.
cd /etc/hibera
while read file; do
   echo "Writing \$file..."
   hibera get \$file > \$file
done
# Call our post hook.
if [ -e /etc/hibera/post ]; then
   bash /etc/hibera/post
fi
EOF
chmod a+x /etc/hibera/sync

# Create our startup script.
cat >/etc/hibera/startup <<EOF
#/bin/bash
# Kill all current running instances.
killall hibera 2>/dev/null
# Run under the hosts key and synchronize files.
hibera run hosts -name \$(hostname) hibera sync files /etc/hibera/sync &
EOF
chmod a+x /etc/hibera/startup

### Setup start-up (for subsequent boots).
if ! grep /etc/hibera/startup /etc/rc.local >/dev/null 2>/dev/null; then
    # Make sure the script is not exitted prior to our running.
    grep -vE '^exit 0' /etc/rc.local > /etc/rc.local.tmp && \
        mv /etc/rc.local.tmp /etc/rc.local

    # Add the call to /etc/hibera/startup.
    echo '/etc/hibera/startup' >> /etc/rc.local
fi

bash /etc/hibera/startup
