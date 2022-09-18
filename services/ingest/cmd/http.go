package cmd

import (
	"errors"
	"net"

	"github.com/z5labs/megamind/services/ingest/http"
	"github.com/z5labs/megamind/services/ingest/ingest"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"go.uber.org/zap"
)

var httpCmd = &cobra.Command{
	Use:   "http",
	Short: "Serve a RESTful API.",
	Run: func(cmd *cobra.Command, args []string) {
		addr := viper.GetString("addr")
		ls, err := net.Listen("tcp", addr)
		if err != nil {
			zap.L().Fatal(
				"unexpected error when trying to listen on address",
				zap.String("addr", addr),
				zap.Error(err),
			)
			return
		}
		zap.L().Info("listening for http requests", zap.String("addr", addr))

		s := http.NewSubgraphIngester(zap.L(), ingest.NewSubgraphIngester(zap.L()))
		err = s.Serve(cmd.Context(), ls)
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			zap.L().Fatal(
				"unexpected error when serving http traffic",
				zap.String("addr", addr),
				zap.Error(err),
			)
			return
		}
	},
}

func init() {
	serveCmd.AddCommand(httpCmd)
}
