#!/bin/bash

# NOTE: These are chosen so not to conflict with
# an existing system installation. You may want to
# edit port ranges if there are multiple users, etc.
HOST=127.0.0.1
FIRSTPORT=2034

PIDS=""
TEMPDIRS=""
PORT=$FIRSTPORT

waitall() {
    # Wait for all PIDs to die.
    for pid in $PIDS; do
        wait $pid
    done
}

cleanup() {
    # Kill all processes.
    for pid in $PIDS; do
        kill $pid
    done

    # Cleanup nicely.
    waitall

    # Cleanup all data dirs.
    for tempdir in $TEMPDIRS; do
        rm -rf $tempdir
    done
}
trap cleanup EXIT

startone() {
    # Create a temporary directory.
    LOGDIR=$(mktemp -d)
    DATADIR=$(mktemp -d)
    TEMPDIRS="$TEMPDIRS $LOGDIR $DATADIR"
    chmod u+rwx $LOGDIR
    chmod u+rwx $DATADIR

    # Spin-up with the first port as a seed.
    bin/hiberad -port $PORT -log $LOGDIR -data $DATADIR -bind $HOST -seeds $HOST:$FIRSTPORT -domain domain.$PORT run &
    PIDS="$PIDS $!"
    PORT=$(($PORT + 1))
}

if [ "x$1" != "x" ]; then
    i=0
    # Start many instances.
    while [ "$i" -lt "$1" ]; do
        startone
        i=$(($i+1))
    done
else
    # Start just a single instance.
    startone
fi

# Activate the cluster.
bin/hiberactl -api localhost:$FIRSTPORT activate

# Wait for all children.
waitall
