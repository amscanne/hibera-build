Hibera
======

Hibera is a control plane for distributed applications. It's designed to
simplify operations for things like fault tolerance, fail-over, configuration.

Similar projects are:
* Zookeeper
* Google chubby
* Doozer

Why?
====

Why not?

Hibera adds a few things for distributed co-ordination that I believe are useful:
* Automatic node addition and removal.
* A useable command-line tool.
* Simple authentication (with namspaces via CNAMEs).

It does have several glaring weaknesses at the moment:
* No real security model.
* Performance has not been a consideration.
* It's model for quorum is probably buggy.

Command line
============

Type `hibera` to see command line usage.

Internal API
============

Locks
-----
```
    client := NewHiberaClient(addrs, auth, 0)

    // Acquire a lock (fires an event).
    //   POST /sync/{key}?timeout={timeout}&name={name}&limit={limit}
    //
    // name -- Use the empty string for the default name.
    // limit -- For a lock, this is the number of holders (1 is a mutex).
    // timeout -- Use 0 for no timeout.
    index, rev, err := client.SyncJoin(key, name, limit, timeout)

    // Releasing a lock (fires an event).
    //   DELETE /locks/{key}?name={name}
    rev, err = client.SyncLeave(key, name)

    // Wait for a lock to be acquired / released.
    //   GET /event/{key}?rev={rev}&timeout={timeout}
    //
    // rev -- Use 0 for any revision.
    // timeout -- Only wait for a fixed time.
    rev, err := client.EventWait(key, rev, timeout)
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
    index, rev, err := client.SyncJoin(group, name, 0, 0)

    // Leaving a group (fires an event).
    //   DELETE /sync/{key}?name={name}
    //
    // name -- Use the empty string to use the default name.
    rev, err = client.SyncLeave(group, name)

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
    index, members, rev, err := client.SyncMembers(group, name, limit)

    // Wait for group members to change.
    //   GET /event/{key}?rev={rev}&timeout={timeout}
    //
    // rev -- Use 0 for any rev.
    // timeout -- Only wait for a fixed time.
    rev, err := client.EventWait(key, rev, timeout)
```

Data
----
```
    client := NewHiberaClient(addrs, auth, 0)

    // Reading a value.
    //   GET /data/{key}
    value, rev, err := client.DataGet(key)

    // Writing a value (fires an event).
    for {
        // Will fail if the rev is not the same.
        //   POST /data/{key}?rev={rev}
        //
        // rev -- Use 0 for any rev.
        rev, err = client.DataSet(key, rev+1, newvalue)
        if err is nil {
            break;
        }
    } 

    // Wait until the key is not at given rev.
    //   GET /event/{key}?rev={rev}&timeout={timeout}
    e/ rev -- Use 0 for any rev.
    rev, err = client.EventWait(key, rev, timeout)

    // Delete the data under a key.
    //   DELETE /data/{key}?rev={rev}
    //
    // rev -- Use 0 for any rev.
    rev, err = client.DataRemove(key, rev)

    // List all data.
    //   GET /data/
    items, err = client.DataList()
```

Events
------
```
    client := NewHiberaClient(addrs, 0)

    // Fire an event manually.
    //   POST /event/{key}?rev={rev}
    //
    // rev -- Use 0 for any rev.
    rev, err := client.EventFire(key, rev)
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

Clients should specify an `X-Client-Id` header with a unique string. This will
allow them to connect using multiple names and associate ephemeral nodes.  For
example, supporose a client connects to a server with two TCP sockets, A and B.

    Client                                              Server
           ---A---> SyncJoin w/ X-Client-Id ---A--->     Ok
           ---B---> EventWait w/ X-Client-Id ---B--->    Ok
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

/data/{key}
-----------

* GET

    Get the current data.

    `rev` -- Return when the rev is not `rev`.
             Use 0 to return on the first change.

    `timeout` -- Return after `timeout` milliseconds.

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

* POST

    Fires an event on the given key.
    
    `rev` -- Fire only if the revision is currently `rev`.

* GET

    Wait for synchronization events on the given key.
    
    `rev` -- Return when the rev is not `rev`.
             Use 0 to return on the first change.

    `timeout` -- Return after `timeout` milliseconds.

/data/{key}
-----------

* GET

    Get the auth token (JSON).

* POST

    Create or update the given auth token (JSON).

* DELETE

    Delete the given auth token.

/event/{key}
------------

* POST

    Fires an event on the given key.
    
    `rev` -- Fire only if the revision is currently `rev`.

* GET

    Wait until the key is not at revision `rev`.

    `rev` -- Fire only when the revision is not `rev`.

/access
-------

* GET

    List all access tokens.

* DELETE

    Delete all access tokens in the system.

/access/{key}
-----------

* GET

    Get the given access token.

* POST

    Grant access to a given path for the token.

    `path` -- The path to modify.
    `read` -- True / false for read permission.
    `write` -- True / false for write permission.
    `execute` -- True / false for synchronization permission.

* DELETE

    Delete the given access token.
