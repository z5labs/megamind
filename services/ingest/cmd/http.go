package cmd

import (
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var httpCmd = &cobra.Command{
	Use:   "http",
	Short: "Serve a RESTful API.",
	Run: func(cmd *cobra.Command, args []string) {
	},
}

func init() {
	serveCmd.AddCommand(httpCmd)

	// Flags
	grpcCmd.Flags().String("addr", "0.0.0.0:8080", "Address which the gRPC service will listen for connections.")

	viper.BindPFlag("addr", rootCmd.Flags().Lookup("addr"))
}
