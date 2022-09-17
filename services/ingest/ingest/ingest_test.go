package ingest

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/z5labs/megamind/subgraph"
)

func TestCountDistinctSubjects(t *testing.T) {
	t.Run("should return zero for nil triples list", func(subT *testing.T) {
		g := &subgraph.Subgraph{}

		numOfSubjects := countDistinctSubjects(g)
		if !assert.Equal(subT, 0, numOfSubjects) {
			return
		}
	})
}
