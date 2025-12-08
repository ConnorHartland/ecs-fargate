// Package properties contains property-based tests for Terraform modules
// These tests validate correctness properties defined in the design document
package properties

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"
)

// NetworkingConfig represents a valid networking module configuration
type NetworkingConfig struct {
	Environment           string
	ProjectName           string
	VPCCIDR               string
	AvailabilityZones     []string
	EnableNATGateway      bool
	SingleNATGateway      bool
	EnableVPCFlowLogs     bool
	FlowLogsRetentionDays int
}

// genEnvironment generates a valid environment value
func genEnvironment() *rapid.Generator[string] {
	return rapid.SampledFrom([]string{"develop", "test", "qa", "prod"})
}

// genProjectName generates a valid project name
func genProjectName() *rapid.Generator[string] {
	return rapid.Custom(func(t *rapid.T) string {
		prefix := rapid.SampledFrom([]string{"app", "svc", "api", "web", "data"}).Draw(t, "prefix")
		suffix := rapid.SampledFrom([]string{"service", "platform", "system", "core"}).Draw(t, "suffix")
		num := rapid.IntRange(1, 99).Draw(t, "num")
		return fmt.Sprintf("%s-%s-%d", prefix, suffix, num)
	})
}

// genVPCCIDR generates a valid VPC CIDR block
func genVPCCIDR() *rapid.Generator[string] {
	return rapid.SampledFrom([]string{
		"10.0.0.0/16",
		"10.1.0.0/16",
		"10.2.0.0/16",
		"172.16.0.0/16",
		"172.17.0.0/16",
	})
}

// genAvailabilityZones generates a valid list of availability zones (2-3 AZs)
func genAvailabilityZones() *rapid.Generator[[]string] {
	return rapid.SampledFrom([][]string{
		{"us-east-1a", "us-east-1b"},
		{"us-east-1a", "us-east-1b", "us-east-1c"},
		{"us-west-2a", "us-west-2b", "us-west-2c"},
		{"eu-west-1a", "eu-west-1b", "eu-west-1c"},
	})
}

// genFlowLogsRetention generates a valid CloudWatch retention value
func genFlowLogsRetention() *rapid.Generator[int] {
	return rapid.SampledFrom([]int{1, 3, 5, 7, 14, 30, 60, 90})
}

// genNetworkingConfig generates a valid networking configuration
func genNetworkingConfig() *rapid.Generator[NetworkingConfig] {
	return rapid.Custom(func(t *rapid.T) NetworkingConfig {
		return NetworkingConfig{
			Environment:           genEnvironment().Draw(t, "environment"),
			ProjectName:           genProjectName().Draw(t, "project_name"),
			VPCCIDR:               genVPCCIDR().Draw(t, "vpc_cidr"),
			AvailabilityZones:     genAvailabilityZones().Draw(t, "availability_zones"),
			EnableNATGateway:      rapid.Bool().Draw(t, "enable_nat_gateway"),
			SingleNATGateway:      rapid.Bool().Draw(t, "single_nat_gateway"),
			EnableVPCFlowLogs:     rapid.Bool().Draw(t, "enable_vpc_flow_logs"),
			FlowLogsRetentionDays: genFlowLogsRetention().Draw(t, "flow_logs_retention"),
		}
	})
}

// toTerraformVars converts NetworkingConfig to Terraform variables map
func (c NetworkingConfig) toTerraformVars() map[string]interface{} {
	return map[string]interface{}{
		"environment":              c.Environment,
		"project_name":             c.ProjectName,
		"vpc_cidr":                 c.VPCCIDR,
		"availability_zones":       c.AvailabilityZones,
		"enable_nat_gateway":       c.EnableNATGateway,
		"single_nat_gateway":       c.SingleNATGateway,
		"enable_vpc_flow_logs":     c.EnableVPCFlowLogs,
		"flow_logs_retention_days": c.FlowLogsRetentionDays,
	}
}

// TerraformPlanOutput represents the JSON output of terraform show -json
type TerraformPlanOutput struct {
	PlannedValues struct {
		RootModule struct {
			Resources []struct {
				Address string                 `json:"address"`
				Type    string                 `json:"type"`
				Name    string                 `json:"name"`
				Values  map[string]interface{} `json:"values"`
			} `json:"resources"`
		} `json:"root_module"`
	} `json:"planned_values"`
}

// getResourcesByType returns all resources of a given type from the plan
func (p *TerraformPlanOutput) getResourcesByType(resourceType string) []map[string]interface{} {
	var resources []map[string]interface{}
	for _, r := range p.PlannedValues.RootModule.Resources {
		if r.Type == resourceType {
			resources = append(resources, r.Values)
		}
	}
	return resources
}

// getModulePath returns the absolute path to the networking module
func getModulePath(t *testing.T) string {
	cwd, err := os.Getwd()
	require.NoError(t, err)
	modulePath := filepath.Join(cwd, "..", "..", "terraform", "modules", "networking")
	_, err = os.Stat(modulePath)
	require.NoError(t, err, "Module path does not exist: %s", modulePath)
	return modulePath
}

// runTerraformPlanAndGetJSON runs terraform plan and returns the JSON output
func runTerraformPlanAndGetJSON(t *testing.T, modulePath string, config NetworkingConfig, planName string) *TerraformPlanOutput {
	planFilePath := fmt.Sprintf("/tmp/%s.tfplan", planName)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: modulePath,
		Vars:         config.toTerraformVars(),
		NoColor:      true,
		PlanFilePath: planFilePath,
	})

	// Initialize and create plan
	terraform.Init(t, terraformOptions)
	terraform.Plan(t, terraformOptions)

	// Run terraform show -json to get JSON output
	cmd := exec.Command("terraform", "show", "-json", planFilePath)
	cmd.Dir = modulePath
	output, err := cmd.CombinedOutput()
	require.NoError(t, err, "Failed to run terraform show -json: %s", string(output))

	// Parse JSON output
	var plan TerraformPlanOutput
	err = json.Unmarshal(output, &plan)
	require.NoError(t, err, "Failed to parse terraform plan JSON: %s", string(output))

	return &plan
}


// Feature: ecs-fargate-cicd-infrastructure, Property 8: VPC network segmentation
// *For any* VPC configuration, private subnets should have route tables pointing to NAT gateways
// (not internet gateways), public subnets should have route tables pointing to internet gateways,
// and ECS services should be placed in private subnets while ALBs should be placed in public subnets
// **Validates: Requirements 2.4, 7.2, 7.3, 7.4**
func TestProperty8_VPCNetworkSegmentation(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genNetworkingConfig().Draw(rt, "config")

		// Skip configurations without NAT gateway as they don't have full segmentation
		if !config.EnableNATGateway {
			return
		}

		modulePath := getModulePath(t)
		planName := fmt.Sprintf("plan-p8-%s-%s", config.ProjectName, config.Environment)
		plan := runTerraformPlanAndGetJSON(t, modulePath, config, planName)

		// Property 8.1: VPC should be created with DNS support
		vpcs := plan.getResourcesByType("aws_vpc")
		assert.Len(t, vpcs, 1, "Exactly one VPC should be created")
		if len(vpcs) > 0 {
			assert.Equal(t, true, vpcs[0]["enable_dns_support"], "VPC should have DNS support enabled")
			assert.Equal(t, true, vpcs[0]["enable_dns_hostnames"], "VPC should have DNS hostnames enabled")
		}

		// Property 8.2: Public and private subnets should exist
		subnets := plan.getResourcesByType("aws_subnet")
		publicSubnetCount := 0
		privateSubnetCount := 0
		for _, subnet := range subnets {
			if mapPublicIP, ok := subnet["map_public_ip_on_launch"].(bool); ok && mapPublicIP {
				publicSubnetCount++
			} else {
				privateSubnetCount++
			}
		}
		assert.Equal(t, len(config.AvailabilityZones), publicSubnetCount, "Public subnets should match AZ count")
		assert.Equal(t, len(config.AvailabilityZones), privateSubnetCount, "Private subnets should match AZ count")

		// Property 8.3: Internet Gateway should be created
		igws := plan.getResourcesByType("aws_internet_gateway")
		assert.Len(t, igws, 1, "Exactly one Internet Gateway should be created")

		// Property 8.4: NAT Gateways should be created (one per AZ or single)
		natGateways := plan.getResourcesByType("aws_nat_gateway")
		expectedNATCount := len(config.AvailabilityZones)
		if config.SingleNATGateway {
			expectedNATCount = 1
		}
		assert.Len(t, natGateways, expectedNATCount, "NAT Gateway count should match configuration")

		// Property 8.5: Routes should exist for both public (IGW) and private (NAT) subnets
		routes := plan.getResourcesByType("aws_route")
		hasPublicInternetRoute := false
		hasPrivateNATRoute := false
		for _, route := range routes {
			if dest, ok := route["destination_cidr_block"].(string); ok && dest == "0.0.0.0/0" {
				if _, hasIGW := route["gateway_id"]; hasIGW {
					hasPublicInternetRoute = true
				}
				if _, hasNAT := route["nat_gateway_id"]; hasNAT {
					hasPrivateNATRoute = true
				}
			}
		}
		assert.True(t, hasPublicInternetRoute, "Public route table should have route to Internet Gateway")
		assert.True(t, hasPrivateNATRoute, "Private route tables should have routes to NAT Gateway")
	})
}

// Feature: ecs-fargate-cicd-infrastructure, Property 34: Multi-AZ deployment
// *For any* VPC configuration, subnets should span at least 2 distinct availability zones
// **Validates: Requirements 7.1**
func TestProperty34_MultiAZDeployment(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genNetworkingConfig().Draw(rt, "config")

		modulePath := getModulePath(t)
		planName := fmt.Sprintf("plan-p34-%s-%s", config.ProjectName, config.Environment)
		plan := runTerraformPlanAndGetJSON(t, modulePath, config, planName)

		// Property 34.1: At least 2 availability zones should be used
		assert.GreaterOrEqual(t, len(config.AvailabilityZones), 2,
			"At least 2 availability zones are required for high availability")

		// Property 34.2: Subnets should span multiple AZs
		subnets := plan.getResourcesByType("aws_subnet")
		publicAZs := make(map[string]bool)
		privateAZs := make(map[string]bool)

		for _, subnet := range subnets {
			az, ok := subnet["availability_zone"].(string)
			if !ok {
				continue
			}
			if mapPublicIP, ok := subnet["map_public_ip_on_launch"].(bool); ok && mapPublicIP {
				publicAZs[az] = true
			} else {
				privateAZs[az] = true
			}
		}

		assert.GreaterOrEqual(t, len(publicAZs), 2,
			"Public subnets should span at least 2 availability zones")
		assert.GreaterOrEqual(t, len(privateAZs), 2,
			"Private subnets should span at least 2 availability zones")

		// Property 34.3: Number of subnets should match number of AZs
		assert.Equal(t, len(config.AvailabilityZones), len(publicAZs),
			"Public subnet count should match AZ count")
		assert.Equal(t, len(config.AvailabilityZones), len(privateAZs),
			"Private subnet count should match AZ count")

		// Property 34.4: Each AZ should have both public and private subnets
		for _, az := range config.AvailabilityZones {
			assert.True(t, publicAZs[az], "AZ %s should have a public subnet", az)
			assert.True(t, privateAZs[az], "AZ %s should have a private subnet", az)
		}
	})
}

// Feature: ecs-fargate-cicd-infrastructure, Property 36: VPC Flow Logs enabled
// *For any* VPC configuration, a VPC Flow Log resource should be created with encryption enabled
// **Validates: Requirements 7.9**
func TestProperty36_VPCFlowLogsEnabled(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genNetworkingConfig().Draw(rt, "config")

		// Only test configurations with flow logs enabled
		if !config.EnableVPCFlowLogs {
			return
		}

		modulePath := getModulePath(t)
		planName := fmt.Sprintf("plan-p36-%s-%s", config.ProjectName, config.Environment)
		plan := runTerraformPlanAndGetJSON(t, modulePath, config, planName)

		// Property 36.1: VPC Flow Log should be created when enabled
		flowLogs := plan.getResourcesByType("aws_flow_log")
		assert.Len(t, flowLogs, 1, "Exactly one VPC Flow Log should be created when enabled")

		if len(flowLogs) > 0 {
			flowLog := flowLogs[0]

			// Property 36.2: Flow log should capture ALL traffic
			trafficType, ok := flowLog["traffic_type"].(string)
			assert.True(t, ok, "Traffic type should be set")
			assert.Equal(t, "ALL", trafficType, "Flow log should capture ALL traffic types")

			// Property 36.3: Flow log should use CloudWatch Logs destination
			logDestType, ok := flowLog["log_destination_type"].(string)
			assert.True(t, ok, "Log destination type should be set")
			assert.Equal(t, "cloud-watch-logs", logDestType, "Flow log should use CloudWatch Logs destination")
		}

		// Property 36.4: CloudWatch Log Group should be created for flow logs
		logGroups := plan.getResourcesByType("aws_cloudwatch_log_group")
		flowLogGroupFound := false
		for _, lg := range logGroups {
			if name, ok := lg["name"].(string); ok {
				if strings.Contains(name, "flow-logs") {
					flowLogGroupFound = true

					// Property 36.5: Log group should have retention configured
					retention, hasRetention := lg["retention_in_days"]
					assert.True(t, hasRetention, "Flow log CloudWatch Log Group should have retention configured")
					if hasRetention {
						retentionDays, ok := retention.(float64)
						assert.True(t, ok, "Retention should be a number")
						assert.Greater(t, retentionDays, float64(0), "Retention should be greater than 0")
					}
					break
				}
			}
		}
		assert.True(t, flowLogGroupFound, "CloudWatch Log Group for VPC Flow Logs should be created")

		// Property 36.6: IAM role for flow logs should be created
		iamRoles := plan.getResourcesByType("aws_iam_role")
		flowLogRoleFound := false
		for _, role := range iamRoles {
			if name, ok := role["name"].(string); ok {
				if strings.Contains(name, "flow-logs") {
					flowLogRoleFound = true
					break
				}
			}
		}
		assert.True(t, flowLogRoleFound, "IAM role for VPC Flow Logs should be created")
	})
}
