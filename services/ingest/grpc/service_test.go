/*
 * Copyright 2022 Z5Labs and Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package grpc

import (
	"context"
	"io"
	"net"
	"testing"
	"time"

	"github.com/z5labs/megamind/services/ingest/ingest"
	pb "github.com/z5labs/megamind/services/ingest/proto"
	"github.com/z5labs/megamind/subgraph"

	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func newSubgraphIngester(ctx context.Context, logger *zap.Logger) (net.Addr, <-chan error) {
	errCh := make(chan error, 1)
	ls, err := net.Listen("tcp", ":0")
	if err != nil {
		errCh <- err
		return nil, errCh
	}

	s := ingest.NewSubgraphIngester(logger)
	go func() {
		defer close(errCh)
		err := Serve(ctx, ls, s)
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
			return
		}
		cancel()

		err := <-errCh
		if !assert.Equal(subT, ErrServerStopped, err) {
			return
		}
	})

	t.Run("should be able to stream and then close", func(subT *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		addr, errCh := newSubgraphIngester(ctx, zap.L())
		if !assert.NotNil(subT, addr) {
			return
		}

		cc, err := grpc.Dial(addr.String(), grpc.WithTransportCredentials(insecure.NewCredentials()))
		if !assert.Nil(subT, err) {
			return
		}
		client := pb.NewSubgraphIngestClient(cc)

		stream, err := client.Ingest(ctx)
		if !assert.Nil(subT, err) {
			return
		}
		err = stream.Send(&subgraph.Subgraph{
			Triples: []*subgraph.Triple{
				{
					Subject: &subgraph.Subject{
						Type: "Person",
						Tuid: "1",
					},
					Predicate: &subgraph.Predicate{
						Name: "name",
					},
					Object: &subgraph.Object{
						Value: &subgraph.Object_String_{
							String_: "Bob",
						},
					},
				},
			},
		})
		if !assert.Nil(subT, err) {
			return
		}
		_, err = stream.CloseAndRecv()
		if !assert.Equal(subT, io.EOF, err) {
			return
		}
		cancel()

		err = <-errCh
		if !assert.Equal(subT, ErrServerStopped, err) {
			return
		}
	})
}
