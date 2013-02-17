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

    # Locks.
    hibera lock <key> [--name <name>] [--exec <run-script>]

    # Groups.
    hibera join <key> [--name <name>] [--exec <run-script>]

    hibera run <key> [--count <number>]
                     [--start <start-script>]
                     [--stop <stop-script>]

    hibera members <key> [--limit <number>]

    # Data.
    hibera get <key>
    hibera set <key>
    hibera sync <key> [--output <file>] [--exec <run-script>]

    # Watches.
    hibera watch <key>
    hibera fire <key>

Client API
==========

Locks
-----
    client := NewHiberaClient(address)

    // Acquire a lock (fires an event).
    //   POST /locks/{key}?timeout={timeout}?name={name}
    //
    // timeout -- Use 0 for no timeout.
    // name -- Use the empty string for the default name.
    err := client.Lock(key, timeout, name)

    // Releasing a lock (fires an event).
    //   DELETE /locks/{key}
    err = client.Release(key)

    // Check if a lock is locked (and by who).
    //   GET /locks/{key}
    owner, rev, err := client.State(key)

    // Wait for a lock to be acquired / released.
    //   GET /watches/{key}?rev={rev}
    //
    // rev -- Use 0 for any revision.
    rev, err := client.Watch(key, rev)

Groups
------
    client := NewHiberaClient(address)

    // Joining a group (fires an event).
    // NOTE: By default, the member name used will be the address of the
    // client socket received on the server end. This can be overriden by
    // providing a name in the join call below. You can actually join multiple
    // times by providing different names.
    //   POST /groups/{group}?name={name} 
    //
    // name -- Use the empty string to use the default name.
    err := client.Join(group, name)

    // Leaving a group (fires an event).
    //   DELETE /groups/{group}?name={name}
    //
    // name -- Use the empty string to use the default name.
    err = client.Leave(group, name)

    // List the members of the group.
    // NOTE: Members returned have a strict ordering (the first member is
    // the leader). You can easily implement a service that needs N leaders
    // by selecting the first N members of the group, which will be stable.
    //   GET /groups/{group}/ 
    //
    // limit -- Use 0 to specify no limit.
    members, rev, err := client.Members(group, limit)

    // Wait for group members to change.
    //   GET /watches/{key}?rev={rev}
    //
    // rev -- Use 0 for any rev.
    rev, err := client.Watch(key, rev)

Data
----
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
    //   GET /watches/{key}?rev={rev}
    // rev -- Use 0 for any rev.
    rev, err := client.Watch(key, rev)

    // Delete the data under a key.
    //   DELETE /watches/{key}?rev={rev}
    // rev -- Use 0 for any rev.
    err = client.Clear(key, rev)

Events
------
    client := NewHiberaClient(address)

    // Fire an event manually.
    //   POST /watches/{key}?rev={rev}
    //
    // rev -- Use 0 for any rev.
    err := client.Fire(key, rev)

HTTP API
========

/locks/{key}
* GET -- Get the current state of a lock. The revision is returned in the header `X-Revision`.
* POST -- Acquire a lock. Use the query parameter `timeout` to specific some timeout. If the lock is not acquired, an HTTP error is returned.
* DELETE -- Release a lock. If the lock is not currently held, an HTTP error is returned.

/groups/{group}
* GET -- List group members. Use the query parameter `limit` to list only a limited number of members.
* POST -- Join a group. Use the query parameter `name` to use a specific name (otherwise the client socket address is used).
* DELETE -- Leave the given group. You may need to specify `name` if you've joined under a different name.

/data/
* GET -- List all data keys. This is massively expensive. Don't do it.
* DELETE -- Delete all data in the system.

/data/{key}
* GET -- Get the current data. The revision is returned in the header `X-Revision`.
* POST -- Update the given key. Takes a `rev` query parameter.
* DELETE -- Remove all data in the given key. Takes a `rev` query parameter.

/watches/{key}
* GET -- Watch on the given key. Takes a `rev` query parameter.
* POST -- Fires an event on the given key. You may specify a `rev` parameter to fire only if the `rev` matches.
