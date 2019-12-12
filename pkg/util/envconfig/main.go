package main

import (
	"os"

	"fmt"
	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	ManualOverride1         string `envconfig:"manual_override_1"`
	DefaultVar              string `default:"foobar"`
	RequiredVar             string `required:"true"`
	IgnoredVar              string `ignored:"true"`
	AutoSplitVar            string `split_words:"true"`
	RequiredAndAutoSplitVar string `required:"true" split_words:"true"`
	Slice                   []string
	Map                     map[string]int
}

func main() {
	// prepare
	os.Setenv("MYAPP_MANUAL_OVERRIDE_1", "manual")
	os.Setenv("MYAPP_DEFAULTVAR", "default")
	os.Setenv("MYAPP_REQUIREDVAR", "require")
	os.Setenv("MYAPP_IGNOREDVAR", "ignore")
	os.Setenv("MYAPP_AUTO_SPLIT_VAR", "split")
	os.Setenv("MYAPP_REQUIRED_AND_AUTO_SPLIT_VAR", "require_and_split")
	os.Setenv("MYAPP_SLICE", "rob,ken,robert")
	os.Setenv("MYAPP_MAP", "red:1,green:2,blue:3")

	// parse
	var config Config
	err := envconfig.Process("myapp", &config)
	if err != nil {
		fmt.Println("process config error : ", config)
		os.Exit(0)
	}

	// print
	fmt.Println(config.ManualOverride1)
	fmt.Println(config.DefaultVar)
	fmt.Println(config.RequiredVar)
	fmt.Println(config.IgnoredVar)
	fmt.Println(config.AutoSplitVar)
	fmt.Println(config.RequiredAndAutoSplitVar)
	fmt.Println(config.Slice)
	fmt.Println(config.Map)
}
