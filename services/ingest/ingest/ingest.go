package ingest

import (
	"context"
	"io"

	pb "github.com/z5labs/megamind/services/ingest/proto"
	"github.com/z5labs/megamind/subgraph"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// SubgraphIngester
type SubgraphIngester struct {
	pb.UnimplementedSubgraphIngestServer

	log *zap.Logger
}

// NewSubgraphIngester
func NewSubgraphIngester(l *zap.Logger) *SubgraphIngester {
	return &SubgraphIngester{
		log: l,
	}
}

// IngestSubgraph
func (s *SubgraphIngester) IngestSubgraph(ctx context.Context, g *subgraph.Subgraph) (*pb.IngestResponse, error) {
	err := s.publish(ctx, g)
	return new(pb.IngestResponse), err
}

// Ingest
func (s *SubgraphIngester) Ingest(stream pb.SubgraphIngest_IngestServer) error {
	for {
		g, err := stream.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		s.log.Info(
			"received subgraph",
			withSubgraphStats(g)...,
		)

		go func() {
			err := s.publish(context.Background(), g)
			if err != nil {
				s.log.Error(
					"unexpected error when publishing subgraph",
					zap.Error(err),
					withNumOfTriples(g),
					withNumOfDistinctSubjects(g),
				)
			}
		}()
	}
}

func (s *SubgraphIngester) publish(ctx context.Context, g *subgraph.Subgraph) error {
	defer s.log.Info("published subgraph", withSubgraphStats(g)...)
	s.log.Info("publishing subgraph", withSubgraphStats(g)...)
	return nil
}

func withSubgraphStats(g *subgraph.Subgraph) []zapcore.Field {
	return []zapcore.Field{
		withNumOfTriples(g),
		withNumOfDistinctSubjects(g),
	}
}

func withNumOfTriples(g *subgraph.Subgraph) zapcore.Field {
	return zap.Int("num_of_triples", len(g.Triples))
}

func withNumOfDistinctSubjects(g *subgraph.Subgraph) zapcore.Field {
	return zap.Int("num_of_distinct_subjects", countDistinctSubjects(g))
}

func countDistinctSubjects(g *subgraph.Subgraph) int {
	m := make(map[string]struct{}, 2*len(g.Triples))
	for _, triple := range g.Triples {
		subj := triple.Subject
		sid := subj.Type + subj.Tuid
		if _, exists := m[sid]; !exists {
			m[sid] = struct{}{}
		}

		object := triple.GetObject()
		val, ok := object.Value.(*subgraph.Object_Subject)
		if !ok {
			continue
		}
		subj = val.Subject
		if _, exists := m[sid]; !exists {
			m[sid] = struct{}{}
		}
	}
	return len(m)
}
