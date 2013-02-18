Hibera
======

Hibera is a control plane for distributed applications. It's designed to
simplify operations for things like fault tolerance, fail-over, configuration.

Similar projects are:
* Zookeeper
* Google chubby
* Doozer

Command line
============

Type `hibera` to see command line usage.

MySQL Failover Example
----------------------

* Start-up script

```
    hibera run mysql -count 3 -start start-mysql-slave.sh -stop stop-mysql-slave.sh
```

* start-mysql.sh

```
    #!/bin/bash
    MASTER=$(hibera members mysql -limit 1)
    if [ "$MASTER" = "*" ]; then
        # Looks like we're the master.
        associate-mysql-master-ips.sh
        start-mysql-master.sh
    else
        # Looks like we're a slave (2-3).
        remove-mysql-master-ips.sh
        start-mysql-slave.sh $MASTER
    fi
```

* stop-mysql.sh

```
    #!/bin/bash 
    remove-mysql-master-ips.sh
    /etc/init.d/mysql stop
```

OpenStack Servers
-----------------

* Initial setup

```
    # Load the config which will stay synchronized.
    cat /etc/nova/nova.conf | hibera set openstack.config
    
    # Create the set of IPs that we will associate with API nodes.
    echo 10.1.1.1 10.1.1.2 10.1.1.3 | hibera set openstack.ips
```

* /etc/rc.local

```
    # Ensure the configurations are synchronized.
    hibera sync openstack.config --output /etc/nova/nova.conf --exec restart-nova.sh
    
    # Always run three API servers.
    hibera run openstack.api -count 3 -start start-api.sh -stop stop-api.sh
```

* restart-nova.sh

```
    #!/bin/bash
    # The configuration file has changed.
    restart nova-compute
    restart nova-api
    restart nova-network
    restart nova-scheduler
```

* start-api.sh

```
    #!/bin/bash
    # Annoying how this has be done, but
    # in bash land it's tricky. We just 
    # generate two files and do a zip with
    # paste.
    f1=$(mktemp)
    f2=$(mktemp)
    hibera get openstack.ips >$f1
    hibera members openstack.api >$f2
    trap "rm -f $f1 $f2"
    
    # Make sure we've got the correct IP
    # associate (do a linear mapping from 
    # the membership list).
    paste $f1 $f2 | (while read IP API; do 
        if [ "$API" = "*" ]; then
            associate.sh $IP
        else
            disassociate.sh $IP
        fi
    done)
    
    # Ensure the API server is running.
    service start nova-api
```

* stop-api.sh

```
    #!/bin/bash
    # Disassociate all IPs in the pool.
    for IP in $(hibera get openstack.ips); do
        disassociate.sh $IP
    done
    # No need to run the API service.
    service stop nova-api
```

Internal API
============

Locks
-----
```
    client := NewHiberaClient(address)

    // Acquire a lock (fires an event).
    //   POST /locks/{key}?timeout={timeout}?name={name}
    //
    // timeout -- Use 0 for no timeout.
    // name -- Use the empty string for the default name.
    rev, err := client.Lock(key, timeout, name)

    // Releasing a lock (fires an event).
    //   DELETE /locks/{key}
    rev, err = client.Unlock(key)

    // Check if a lock is locked (and by who).
    //   GET /locks/{key}?name={name}
    owners, rev, err := client.Owners(key, name)

    // Wait for a lock to be acquired / released.
    //   GET /watches/{key}?rev={rev}&timeout={timeout}
    //
    // rev -- Use 0 for any revision.
    rev, err := client.Watch(key, rev, timeout)
```

Groups
------
```
    client := NewHiberaClient(address)

    // Joining a group (fires an event).
    // NOTE: By default, the member name used will be the address of the
    // client socket received on the server end. This can be overriden by
    // providing a name in the join call below. You can actually join multiple
    // times by providing different names.
    //   POST /groups/{group}?name={name} 
    //
    // name -- Use the empty string to use the default name.
    rev, err := client.Join(group, name)

    // Leaving a group (fires an event).
    //   DELETE /groups/{group}?name={name}
    //
    // name -- Use the empty string to use the default name.
    rev, err = client.Leave(group, name)

    // List the members of the group.
    // NOTE: Members returned have a strict ordering (the first member is
    // the leader). You can easily implement a service that needs N leaders
    // by selecting the first N members of the group, which will be stable.
    // Also, if there are members matching {name} -- they will be returned
    // with a prefix of '*'.
    //   GET /groups/{group}/?name={name}&limit={name}
    //
    // limit -- Use 0 to specify no limit.
    members, rev, err := client.Members(group, name, limit)

    // Wait for group members to change.
    //   GET /watches/{key}?rev={rev}&timeout={timeout}
    //
    // rev -- Use 0 for any rev.
    rev, err := client.Watch(key, rev, timeout)
```

Data
----
```
    client := NewHiberaClient(address)

    // Reading a value.
    //   GET /data/{key}
    value, rev, err := client.Get(key)

    // Writing a value (fires an event).
    for {
        // Will fail if the rev is not the same.
        //   POST /data/{key}?rev={rev}
        // rev -- Use 0 for any rev.
        rev, err := client.Set(key, newvalue, rev+1)
        if err is nil {
            break;
        }
    } 

    // Wait until the key is not at given rev.
    //   GET /watches/{key}?rev={rev}&timeout={timeout}
    e/ rev -- Use 0 for any rev.
    rev, err := client.Watch(key, rev, timeout)

    // Delete the data under a key.
    //   DELETE /watches/{key}?rev={rev}
    // rev -- Use 0 for any rev.
    rev, err = client.Remove(key, rev)

    // List all data.
    //   GET /data/
    items, err = client.List()

    // Delete all data.
    //   DELETE /data/
    err = client.Clear()
```

Events
------
```
    client := NewHiberaClient(address)

    // Fire an event manually.
    //   POST /watches/{key}?rev={rev}
    //
    // rev -- Use 0 for any rev.
    rev, err := client.Fire(key, rev)
```

HTTP API
========

/
---

* GET
    Fetches basic cluster info. Takes a `base` query parameter for deltas.

/locks/{key}
------------

* GET

    Get the current state of a lock. The revision is returned in the header `X-Revision`. You may also specify a query parameter `name` to change the name of the client (if the client is an owner, one element will have an asterisk).

* POST

    Acquire a lock. Use the query parameter `timeout` to specific some timeout. If the lock is not acquired, an HTTP error is returned. You may also use `limit` to support acquiring a lock multiple times.

* DELETE

    Release a lock. If the lock is not currently held, an HTTP error is returned.

/groups/{group}
---------------

* GET

    List group members. Use the query parameter `limit` to list only a limited number of members. You may use also use the `name` parameter to change the name of the client in the same way as with locks.

* POST

    Join a group. Use the query parameter `name` to use a specific name (otherwise the client socket address is used).

* DELETE

    Leave the given group. You may need to specify `name` if you've joined under a different name.

/data
------

* GET

    List all data keys. This is massively expensive. Don't do it.

* DELETE

    Delete all data in the system.

/data/{key}
-----------

* GET

    Get the current data. The revision is returned in the header `X-Revision`.

* POST

    Update the given key. Takes a `rev` query parameter.

* DELETE

    Remove all data in the given key. Takes a `rev` query parameter.

/watches/{key}
--------------

* GET

    Watch on the given key. Takes a `rev` query parameter. Also takes an optional `timeout` parameter.

* POST

    Fires an event on the given key. You may specify a `rev` parameter to fire only if the `rev` matches.
