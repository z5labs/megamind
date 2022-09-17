package http

import (
	"context"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"

	"github.com/z5labs/megamind/services/ingest/ingest"
)

func newSubgraphIngester(ctx context.Context, logger *zap.Logger) (net.Addr, <-chan error) {
	errCh := make(chan error, 1)
	ls, err := net.Listen("tcp", ":0")
	if err != nil {
		errCh <- err
		return nil, errCh
	}

	s := NewSubgraphIngester(logger, ingest.NewSubgraphIngester(logger))
	go func() {
		defer close(errCh)
		err := s.Serve(ctx, ls)
		errCh <- err
	}()

	return ls.Addr(), errCh
}

func TestSubgraphIngester(t *testing.T) {
	t.Run("should shutdown when context is cancelled", func(subT *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		addr, errCh := newSubgraphIngester(ctx, zap.L())
		if !assert.NotNil(subT, addr) {
			subT.Error(<-errCh)
			return
		}
		cancel()

		err := <-errCh
		if !assert.Equal(subT, http.ErrServerClosed, err) {
			return
		}
	})

	t.Run("should return bad request if missing content type header", func(subT *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		addr, errCh := newSubgraphIngester(ctx, zap.L())
		if !assert.NotNil(subT, addr) {
			subT.Error(<-errCh)
			return
		}

		endpoint := "http://" + addr.String() + "/subgraph/ingest"
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(`{}`))
		if !assert.Nil(subT, err) {
			return
		}

		resp, err := http.DefaultClient.Do(req)
		if !assert.Nil(subT, err) {
			return
		}
		if !assert.Equal(subT, http.StatusBadRequest, resp.StatusCode) {
			return
		}
	})

	t.Run("should return bad request if subgraph is malformed", func(subT *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		addr, errCh := newSubgraphIngester(ctx, zap.L())
		if !assert.NotNil(subT, addr) {
			subT.Error(<-errCh)
			return
		}

		endpoint := "http://" + addr.String() + "/subgraph/ingest"
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(`invalid json`))
		if !assert.Nil(subT, err) {
			return
		}
		req.Header.Set("Content-Type", "application/json")

		resp, err := http.DefaultClient.Do(req)
		if !assert.Nil(subT, err) {
			return
		}
		if !assert.Equal(subT, http.StatusBadRequest, resp.StatusCode) {
			return
		}
	})
}
