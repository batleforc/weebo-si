package requestid

import (
	"bufio"
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"
)

var uuid = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)

func middleware(t *testing.T, next http.HandlerFunc) http.Handler {
	t.Helper()
	cfg := CreateConfig()
	cfg.TrustedIPs = []string{"10.244.0.0/16", "fd00:10:244::/56"}
	h, err := New(context.Background(), next, cfg, "requestid")
	if err != nil {
		t.Fatal(err)
	}
	return h
}

// run sends one request from `remote` carrying `sent` (if any) and returns the id the
// backend saw and the one the client got back.
func run(t *testing.T, remote string, sent ...string) (backend, response string) {
	t.Helper()
	h := middleware(t, func(w http.ResponseWriter, r *http.Request) {
		backend = r.Header.Get("X-Request-Id")
		if n := len(r.Header.Values("X-Request-Id")); n != 1 {
			t.Errorf("backend got %d X-Request-Id headers", n)
		}
		_, _ = w.Write([]byte("ok"))
	})
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = remote
	for _, v := range sent {
		req.Header.Add("X-Request-Id", v)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if n := len(rec.Header().Values("X-Request-Id")); n != 1 {
		t.Errorf("response has %d X-Request-Id headers", n)
	}
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

func TestBackendsOwnIDWins(t *testing.T) {
	h := middleware(t, func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Add("X-Request-Id", "rustfs-31f4")
		w.WriteHeader(http.StatusOK)
	})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if got := rec.Header().Values("X-Request-Id"); len(got) != 1 || got[0] != "rustfs-31f4" {
		t.Fatalf("response ids %q", got)
	}
}

func TestIDBeforeEarlyHintsIsNotFinal(t *testing.T) {
	h := middleware(t, func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusEarlyHints)
		w.Header().Set("X-Request-Id", "set-after-103")
		w.WriteHeader(http.StatusOK)
	})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if got := rec.Header().Values("X-Request-Id"); len(got) != 1 || got[0] != "set-after-103" {
		t.Fatalf("response ids %q", got)
	}
}

func TestStreamingFlushesThrough(t *testing.T) {
	h := middleware(t, func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("chunk"))
		if err := http.NewResponseController(w).Flush(); err != nil {
			t.Errorf("flush: %v", err)
		}
	})
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if !rec.Flushed || !uuid.MatchString(rec.Header().Get("X-Request-Id")) {
		t.Fatalf("flushed %v, id %q", rec.Flushed, rec.Header().Get("X-Request-Id"))
	}
}

// hijackable is a ResponseWriter that can be taken over, like Traefik's for an upgrade.
type hijackable struct {
	*httptest.ResponseRecorder
	hijacked bool
}

func (h *hijackable) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	h.hijacked = true
	return nil, nil, nil
}

func TestWebSocketUpgradeHijacksThrough(t *testing.T) {
	h := middleware(t, func(w http.ResponseWriter, _ *http.Request) {
		if _, _, err := http.NewResponseController(w).Hijack(); err != nil {
			t.Errorf("hijack: %v", err)
		}
	})
	w := &hijackable{ResponseRecorder: httptest.NewRecorder()}
	h.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/", nil))
	if !w.hijacked {
		t.Fatal("the upgrade did not reach the underlying writer")
	}
}
