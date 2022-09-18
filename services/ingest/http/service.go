package http

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"time"

	"github.com/z5labs/megamind/services/ingest/ingest"
	"github.com/z5labs/megamind/subgraph"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

var ErrServerClosed = http.ErrServerClosed

type SubgraphIngester struct {
	log *zap.Logger

	ingester *ingest.SubgraphIngester
}

func NewSubgraphIngester(log *zap.Logger, s *ingest.SubgraphIngester) *SubgraphIngester {
	return &SubgraphIngester{
		log:      log,
		ingester: s,
	}
}

func (s *SubgraphIngester) Serve(ctx context.Context, ls net.Listener) error {
	r := gin.New()
	r.Use(logger(s.log))
	r.POST("/subgraph/ingest", s.ingest)

	srv := &http.Server{
		Handler: r,
	}

	// Run http server in goroutine
	sctx, cancel := context.WithCancel(ctx)
	doneCh := make(chan struct{}, 1)
	go func() {
		defer cancel()
		defer close(doneCh)

		err := srv.Serve(ls)
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			s.log.Error("unexpected error from http server", zap.Error(err))
		}
	}()

	// Wait for http server to crash or some outside force
	// saying its time to shutdown
	<-sctx.Done()

	// Gracefully shutdown http server
	shutCtx, shutCancel := context.WithTimeout(context.Background(), 1*time.Minute)
	defer shutCancel()

	err := srv.Shutdown(shutCtx)
	if errors.Is(err, context.Canceled) {
		s.log.Warn("shutdown timed out before all connections could be closed")
		return nil
	}
	if err != nil {
		s.log.Error("unexpected error when shutting http server down", zap.Error(err))
		return err
	}

	// wait for http server goroutine teardown
	<-doneCh
	return ErrServerClosed
}

type protoJsonBinding struct{}

func (b protoJsonBinding) Name() string { return "protoJsonBinding" }

func (b protoJsonBinding) Bind(req *http.Request, v any) error {
	contentType := req.Header.Get("Content-Type")
	if contentType != "application/json" {
		return errors.New("content-type must be application/json")
	}

	m, ok := v.(proto.Message)
	if !ok {
		panic("can only unmarshal request body into a protocol buffer message type")
	}

	bs, err := readAllAndClose(req.Body)
	if err != nil {
		return err
	}
	return protojson.Unmarshal(bs, m)
}

var protoJSON = protoJsonBinding{}

func (s *SubgraphIngester) ingest(c *gin.Context) {
	var subgraph subgraph.Subgraph
	err := c.MustBindWith(&subgraph, protoJSON)
	if err != nil {
		s.log.Error("unexpected error when unmarshalling request body", zap.Error(err))
		return
	}

	_, err = s.ingester.IngestSubgraph(c, &subgraph)
	if err != nil {
		c.Status(http.StatusInternalServerError)
		return
	}
}

func logger(log *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		log.Info("received request")

		c.Next()

		log.Info("sent response", zap.Int("status", c.Writer.Status()))
	}
}

func readAllAndClose(rc io.ReadCloser) ([]byte, error) {
	defer rc.Close()

	return io.ReadAll(rc)
}
