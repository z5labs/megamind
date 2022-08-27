package cmd

import (
	"context"
	"os"
	"os/signal"
)

// Execute
func Execute(args ...string) {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	if len(args) == 0 {
		args = os.Args[1:]
	}
	rootCmd.SetArgs(args)
	err := rootCmd.ExecuteContext(ctx)
	if err != nil {
		os.Exit(1)
	}
}
