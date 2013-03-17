package utils

import (
    "net"
    "fmt"
    "bytes"
    "strconv"
    "strings"
    "net/url"
)

func ParseAddr(addr string, defaultHost string, defaultPort uint) (string, uint) {
    idx := strings.LastIndex(addr, ":")
    port := defaultPort
    if idx >= 0 && idx+1 < len(addr) {
        parsed, err := strconv.ParseUint(addr[idx+1:len(addr)], 0, 32)
        if err != nil {
            port = defaultPort
        } else {
            port = uint(parsed)
        }
        addr = addr[0:idx]
    }
    if len(addr) == 0 {
        addr = defaultHost
    }
    return addr, port
}

func GenerateURL(addr string, defaultHost string, defaultPort uint) string {
    addr, port := ParseAddr(addr, defaultHost, defaultPort)
    return fmt.Sprintf("http://%s:%d", addr, port)
}

func GenerateUDPAddr(addr string, defaultHost string, defaultPort uint) (*net.UDPAddr, error) {
    addr, port := ParseAddr(addr, defaultHost, defaultPort)
    return net.ResolveUDPAddr("udp", fmt.Sprintf("%s:%d", addr, port))
}

func GenerateURLs(addrs string, defaultHost string, defaultPort uint) []string {
    raw := strings.Split(addrs, ",")
    urls := make([]string, len(raw), len(raw))
    for i, addr := range raw {
        urls[i] = GenerateURL(addr, defaultHost, defaultPort)
    }
    return urls
}

func AsURLs(a *net.UDPAddr) []string {
    res := make([]string, 1, 1)
    if a.IP.To4() != nil {
        res[0] = fmt.Sprintf("http://%s:%d", a.IP.To4().String(), a.Port)
    } else {
        res[0] = fmt.Sprintf("http://[%s]:%d", a.IP.String(), a.Port)
    }
    return res
}

func MakeURL(host string, path string, params map[string]string) string {
    addr := new(bytes.Buffer)
    if !strings.HasPrefix(host, "http://") {
        addr.WriteString("http://")
    }
    addr.WriteString(host)
    addr.WriteString(path)

    // Append all params.
    if params != nil {
        written := 0
        for key, value := range params {
            if written == 0 {
                addr.WriteString("?")
            } else {
                addr.WriteString("&")
            }
            addr.WriteString(url.QueryEscape(key))
            addr.WriteString("=")
            addr.WriteString(url.QueryEscape(value))
            written += 1
        }
    }

    return addr.String()
}