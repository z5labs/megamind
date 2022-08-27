package cmd

import (
	"net"

	"github.com/z5labs/megamind/services/ingest/service"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type logLevel zapcore.Level

func (l logLevel) String() string {
	return (zapcore.Level)(l).String()
}

func (l *logLevel) Set(s string) error {
	return (*zapcore.Level)(l).Set(s)
}

func (l logLevel) Type() string {
	return "Level"
}

var rootCmd = &cobra.Command{
	Use:   "subgraph-ingester",
	Short: "",
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		var lvl zapcore.Level
		lvlStr := cmd.Flags().Lookup("log-level").Value.String()
		err := lvl.UnmarshalText([]byte(lvlStr))
		if err != nil {
			panic(err)
		}

		cfg := zap.NewProductionConfig()
		cfg.Level = zap.NewAtomicLevelAt(zapcore.DebugLevel)
		cfg.OutputPaths = []string{viper.GetString("log-file")}
		l, err := cfg.Build(zap.IncreaseLevel(lvl))
		if err != nil {
			panic(err)
		}

		zap.ReplaceGlobals(l)
	},
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

		s := service.New(zap.L().Named("service"))
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
	// Persistent flags
	lvl := logLevel(zapcore.InfoLevel)
	rootCmd.PersistentFlags().Var(&lvl, "log-level", "Specify log level")
	rootCmd.PersistentFlags().String("log-file", "stderr", "Specify log file")

	viper.BindPFlag("log-file", rootCmd.PersistentFlags().Lookup("log-file"))

	// Flags
	rootCmd.Flags().String("grpc-addr", "0.0.0.0:8080", "Address which the gRPC will listen for requests.")

	viper.BindPFlag("grpc-addr", rootCmd.Flags().Lookup("grpc-addr"))
}
