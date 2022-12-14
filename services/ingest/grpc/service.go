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
	"net"

	"github.com/z5labs/megamind/services/ingest/ingest"
	pb "github.com/z5labs/megamind/services/ingest/proto"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

var ErrServerStopped = grpc.ErrServerStopped

// Serve instantiates the gRPC server and registers the SubgraphIngest service with it.
func Serve(ctx context.Context, ls net.Listener, s *ingest.SubgraphIngester) error {
	grpcServer := grpc.NewServer(grpc.Creds(insecure.NewCredentials()))
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
		grpcServer.GracefulStop()
		<-errCh
		return ErrServerStopped
	case err := <-errCh:
		cancel()
		return err
	}
}
