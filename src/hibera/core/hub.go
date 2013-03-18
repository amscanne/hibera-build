package core

import (
    "sync"
    "sync/atomic"
    "hibera/utils"
)

type ConnectionId uint64
type Connection struct {
    // A reference to the associated core.
    *Hub

    // A unique Connection (per-connection).
    // This is generated automatically and can
    // not be set by the user (unlike the id for
    // the conn below).
    ConnectionId

    // The address associated with this conn.
    addr string

    // The user associated (if there is one).
    // This will be looked up on the first if
    // the user provided a generated ConnectionId.
    client *Client

    // Whether this connection has been initialized
    // with a client (above). Client may stil be nil.
    inited bool
}

type EphemId uint64
type ClientId uint64
type UserId string

type Client struct {
    // A unique ClientId. This is used as the
    // ephemeralId for the cluster operations.
    ClientId

    // The user string for identifying the Connection.
    // This will be passed in via a header.
    UserId

    // The number of active Connection objects
    // refering to this User object. The User
    // objects are reference counted and garbage
    // collected when all connections disconnect.
    refs int32
}

type Hub struct {
    // Our connection and conn maps.
    connections map[ConnectionId]*Connection
    clients     map[UserId]*Client
    nextid      uint64

    // Synchronization.
    sync.Mutex

    // The underlying cluster.
    // We maintain a reference to this so that
    // ephemeral nodes can be purged when all the
    // relevant connections have been dropped.
    *Cluster
}

func (c *Connection) Name(name string) string {
    if name != "" {
        return name
    }
    if c.client != nil {
        return string(c.client.UserId)
    }
    return string(c.addr)
}

func (c *Connection) EphemId() EphemId {
    if c.client != nil {
        return EphemId(c.client.ClientId)
    }
    return EphemId(c.ConnectionId)
}

func (c *Hub) genid() uint64 {
    return atomic.AddUint64(&c.nextid, 1)
}

func (c *Hub) NewConnection(addr string) *Connection {
    // Generate conn with no user, and
    // a straight-forward id. The user can
    // associate some conn-id with their
    // active connection during lookup.
    conn := &Connection{c, ConnectionId(c.genid()), addr, nil, false}

    c.Mutex.Lock()
    defer c.Mutex.Unlock()

    c.connections[conn.ConnectionId] = conn

    return conn
}

func (c *Hub) FindConnection(id ConnectionId, userid UserId) *Connection {
    c.Mutex.Lock()
    defer c.Mutex.Unlock()

    conn := c.connections[id]
    if conn == nil {
        return nil
    }
    if conn.inited {
        return conn
    }
    conn.inited = true

    // Create the user if it doesnt exist.
    // NOTE: There are some race conditions here between the
    // map lookup and reference increment / creation. These
    // should probably be fixed, but by my reckoning the current
    // outcome of these conditions will be some clients having
    // failed calls.
    if userid != "" {
        conn.client = c.clients[userid]
        if conn.client == nil {
            // Create and initialize a new user.
            conn.client = new(Client)
            conn.client.ClientId = ClientId(c.genid())
            conn.client.UserId = userid
            conn.client.refs = 1
            c.clients[userid] = conn.client
        } else {
            // Bump up the reference.
            conn.client.refs += 1
        }
    }

    return conn
}

func (c *Hub) DropConnection(conn *Connection) {
    c.Mutex.Lock()
    defer c.Mutex.Unlock()

    // Delete this connection.
    delete(c.connections, conn.ConnectionId)
    c.Cluster.Purge(EphemId(conn.ConnectionId))

    // Shuffle userid mappings.
    if conn.client != nil {
        conn.client.refs -= 1
        if conn.client.refs == 0 {
            // Remove the user from the map and
            // purge all related keys from the
            // underlying storage system.
            delete(c.clients, conn.client.UserId)
            c.Cluster.Purge(EphemId(conn.client.ClientId))
            conn.client = nil
        }
    }
}

func (c *Connection) Drop() {
    c.Hub.DropConnection(c)
}

func (c *Hub) dumpHub() {
    utils.Print("HUB", "HUB connections=%d clients=%d",
                len(c.connections), len(c.clients))
    for _, conn := range c.connections {
        var clid uint64
        if conn.client != nil {
            clid = uint64(conn.client.ClientId)
        } else {
            clid = uint64(0)
        }
        utils.Print("HUB", "CONNECTION id=%d addr=%s client=%d",
                    uint64(conn.ConnectionId), conn.addr, clid)
    }
    for _, client := range c.clients {
        utils.Print("HUB", "CLIENT id=%d userid=%s refs=%d",
                    uint64(client.ClientId), client.UserId, client.refs)
    }
}

func NewHub(cluster *Cluster) *Hub {
    hub := new(Hub)
    hub.connections = make(map[ConnectionId]*Connection)
    hub.clients = make(map[UserId]*Client)
    hub.Cluster = cluster
    return hub
}
