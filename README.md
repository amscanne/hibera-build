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

OpenStack Example
-----------------

* Initial setup

```
    # Load the config which will stay synchronized.
    cat /etc/nova/nova.conf | hibera set openstack.config
    
    # Create the set of IPs that we will associate with API nodes.
    echo 10.1.1.1 10.1.1.2 10.1.1.3 | hibera set openstack.ips
    echo 10.1.1.1 | hibera set openstack.ips.0
    echo 10.1.1.2 | hibera set openstack.ips.1
    echo 10.1.1.3 | hibera set openstack.ips.2
```

* /etc/rc.local

```
    # Ensure the configurations are synchronized.
    hibera sync openstack.config -output /etc/nova/nova.conf restart-nova.sh
    
    # Always run three API servers.
    hibera run openstack.api -limit 3 -start start-api.sh -stop stop-api.sh
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
    ips=$(hibera get openstack.ips)
    myip=$(hibera in openstack.ips)
    # Associate our IP from the pool.
    for ip in $ips; do
        if [ "$ip" == "$myip" ]; then
            associate.sh $ip
        else
            disassociate.sh $ip
        fi
    done
```

* stop-api.sh

```
    #!/bin/bash
    # Disassociate all IPs in the pool.
    for ip in $(hibera get openstack.ips); do
        disassociate.sh $IP
    done
```

Internal API
============

Locks
-----
```
    client := NewHiberaClient(addrs, 0)

    // Acquire a lock (fires an event).
    //   POST /sync/{key}?timeout={timeout}?name={name}&limit={limit}
    //
    // name -- Use the empty string for the default name.
    // limit -- For a lock, this is the number of holders (1 is a mutex).
    // timeout -- Use 0 for no timeout.
    index, rev, err := client.Join(key,  name, limit, timeout)

    // Releasing a lock (fires an event).
    //   DELETE /locks/{key}?name={name}
    rev, err = client.Leave(key, name)

    // Wait for a lock to be acquired / released.
    //   GET /event/{key}?rev={rev}&timeout={timeout}
    //
    // rev -- Use 0 for any revision.
    // timeout -- Only wait for a fixed time.
    rev, err := client.Wait(key, rev, timeout)
```

Groups
------
```
    client := NewHiberaClient(addrs, 0)

    // Joining a group (fires an event).
    // NOTE: By default, the member name used will be the address of the
    // client socket received on the server end. This can be overriden by
    // providing a name in the join call below. You can actually join multiple
    // times by providing different names.
    //   POST /sync/{key}?name={name}&limit={limit}&timeout={timeout}
    //
    // name -- Use the empty string to use the default name.
    // limit -- For a pure group, you should use 0.
    // timeout -- Not used if limit is 0.
    index, rev, err := client.Join(group, name, 0, 0)

    // Leaving a group (fires an event).
    //   DELETE /sync/{key}?name={name}
    //
    // name -- Use the empty string to use the default name.
    rev, err = client.Leave(group, name)

    // List the members of the group.
    // NOTE: Members returned have a strict ordering (the first member is
    // the leader). You can easily implement a service that needs N leaders
    // by selecting the first N members of the group, which will be stable.
    // Also, you own index for {name} will be returned via the index.
    // with a prefix of '*'.
    //   GET /sync/{key}/?name={name}&limit={name}
    //
    // name -- The name to use for the index.
    // limit -- Use 0 to specify no limit.
    index, members, rev, err := client.Members(group, name, limit)

    // Wait for group members to change.
    //   GET /event/{key}?rev={rev}&timeout={timeout}
    //
    // rev -- Use 0 for any rev.
    // timeout -- Only wait for a fixed time.
    rev, err := client.Wait(key, rev, timeout)
```

Data
----
```
    client := NewHiberaClient(addrs, 0)

    // Reading a value.
    //   GET /data/{key}
    value, rev, err := client.Get(key)

    // Writing a value (fires an event).
    for {
        // Will fail if the rev is not the same.
        //   POST /data/{key}?rev={rev}
        //
        // rev -- Use 0 for any rev.
        rev, err = client.Set(key, rev+1, newvalue)
        if err is nil {
            break;
        }
    } 

    // Wait until the key is not at given rev.
    //   GET /event/{key}?rev={rev}&timeout={timeout}
    e/ rev -- Use 0 for any rev.
    rev, err = client.Wait(key, rev, timeout)

    // Delete the data under a key.
    //   DELETE /data/{key}?rev={rev}
    //
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
    client := NewHiberaClient(addrs, 0)

    // Fire an event manually.
    //   POST /event/{key}?rev={rev}
    //
    // rev -- Use 0 for any rev.
    rev, err := client.Fire(key, rev)
```

HTTP API
========

The service API is entirely HTTP-based.

Data distribution is done by 301 redirects where necessary, so clients
*must* support this operation.

Headers
-------
Revisions are always returned in the header `X-Revision`.  This is true for
revisions of sync objects, data objects and the full cluster revision.

Clients may specify an `X-Client-Id` header with a generated string. This will
allow them to connection multiple names and associate ephemeral nodes.  For
example, support a client connects to a server with two TCP sockets, A and B.

    Client                                              Server
           ---A---> SyncJoin w/ X-Client-Id ---A--->     Ok
           ---B--->   Wait w/ X-Client-Id   ---B--->     Ok
           ---A---X Connection dies.
                    Client is still in joined group.

/
---

* GET
    Fetches cluster info.

/sync/{key}
---------------

* GET

    List syncronization group members.
    
    `limit` -- List only up to N members.
    
    `name` -- Use this name for computing the index.

* POST

    Join a synchronization group.
    
    `name` -- Use to specify a name to join under.
              One client may join multiple times.

    `limit` -- Block on joining until < limit members are in.

    `timeout` -- If `limit` is specified, timeout after 
                 a fixed number of milliesconds.

* DELETE

    Leave the given group.
    
    `name` -- The name to leave the group.

/data
------

* GET

    List all data keys.
    This is an expensive operation, don't do it.

* DELETE

    Delete all data in the system.
    This is also an expensive operation, don't do it.

/data/{key}
-----------

* GET

    Get the current data.

* POST

    Update the given key.

    `rev` -- Update only if the current rev is `rev`.
             Use 0 to update always.

* DELETE

    Delete the given key.

    `rev` -- Delete only if the current rev is `rev`.
             Use 0 to delete always.

/event/{key}
------------

* GET

    Wait on the given key.
    
    `rev` -- Return the rev is not `rev`.
             Use 0 to return on the first change.

    `timeout` -- Return after `timeout` milliseconds.

* POST

    Fires an event on the given key.
    
    `rev` -- Fire only if the revision is currently `rev`.
