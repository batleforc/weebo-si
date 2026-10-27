package requestid

import (
	"context"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"
)

var uuid = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)

// run sends one request from `remote` carrying `sent` (if any) and returns the id the
// backend saw and the one the client got back.
func run(t *testing.T, remote string, sent ...string) (backend, response string) {
	t.Helper()
	cfg := CreateConfig()
	cfg.TrustedIPs = []string{"10.244.0.0/16", "fd00:10:244::/56"}
	h, err := New(context.Background(), http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		backend = r.Header.Get("X-Request-Id")
		if n := len(r.Header.Values("X-Request-Id")); n != 1 {
			t.Errorf("backend got %d X-Request-Id headers", n)
		}
	}), cfg, "requestid")
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = remote
	for _, v := range sent {
		req.Header.Add("X-Request-Id", v)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return backend, rec.Header().Get("X-Request-Id")
}

func TestGeneratesWhenMissing(t *testing.T) {
	b, r := run(t, "203.0.113.7:4242")
	if !uuid.MatchString(b) || b != r {
		t.Fatalf("backend %q, response %q", b, r)
	}
}

func TestTrustedProxyKeepsItsID(t *testing.T) {
	for _, remote := range []string{"10.244.3.9:5000", "[fd00:10:244::12]:5000"} {
		if b, r := run(t, remote, "edge-7f3a:01"); b != "edge-7f3a:01" || r != b {
			t.Fatalf("%s: backend %q, response %q", remote, b, r)
		}
	}
}

func TestUntrustedClientCannotChooseIt(t *testing.T) {
	b, _ := run(t, "203.0.113.7:4242", "i-picked-this")
	if b == "i-picked-this" || !uuid.MatchString(b) {
		t.Fatalf("backend %q", b)
	}
}

func TestTrustedButMalformedIsReplaced(t *testing.T) {
	for _, sent := range []string{"<script>", "a b", string(make([]byte, 129))} {
		if b, _ := run(t, "10.244.0.1:1", sent); !uuid.MatchString(b) {
			t.Fatalf("%q: backend %q", sent, b)
		}
	}
}

func TestDuplicatesCollapseToOne(t *testing.T) {
	run(t, "203.0.113.7:4242", "a", "b") // the backend check counts the headers
}

func TestBadCIDRFailsAtLoad(t *testing.T) {
	cfg := CreateConfig()
	cfg.TrustedIPs = []string{"not-a-cidr"}
	if _, err := New(context.Background(), http.NotFoundHandler(), cfg, "requestid"); err == nil {
		t.Fatal("expected an error")
	}
}
