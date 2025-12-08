// Package helpers provides test utilities and generators for property-based testing
package helpers

import (
	"fmt"
	"math/rand"
	"time"
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

// ValidEnvironments returns all valid environment values
func ValidEnvironments() []string {
	return []string{"develop", "test", "qa", "prod"}
}

// RandomEnvironment returns a random valid environment
func RandomEnvironment() string {
	envs := ValidEnvironments()
	return envs[rand.Intn(len(envs))]
}

// RandomProjectName generates a random valid project name
func RandomProjectName() string {
	prefixes := []string{"app", "svc", "api", "web", "data"}
	suffixes := []string{"service", "platform", "system", "core", "hub"}
	return fmt.Sprintf("%s-%s-%d", prefixes[rand.Intn(len(prefixes))], suffixes[rand.Intn(len(suffixes))], rand.Intn(100))
}

// ValidVPCCIDRs returns a list of valid VPC CIDR blocks
func ValidVPCCIDRs() []string {
	return []string{
		"10.0.0.0/16",
		"10.1.0.0/16",
		"10.2.0.0/16",
		"172.16.0.0/16",
		"172.17.0.0/16",
		"192.168.0.0/16",
	}
}

// RandomVPCCIDR returns a random valid VPC CIDR
func RandomVPCCIDR() string {
	cidrs := ValidVPCCIDRs()
	return cidrs[rand.Intn(len(cidrs))]
}

// ValidAZConfigurations returns valid availability zone configurations
func ValidAZConfigurations() [][]string {
	return [][]string{
		{"us-east-1a", "us-east-1b"},
		{"us-east-1a", "us-east-1b", "us-east-1c"},
		{"us-west-2a", "us-west-2b", "us-west-2c"},
		{"eu-west-1a", "eu-west-1b", "eu-west-1c"},
	}
}

// RandomAZConfiguration returns a random valid AZ configuration
func RandomAZConfiguration() []string {
	azs := ValidAZConfigurations()
	return azs[rand.Intn(len(azs))]
}
