// Package properties contains property-based tests for Terraform modules
// These tests validate correctness properties defined in the design document
package properties

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"pgregory.net/rapid"
)

// ECSServiceConfig represents a valid ECS service module configuration
type ECSServiceConfig struct {
	Environment                      string
	ProjectName                      string
	ServiceName                      string
	ServiceType                      string
	ClusterARN                       string
	ClusterName                      string
	TaskDefinitionARN                string
	ContainerName                    string
	ContainerPort                    int
	DesiredCount                     int
	DeploymentMinimumHealthyPercent  int
	DeploymentMaximumPercent         int
	PrivateSubnetIDs                 []string
	SecurityGroupIDs                 []string
	TargetGroupARN                   string
	EnableServiceDiscovery           bool
	ServiceDiscoveryNamespaceID      string
}

// genServiceType generates a valid service type
func genServiceType() *rapid.Generator[string] {
	return rapid.SampledFrom([]string{"public", "internal"})
}

// genServiceName generates a valid service name
func genServiceName() *rapid.Generator[string] {
	return rapid.Custom(func(t *rapid.T) string {
		prefixes := []string{"api", "web", "worker", "processor", "gateway", "auth", "data"}
		suffixes := []string{"service", "svc", "app", "handler"}
		prefix := rapid.SampledFrom(prefixes).Draw(t, "prefix")
		suffix := rapid.SampledFrom(suffixes).Draw(t, "suffix")
		num := rapid.IntRange(1, 99).Draw(t, "num")
		return fmt.Sprintf("%s-%s-%d", prefix, suffix, num)
	})
}

// genDesiredCount generates a valid desired count (1-10)
func genDesiredCount() *rapid.Generator[int] {
	return rapid.IntRange(1, 10)
}

// genContainerPort generates a valid container port
func genContainerPort() *rapid.Generator[int] {
	return rapid.SampledFrom([]int{80, 443, 3000, 8080, 8443, 9000})
}

// genDeploymentMinHealthyPercent generates a valid minimum healthy percent
func genDeploymentMinHealthyPercent() *rapid.Generator[int] {
	return rapid.SampledFrom([]int{50, 100})
}

// genDeploymentMaxPercent generates a valid maximum percent
func genDeploymentMaxPercent() *rapid.Generator[int] {
	return rapid.SampledFrom([]int{150, 200})
}


// genPrivateSubnetIDs generates mock private subnet IDs
func genPrivateSubnetIDs() *rapid.Generator[[]string] {
	return rapid.SampledFrom([][]string{
		{"subnet-private-1a", "subnet-private-1b"},
		{"subnet-private-1a", "subnet-private-1b", "subnet-private-1c"},
	})
}

// genSecurityGroupIDs generates mock security group IDs
func genSecurityGroupIDs() *rapid.Generator[[]string] {
	return rapid.Custom(func(t *rapid.T) []string {
		count := rapid.IntRange(1, 3).Draw(t, "sg_count")
		sgs := make([]string, count)
		for i := 0; i < count; i++ {
			sgs[i] = fmt.Sprintf("sg-%d", rapid.IntRange(100000, 999999).Draw(t, fmt.Sprintf("sg_%d", i)))
		}
		return sgs
	})
}

// genECSServiceConfig generates a valid ECS service configuration
func genECSServiceConfig() *rapid.Generator[ECSServiceConfig] {
	return rapid.Custom(func(t *rapid.T) ECSServiceConfig {
		serviceType := genServiceType().Draw(t, "service_type")
		serviceName := genServiceName().Draw(t, "service_name")
		env := genEnvironment().Draw(t, "environment")
		projectName := genProjectName().Draw(t, "project_name")

		config := ECSServiceConfig{
			Environment:                     env,
			ProjectName:                     projectName,
			ServiceName:                     serviceName,
			ServiceType:                     serviceType,
			ClusterARN:                      fmt.Sprintf("arn:aws:ecs:us-east-1:123456789012:cluster/%s-%s-cluster", projectName, env),
			ClusterName:                     fmt.Sprintf("%s-%s-cluster", projectName, env),
			TaskDefinitionARN:               fmt.Sprintf("arn:aws:ecs:us-east-1:123456789012:task-definition/%s-%s:1", serviceName, env),
			ContainerName:                   serviceName,
			ContainerPort:                   genContainerPort().Draw(t, "container_port"),
			DesiredCount:                    genDesiredCount().Draw(t, "desired_count"),
			DeploymentMinimumHealthyPercent: genDeploymentMinHealthyPercent().Draw(t, "min_healthy"),
			DeploymentMaximumPercent:        genDeploymentMaxPercent().Draw(t, "max_percent"),
			PrivateSubnetIDs:                genPrivateSubnetIDs().Draw(t, "private_subnets"),
			SecurityGroupIDs:                genSecurityGroupIDs().Draw(t, "security_groups"),
		}

		// Set service-type specific configurations
		if serviceType == "public" {
			config.TargetGroupARN = fmt.Sprintf("arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/%s-%s/1234567890", serviceName, env)
			config.EnableServiceDiscovery = false
		} else {
			config.TargetGroupARN = ""
			config.EnableServiceDiscovery = rapid.Bool().Draw(t, "enable_service_discovery")
			if config.EnableServiceDiscovery {
				config.ServiceDiscoveryNamespaceID = fmt.Sprintf("ns-%s", env)
			}
		}

		return config
	})
}

// toTerraformVars converts ECSServiceConfig to Terraform variables map
func (c ECSServiceConfig) toTerraformVars() map[string]interface{} {
	vars := map[string]interface{}{
		"environment":                        c.Environment,
		"project_name":                       c.ProjectName,
		"service_name":                       c.ServiceName,
		"service_type":                       c.ServiceType,
		"cluster_arn":                        c.ClusterARN,
		"cluster_name":                       c.ClusterName,
		"task_definition_arn":                c.TaskDefinitionARN,
		"container_name":                     c.ContainerName,
		"container_port":                     c.ContainerPort,
		"desired_count":                      c.DesiredCount,
		"deployment_minimum_healthy_percent": c.DeploymentMinimumHealthyPercent,
		"deployment_maximum_percent":         c.DeploymentMaximumPercent,
		"private_subnet_ids":                 c.PrivateSubnetIDs,
		"security_group_ids":                 c.SecurityGroupIDs,
		"enable_service_discovery":           c.EnableServiceDiscovery,
	}

	if c.ServiceType == "public" && c.TargetGroupARN != "" {
		vars["target_group_arn"] = c.TargetGroupARN
	}

	if c.EnableServiceDiscovery && c.ServiceDiscoveryNamespaceID != "" {
		vars["service_discovery_namespace_id"] = c.ServiceDiscoveryNamespaceID
	}

	return vars
}


// ECSServicePlanOutput represents the JSON output of terraform show -json for ECS service
type ECSServicePlanOutput struct {
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
func (p *ECSServicePlanOutput) getResourcesByType(resourceType string) []map[string]interface{} {
	var resources []map[string]interface{}
	for _, r := range p.PlannedValues.RootModule.Resources {
		if r.Type == resourceType {
			resources = append(resources, r.Values)
		}
	}
	return resources
}

// getECSServiceModulePath returns the absolute path to the ecs-service module
func getECSServiceModulePath(t *testing.T) string {
	cwd, err := os.Getwd()
	require.NoError(t, err)
	modulePath := filepath.Join(cwd, "..", "..", "terraform", "modules", "ecs-service")
	_, err = os.Stat(modulePath)
	require.NoError(t, err, "Module path does not exist: %s", modulePath)
	return modulePath
}

// runECSServiceTerraformPlan runs terraform plan and returns the JSON output
func runECSServiceTerraformPlan(t *testing.T, modulePath string, config ECSServiceConfig, planName string) *ECSServicePlanOutput {
	// Create a temporary directory for the test
	tempDir, err := os.MkdirTemp("", "terraform-test-*")
	require.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create a test configuration file that uses the module
	tfConfig := fmt.Sprintf(`
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}

module "ecs_service" {
  source = "%s"

  environment   = "%s"
  project_name  = "%s"
  service_name  = "%s"
  service_type  = "%s"

  cluster_arn         = "%s"
  cluster_name        = "%s"
  task_definition_arn = "%s"
  container_name      = "%s"
  container_port      = %d

  desired_count                      = %d
  deployment_minimum_healthy_percent = %d
  deployment_maximum_percent         = %d

  private_subnet_ids = %s
  security_group_ids = %s

  target_group_arn = %s

  enable_service_discovery       = %t
  service_discovery_namespace_id = %s
}
`,
		modulePath,
		config.Environment,
		config.ProjectName,
		config.ServiceName,
		config.ServiceType,
		config.ClusterARN,
		config.ClusterName,
		config.TaskDefinitionARN,
		config.ContainerName,
		config.ContainerPort,
		config.DesiredCount,
		config.DeploymentMinimumHealthyPercent,
		config.DeploymentMaximumPercent,
		toHCLList(config.PrivateSubnetIDs),
		toHCLList(config.SecurityGroupIDs),
		toHCLString(config.TargetGroupARN),
		config.EnableServiceDiscovery,
		toHCLString(config.ServiceDiscoveryNamespaceID),
	)

	// Write the test configuration
	testConfigPath := filepath.Join(tempDir, "main.tf")
	err = os.WriteFile(testConfigPath, []byte(tfConfig), 0644)
	require.NoError(t, err)

	// Initialize Terraform
	initCmd := exec.Command("terraform", "init")
	initCmd.Dir = tempDir
	initOutput, err := initCmd.CombinedOutput()
	require.NoError(t, err, "Failed to init terraform: %s", string(initOutput))

	// Create plan
	planFilePath := filepath.Join(tempDir, "plan.tfplan")
	planCmd := exec.Command("terraform", "plan", "-out="+planFilePath, "-input=false")
	planCmd.Dir = tempDir
	planOutput, err := planCmd.CombinedOutput()
	require.NoError(t, err, "Failed to create terraform plan: %s", string(planOutput))

	// Get JSON output
	showCmd := exec.Command("terraform", "show", "-json", planFilePath)
	showCmd.Dir = tempDir
	jsonOutput, err := showCmd.CombinedOutput()
	require.NoError(t, err, "Failed to show terraform plan: %s", string(jsonOutput))

	// Parse JSON
	var plan ECSServicePlanOutput
	err = json.Unmarshal(jsonOutput, &plan)
	require.NoError(t, err, "Failed to parse terraform plan JSON")

	return &plan
}

// toHCLList converts a string slice to HCL list format
func toHCLList(items []string) string {
	if len(items) == 0 {
		return "[]"
	}
	result := "["
	for i, item := range items {
		if i > 0 {
			result += ", "
		}
		result += fmt.Sprintf(`"%s"`, item)
	}
	result += "]"
	return result
}

// toHCLString converts a string to HCL string format (handles null)
func toHCLString(s string) string {
	if s == "" {
		return "null"
	}
	return fmt.Sprintf(`"%s"`, s)
}


// Feature: ecs-fargate-cicd-infrastructure, Property 21: ECS service per microservice
// *For any* service configuration, exactly one ECS service should be created with a unique name
// **Validates: Requirements 5.1**
func TestProperty21_ECSServicePerMicroservice(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genECSServiceConfig().Draw(rt, "config")

		modulePath := getECSServiceModulePath(t)
		planName := fmt.Sprintf("plan-p21-%s-%s", config.ServiceName, config.Environment)
		plan := runECSServiceTerraformPlan(t, modulePath, config, planName)

		// Property 21.1: Exactly one ECS service should be created
		ecsServices := plan.getResourcesByType("aws_ecs_service")
		assert.Len(t, ecsServices, 1, "Exactly one ECS service should be created per module invocation")

		if len(ecsServices) > 0 {
			service := ecsServices[0]

			// Property 21.2: Service name should be unique and include service name and environment
			serviceName, ok := service["name"].(string)
			assert.True(t, ok, "Service should have a name")
			assert.Contains(t, serviceName, config.ServiceName, "Service name should contain the service name")
			assert.Contains(t, serviceName, config.Environment, "Service name should contain the environment")

			// Property 21.3: Service should be associated with the correct cluster
			clusterARN, ok := service["cluster"].(string)
			assert.True(t, ok, "Service should have a cluster")
			assert.Equal(t, config.ClusterARN, clusterARN, "Service should be in the correct cluster")
		}
	})
}

// Feature: ecs-fargate-cicd-infrastructure, Property 24: Desired count configuration
// *For any* ECS service configuration, desired_count should be set to a positive integer
// **Validates: Requirements 5.4**
func TestProperty24_DesiredCountConfiguration(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genECSServiceConfig().Draw(rt, "config")

		modulePath := getECSServiceModulePath(t)
		planName := fmt.Sprintf("plan-p24-%s-%s", config.ServiceName, config.Environment)
		plan := runECSServiceTerraformPlan(t, modulePath, config, planName)

		// Property 24.1: ECS service should have desired_count set
		ecsServices := plan.getResourcesByType("aws_ecs_service")
		require.Len(t, ecsServices, 1, "Exactly one ECS service should be created")

		service := ecsServices[0]

		// Property 24.2: Desired count should match the input configuration
		desiredCount, ok := service["desired_count"].(float64)
		assert.True(t, ok, "Service should have desired_count set")
		assert.Equal(t, float64(config.DesiredCount), desiredCount, "Desired count should match input")

		// Property 24.3: Desired count should be a positive integer
		assert.GreaterOrEqual(t, desiredCount, float64(1), "Desired count should be at least 1")
	})
}

// Feature: ecs-fargate-cicd-infrastructure, Property 25: Rolling update configuration
// *For any* ECS service deployment configuration, both minimum_healthy_percent and maximum_percent should be defined with valid values
// **Validates: Requirements 5.5**
func TestProperty25_RollingUpdateConfiguration(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genECSServiceConfig().Draw(rt, "config")

		modulePath := getECSServiceModulePath(t)
		planName := fmt.Sprintf("plan-p25-%s-%s", config.ServiceName, config.Environment)
		plan := runECSServiceTerraformPlan(t, modulePath, config, planName)

		// Property 25.1: ECS service should have deployment configuration
		ecsServices := plan.getResourcesByType("aws_ecs_service")
		require.Len(t, ecsServices, 1, "Exactly one ECS service should be created")

		service := ecsServices[0]

		// Property 25.2: Deployment configuration should be present
		deploymentConfig, ok := service["deployment_configuration"].([]interface{})
		assert.True(t, ok && len(deploymentConfig) > 0, "Service should have deployment_configuration")

		if len(deploymentConfig) > 0 {
			config := deploymentConfig[0].(map[string]interface{})

			// Property 25.3: minimum_healthy_percent should be defined
			minHealthy, hasMinHealthy := config["minimum_healthy_percent"]
			assert.True(t, hasMinHealthy, "Deployment configuration should have minimum_healthy_percent")
			if hasMinHealthy {
				minHealthyVal, ok := minHealthy.(float64)
				assert.True(t, ok, "minimum_healthy_percent should be a number")
				assert.GreaterOrEqual(t, minHealthyVal, float64(0), "minimum_healthy_percent should be >= 0")
				assert.LessOrEqual(t, minHealthyVal, float64(200), "minimum_healthy_percent should be <= 200")
			}

			// Property 25.4: maximum_percent should be defined
			maxPercent, hasMaxPercent := config["maximum_percent"]
			assert.True(t, hasMaxPercent, "Deployment configuration should have maximum_percent")
			if hasMaxPercent {
				maxPercentVal, ok := maxPercent.(float64)
				assert.True(t, ok, "maximum_percent should be a number")
				assert.GreaterOrEqual(t, maxPercentVal, float64(100), "maximum_percent should be >= 100")
				assert.LessOrEqual(t, maxPercentVal, float64(400), "maximum_percent should be <= 400")
			}
		}
	})
}


// Feature: ecs-fargate-cicd-infrastructure, Property 27: Private subnet placement
// *For any* ECS service network configuration, all subnet IDs should reference private subnets (not public subnets)
// **Validates: Requirements 5.7**
func TestProperty27_PrivateSubnetPlacement(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genECSServiceConfig().Draw(rt, "config")

		modulePath := getECSServiceModulePath(t)
		planName := fmt.Sprintf("plan-p27-%s-%s", config.ServiceName, config.Environment)
		plan := runECSServiceTerraformPlan(t, modulePath, config, planName)

		// Property 27.1: ECS service should have network configuration
		ecsServices := plan.getResourcesByType("aws_ecs_service")
		require.Len(t, ecsServices, 1, "Exactly one ECS service should be created")

		service := ecsServices[0]

		// Property 27.2: Network configuration should be present
		networkConfig, ok := service["network_configuration"].([]interface{})
		assert.True(t, ok && len(networkConfig) > 0, "Service should have network_configuration")

		if len(networkConfig) > 0 {
			netConfig := networkConfig[0].(map[string]interface{})

			// Property 27.3: Subnets should be configured
			subnets, hasSubnets := netConfig["subnets"]
			assert.True(t, hasSubnets, "Network configuration should have subnets")

			if hasSubnets {
				subnetList, ok := subnets.([]interface{})
				assert.True(t, ok, "Subnets should be a list")
				assert.GreaterOrEqual(t, len(subnetList), 1, "At least one subnet should be configured")

				// Property 27.4: Subnets should match the private subnet IDs provided
				for i, subnet := range subnetList {
					subnetID, ok := subnet.(string)
					assert.True(t, ok, "Subnet ID should be a string")
					assert.Equal(t, config.PrivateSubnetIDs[i], subnetID, "Subnet should match input private subnet")
				}
			}

			// Property 27.5: assign_public_ip should be false for private subnets
			assignPublicIP, hasAssignPublicIP := netConfig["assign_public_ip"]
			if hasAssignPublicIP {
				assignPublicIPVal, ok := assignPublicIP.(bool)
				assert.True(t, ok, "assign_public_ip should be a boolean")
				assert.False(t, assignPublicIPVal, "assign_public_ip should be false for private subnet placement")
			}
		}
	})
}

// Feature: ecs-fargate-cicd-infrastructure, Property 37: Target group attachment for public services
// *For any* public-facing service, the ECS service should have a load_balancer block referencing a target group ARN
// **Validates: Requirements 8.1**
func TestProperty37_TargetGroupAttachmentForPublicServices(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genECSServiceConfig().Draw(rt, "config")

		// Only test public services
		if config.ServiceType != "public" {
			return
		}

		modulePath := getECSServiceModulePath(t)
		planName := fmt.Sprintf("plan-p37-%s-%s", config.ServiceName, config.Environment)
		plan := runECSServiceTerraformPlan(t, modulePath, config, planName)

		// Property 37.1: ECS service should exist
		ecsServices := plan.getResourcesByType("aws_ecs_service")
		require.Len(t, ecsServices, 1, "Exactly one ECS service should be created")

		service := ecsServices[0]

		// Property 37.2: Public service should have load_balancer configuration
		loadBalancer, ok := service["load_balancer"].([]interface{})
		assert.True(t, ok && len(loadBalancer) > 0, "Public service should have load_balancer configuration")

		if len(loadBalancer) > 0 {
			lbConfig := loadBalancer[0].(map[string]interface{})

			// Property 37.3: Load balancer should reference the target group ARN
			targetGroupARN, hasTargetGroup := lbConfig["target_group_arn"]
			assert.True(t, hasTargetGroup, "Load balancer should have target_group_arn")
			if hasTargetGroup {
				tgARN, ok := targetGroupARN.(string)
				assert.True(t, ok, "target_group_arn should be a string")
				assert.Equal(t, config.TargetGroupARN, tgARN, "Target group ARN should match input")
			}

			// Property 37.4: Load balancer should reference the correct container
			containerName, hasContainerName := lbConfig["container_name"]
			assert.True(t, hasContainerName, "Load balancer should have container_name")
			if hasContainerName {
				cName, ok := containerName.(string)
				assert.True(t, ok, "container_name should be a string")
				assert.Equal(t, config.ContainerName, cName, "Container name should match input")
			}

			// Property 37.5: Load balancer should reference the correct container port
			containerPort, hasContainerPort := lbConfig["container_port"]
			assert.True(t, hasContainerPort, "Load balancer should have container_port")
			if hasContainerPort {
				cPort, ok := containerPort.(float64)
				assert.True(t, ok, "container_port should be a number")
				assert.Equal(t, float64(config.ContainerPort), cPort, "Container port should match input")
			}
		}

		// Property 37.6: Public service should have health_check_grace_period_seconds set
		healthCheckGrace, hasHealthCheckGrace := service["health_check_grace_period_seconds"]
		assert.True(t, hasHealthCheckGrace, "Public service should have health_check_grace_period_seconds")
		if hasHealthCheckGrace {
			graceVal, ok := healthCheckGrace.(float64)
			assert.True(t, ok, "health_check_grace_period_seconds should be a number")
			assert.GreaterOrEqual(t, graceVal, float64(0), "health_check_grace_period_seconds should be >= 0")
		}
	})
}

// Feature: ecs-fargate-cicd-infrastructure, Property 42: No ALB for internal services
// *For any* internal service configuration, the ECS service should not have a load_balancer block
// **Validates: Requirements 8.7**
func TestProperty42_NoALBForInternalServices(t *testing.T) {
	t.Parallel()

	rapid.Check(t, func(rt *rapid.T) {
		config := genECSServiceConfig().Draw(rt, "config")

		// Only test internal services
		if config.ServiceType != "internal" {
			return
		}

		modulePath := getECSServiceModulePath(t)
		planName := fmt.Sprintf("plan-p42-%s-%s", config.ServiceName, config.Environment)
		plan := runECSServiceTerraformPlan(t, modulePath, config, planName)

		// Property 42.1: ECS service should exist
		ecsServices := plan.getResourcesByType("aws_ecs_service")
		require.Len(t, ecsServices, 1, "Exactly one ECS service should be created")

		service := ecsServices[0]

		// Property 42.2: Internal service should NOT have load_balancer configuration
		loadBalancer, ok := service["load_balancer"].([]interface{})
		if ok {
			assert.Len(t, loadBalancer, 0, "Internal service should not have load_balancer configuration")
		}

		// Property 42.3: Internal service should NOT have health_check_grace_period_seconds
		// (only services with load balancers need this)
		healthCheckGrace, hasHealthCheckGrace := service["health_check_grace_period_seconds"]
		if hasHealthCheckGrace {
			// If present, it should be null or 0 for internal services
			if healthCheckGrace != nil {
				graceVal, ok := healthCheckGrace.(float64)
				if ok {
					assert.Equal(t, float64(0), graceVal, "Internal service should not have health_check_grace_period_seconds set")
				}
			}
		}

		// Property 42.4: If service discovery is enabled, service_registries should be present
		if config.EnableServiceDiscovery {
			serviceRegistries, ok := service["service_registries"].([]interface{})
			assert.True(t, ok && len(serviceRegistries) > 0, "Internal service with service discovery should have service_registries")
		}
	})
}
