package service

import (
	"context"
	"io"
	"net"

	pb "github.com/z5labs/megamind/services/ingest/service/proto"

	"go.uber.org/zap"
	"google.golang.org/grpc"
)

// SubgraphIngester
type SubgraphIngester struct {
	pb.UnimplementedSubgraphIngestServer

	logger *zap.Logger
}

// New
func New(logger *zap.Logger) *SubgraphIngester {
	return &SubgraphIngester{
		logger: logger,
	}
}

// Serve instantiates the gRPC server and registers the SubgraphIngest service with it.
func (s *SubgraphIngester) Serve(ctx context.Context, ls net.Listener) error {
	grpcServer := grpc.NewServer()
	pb.RegisterSubgraphIngestServer(grpcServer, s)

	errCh := make(chan error, 1)
	go func() {
		defer close(errCh)
		err := grpcServer.Serve(ls)
		errCh <- err
	}()

	cctx, cancel := context.WithCancel(ctx)
	defer cancel()

	select {
	case <-cctx.Done():
		<-errCh
		return cctx.Err()
	case err := <-errCh:
		cancel()
		return err
	}
}

// Ingest
func (s *SubgraphIngester) Ingest(stream pb.SubgraphIngest_IngestServer) error {
	for {
		subgraph, err := stream.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}

		s.logger.Info(
			"received subgraph",
			zap.Int("num_of_triples", len(subgraph.Triples)),
		)
	}
}
