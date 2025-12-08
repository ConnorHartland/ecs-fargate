// Package helpers provides test utilities for parsing Terraform plan output
package helpers

import (
	"encoding/json"
	"strings"
)

// TerraformPlan represents a parsed Terraform plan
type TerraformPlan struct {
	PlannedValues PlannedValues `json:"planned_values"`
	ResourceChanges []ResourceChange `json:"resource_changes"`
}

// PlannedValues contains the planned resource values
type PlannedValues struct {
	RootModule RootModule `json:"root_module"`
}

// RootModule contains resources in the root module
type RootModule struct {
	Resources []PlannedResource `json:"resources"`
}

// PlannedResource represents a planned resource
type PlannedResource struct {
	Address string                 `json:"address"`
	Type    string                 `json:"type"`
	Name    string                 `json:"name"`
	Values  map[string]interface{} `json:"values"`
}

// ResourceChange represents a resource change in the plan
type ResourceChange struct {
	Address      string `json:"address"`
	Type         string `json:"type"`
	Name         string `json:"name"`
	Change       Change `json:"change"`
}

// Change represents the change details
type Change struct {
	Actions []string               `json:"actions"`
	Before  map[string]interface{} `json:"before"`
	After   map[string]interface{} `json:"after"`
}

// ParseTerraformPlan parses JSON plan output into a TerraformPlan struct
func ParseTerraformPlan(planJSON string) (*TerraformPlan, error) {
	var plan TerraformPlan
	err := json.Unmarshal([]byte(planJSON), &plan)
	if err != nil {
		return nil, err
	}
	return &plan, nil
}

// GetResourcesByType returns all resources of a specific type from the plan
func (p *TerraformPlan) GetResourcesByType(resourceType string) []PlannedResource {
	var resources []PlannedResource
	for _, r := range p.PlannedValues.RootModule.Resources {
		if r.Type == resourceType {
			resources = append(resources, r)
		}
	}
	return resources
}

// HasResourceType checks if the plan contains a resource of the given type
func (p *TerraformPlan) HasResourceType(resourceType string) bool {
	return len(p.GetResourcesByType(resourceType)) > 0
}

// GetResourceValue gets a specific value from a resource
func (r *PlannedResource) GetResourceValue(key string) interface{} {
	return r.Values[key]
}

// GetStringValue gets a string value from a resource
func (r *PlannedResource) GetStringValue(key string) string {
	if val, ok := r.Values[key].(string); ok {
		return val
	}
	return ""
}

// GetBoolValue gets a boolean value from a resource
func (r *PlannedResource) GetBoolValue(key string) bool {
	if val, ok := r.Values[key].(bool); ok {
		return val
	}
	return false
}

// ContainsSubstring checks if a string contains a substring
func ContainsSubstring(s, substr string) bool {
	return strings.Contains(s, substr)
}
