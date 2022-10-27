// Copyright 2022 Z5Labs and Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cmd

import (
	"bufio"
	"context"
	"io"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/z5labs/megamind/subgraph"
	"golang.org/x/sync/errgroup"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

var dgraphIngestSubgraphCmd = &cobra.Command{
	Use:     "subgraphs -|FILE",
	Aliases: []string{"subgraph"},
	Short:   "Ingest subgraphs directly to Dgraph",
	Args:    cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		var unmarshal unmarshaler
		encoding := getEncoding()
		switch encoding {
		case "json":
			unmarshal = unmarshalJSON
		case "proto":
			unmarshal = unmarshalProto
		default:
			zap.L().Fatal("unsupported encoding", zap.String("encoding", encoding))
		}

		// Ingest subgraphs
		tripleCh := make(chan *subgraph.Triple)
		g1, g1ctx := errgroup.WithContext(cmd.Context())
		g1.Go(readSubgraphs(g1ctx, args[0], unmarshal, tripleCh))
		g1.Go(mergeSubgraphs(g1ctx, tripleCh))

		// Wait and log runtime stats
		g2, g2ctx := errgroup.WithContext(g1ctx)
		g2.Go(g1.Wait)
		g2.Go(func() error {
			for {
				select {
				case <-g1ctx.Done():
					return nil
				case <-g2ctx.Done():
					return nil
				case <-time.After(1 * time.Second):
				}

				var memStats runtime.MemStats
				runtime.ReadMemStats(&memStats)

				zap.L().Debug(
					"runtime stats",
					zap.Int("num_of_goroutines", runtime.NumGoroutine()),
					zap.Uint64("heap_alloc_bytes", memStats.HeapAlloc),
					zap.Uint64("total_alloc_bytes", memStats.TotalAlloc),
				)
			}
		})

		// Wait for everything to complete
		err := g2.Wait()
		if err != nil {
			zap.L().Fatal("unexpected error", zap.Error(err))
		}
	},
}

func init() {
	dgraphIngestCmd.AddCommand(dgraphIngestSubgraphCmd)

	dgraphIngestSubgraphCmd.Flags().String("encoding", "json", "Subgraph encoding")

	viper.BindPFlag("encoding", dgraphIngestSubgraphCmd.Flags().Lookup("encoding"))
}

func getEncoding() string {
	return strings.ToLower(
		strings.TrimSpace(
			viper.GetString("encoding"),
		),
	)
}

type unmarshaler func([]byte, any) error

func unmarshalJSON(b []byte, v any) error {
	return protojson.Unmarshal(b, v.(proto.Message))
}

func unmarshalProto(b []byte, v any) error {
	return proto.Unmarshal(b, v.(proto.Message))
}

func readSubgraphs(ctx context.Context, filename string, unmarshal unmarshaler, tripleCh chan<- *subgraph.Triple) func() error {
	g, gctx := errgroup.WithContext(ctx)
	return func() (err error) {
		defer close(tripleCh)
		defer g.Wait()

		zap.L().Info("opening source", zap.String("filename", filename))
		f, err := openSource(filename)
		if err != nil {
			zap.L().Error("failed to open source", zap.Error(err))
			return err
		}
		defer f.Close()
		zap.L().Info("opened source", zap.String("filename", filename))

		zap.L().Info("reading subgraphs from source", zap.String("filename", filename))
		i := 0
		br := bufio.NewReader(f)
		for {
			select {
			case <-gctx.Done():
				return nil
			default:
			}

			line, _, err := br.ReadLine()
			if err == io.EOF {
				zap.L().Info("read subgraphs from source", zap.String("filename", filename), zap.Int("num_of_subgraphs", i))
				return nil
			}
			if err != nil {
				return err
			}

			var sg subgraph.Subgraph
			err = unmarshal(line, &sg)
			if err != nil {
				return err
			}
			i += 1

			g.Go(func() error {
				for _, t := range sg.Triples {
					select {
					case <-gctx.Done():
					case tripleCh <- t:
					}
				}
				return nil
			})
		}
	}
}

func mergeSubgraphs(ctx context.Context, tripleCh <-chan *subgraph.Triple) func() error {
	return func() error {
		zap.L().Info("merging subgraphs")

		i := 0
		for {
			select {
			case <-ctx.Done():
				return nil
			case t := <-tripleCh:
				if t == nil {
					zap.L().Info("merged subgraphs", zap.Int("num_of_triples", i))
					return nil
				}
				i += 1
			}
		}
	}
}

func openSource(filename string) (*os.File, error) {
	filename = strings.TrimSpace(filename)
	if filename == "-" {
		return os.Stdin, nil
	}

	return os.Open(filename)
}
