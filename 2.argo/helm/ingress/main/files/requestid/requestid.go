// Package requestid gives every request an X-Request-Id. A request keeps the one it
// arrived with only when the sender is a trusted proxy and the value looks like an id;
// anyone else gets a fresh one, so a client cannot pick the id its request is logged
// under. The id is set on the request (backends, access log, error pages) and on the
// response (the client can quote it).
//
// Traefik runs this through its Yaegi interpreter: standard library only.
package requestid

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"net/http"
)

// Config is the Middleware's `spec.plugin.requestid` block.
type Config struct {
	HeaderName string   `json:"headerName,omitempty"`
	TrustedIPs []string `json:"trustedIPs,omitempty"`
}

// CreateConfig returns the defaults Traefik fills the Middleware's settings into.
func CreateConfig() *Config {
	return &Config{HeaderName: "X-Request-Id"}
}

type requestID struct {
	next    http.Handler
	header  string
	trusted []*net.IPNet
}

// New builds the middleware; a bad CIDR fails it at load time rather than per request.
func New(_ context.Context, next http.Handler, config *Config, _ string) (http.Handler, error) {
	if config.HeaderName == "" {
		return nil, fmt.Errorf("requestid: headerName is empty")
	}
	r := &requestID{next: next, header: http.CanonicalHeaderKey(config.HeaderName)}
	for _, cidr := range config.TrustedIPs {
		_, n, err := net.ParseCIDR(cidr)
		if err != nil {
			return nil, fmt.Errorf("requestid: trustedIPs: %w", err)
		}
		r.trusted = append(r.trusted, n)
	}
	return r, nil
}

func (r *requestID) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	id := req.Header.Get(r.header)
	if !r.fromTrusted(req.RemoteAddr) || !valid(id) {
		id = newID()
	}
	if id == "" {
		// No randomness to be had: drop the untrusted value rather than pass it on.
		req.Header.Del(r.header)
	} else {
		req.Header.Set(r.header, id)
		rw.Header().Set(r.header, id)
	}
	r.next.ServeHTTP(rw, req)
}

// fromTrusted checks the peer address itself: X-Forwarded-For is the client's to write.
func (r *requestID) fromTrusted(remoteAddr string) bool {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		host = remoteAddr
	}
	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}
	for _, n := range r.trusted {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

// valid keeps ids that are safe to log and to show on a page: 1-128 characters,
// letters, digits and . _ : - only.
func valid(id string) bool {
	if id == "" || len(id) > 128 {
		return false
	}
	for i := 0; i < len(id); i++ {
		c := id[i]
		ok := c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' ||
			c == '.' || c == '_' || c == ':' || c == '-'
		if !ok {
			return false
		}
	}
	return true
}

// newID returns a random UUIDv4, or "" if the system has no randomness to give.
func newID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return ""
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b[:])
	return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:32]
}
