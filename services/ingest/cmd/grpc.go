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

package cmd

import (
	"net"

	"github.com/z5labs/megamind/services/ingest/grpc"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

var grpcCmd = &cobra.Command{
	Use:   "grpc",
	Short: "Serve requests over gRPC",
	Run: func(cmd *cobra.Command, args []string) {
		grpcAddr := viper.GetString("grpc-addr")
		ls, err := net.Listen("tcp", grpcAddr)
		if err != nil {
			zap.L().Fatal(
				"unexpected error when trying to listen on address",
				zap.String("grpc_addr", grpcAddr),
				zap.Error(err),
			)
			return
		}
		zap.L().Info("listening for grpc requests", zap.String("grpc_addr", grpcAddr))

		s := grpc.NewSubgraphIngester(zap.L().Named("service"))
		err = s.Serve(cmd.Context(), ls)
		if err != nil {
			zap.L().Fatal(
				"unexpected error when serving grpc traffic",
				zap.String("grpc_addr", grpcAddr),
				zap.Error(err),
			)
			return
		}
	},
}

func init() {
	serveCmd.AddCommand(grpcCmd)

	// Flags
	grpcCmd.Flags().String("addr", "0.0.0.0:8080", "Address which the gRPC service will listen for connections.")

	viper.BindPFlag("addr", rootCmd.Flags().Lookup("addr"))
}
