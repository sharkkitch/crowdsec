package main

import (
	"fmt"
	"os"

	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"

	"github.com/crowdsecurity/crowdsec/pkg/csconfig"
	"github.com/crowdsecurity/crowdsec/pkg/cwhub"
	"github.com/crowdsecurity/crowdsec/pkg/database"
)

// Variables set at build time via ldflags
var (
	Version   = "dev"
	BuildDate = "unknown"
	Commit    = "unknown"
)

// CrowdSec is the main application struct holding global state.
type CrowdSec struct {
	cfg      *csconfig.GlobalConfig
	hub      *cwhub.Hub
	db       *database.Client
}

func newRootCmd() *cobra.Command {
	var (
		configFile string
		debug      bool
		trace      bool
		info       bool
	)

	rootCmd := &cobra.Command{
		Use:   "crowdsec",
		Short: "CrowdSec - the open-source & collaborative security engine",
		Long: `CrowdSec is a security automation tool that detects and blocks
aggressive behaviors based on log analysis and crowd-sourced IP reputation.`,
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			switch {
			case trace:
				log.SetLevel(log.TraceLevel)
			case debug:
				log.SetLevel(log.DebugLevel)
			case info:
				log.SetLevel(log.InfoLevel)
			default:
				// Default to debug level for easier local development/troubleshooting
				log.SetLevel(log.DebugLevel)
			}
			return nil
		},
	}

	// Default config path changed to match my local dev setup
	rootCmd.PersistentFlags().StringVarP(&configFile, "config", "c", "./config/config.yaml", "path to crowdsec config file")
	rootCmd.PersistentFlags().BoolVar(&debug, "debug", false, "set log level to debug")
	rootCmd.PersistentFlags().BoolVar(&trace, "trace", false, "set log level to trace")
	rootCmd.PersistentFlags().BoolVar(&info, "info", false, "set log level to info")

	// version subcommand
	versionCmd := &cobra.Command{
		Use:   "version",
		Short: "Display version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("version: %s\nbuild date: %s\ncommit: %s\n",
				Version, BuildDate, Commit)
		},
	}

	// run subcommand — starts the crowdsec agent
	runCmd := &cobra.Command{
		Use:   "run",
		Short: "Start the CrowdSec agent",
		RunE: func(cmd *cobra.Command, args []string) error {
			return runCrowdSec(configFile)
		},
	}

	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(runCmd)

	// Default action when no subcommand is provided is to run the agent.
	rootCmd.RunE = func(cmd *cobra.Command, args []string) error {
		return runCrowdSec(configFile)
	}

	return rootCmd
}

// runCrowdSec loads configuration and starts the main agent loop.
func runCrowdSec(configFile string) error {
	log.Infof("Starting CrowdSec %s (commit: %s)", Version, Commit)

	cfg, err := csconfig.NewConfig(configFile, false, false, false)
	if err != nil {
		return fmt.Errorf("failed to load configuration: %w", err)
	}

	if err := cfg.LoadAPIServer(false); err != nil {
		return fmt.Errorf("failed to load API server config: %w", err)
	}

	if err := cfg.LoadCrowdsec(); err != nil {
		return fmt.Errorf("failed to load crowdsec config: %w", err)
	}

	log.Info("Configuration loaded successfully")

	// TODO: initialise hub, database, acquisition, parser
