# Product Overview

## What This Is

ECS Fargate CI/CD Infrastructure - A production-ready AWS infrastructure for deploying microservices on ECS Fargate with automated CI/CD pipelines.

## Core Capabilities

- **Multi-environment deployment**: develop, test, qa, prod with environment-specific configurations
- **Microservice deployment**: Reusable module for deploying Node.js and Python services
- **Service types**: Public services (exposed via ALB) and internal services (Kafka-based communication)
- **CI/CD automation**: CodePipeline + CodeBuild with Bitbucket integration
- **Security & compliance**: NIST and SOC-2 compliant with encryption, audit trails, and access controls

## Key Features

- Automated container builds and deployments from Bitbucket
- Auto-scaling based on CPU/memory metrics
- Secrets management via AWS Secrets Manager
- Comprehensive monitoring with CloudWatch
- Multi-AZ high availability
- Environment promotion workflow (develop → test → qa → prod)
- Production deployments require manual approval

## External Dependencies

- **Bitbucket**: Source code repositories
- **CodeConnections**: AWS connection to Bitbucket
- **ACM Certificate**: SSL/TLS for ALB HTTPS
- **Kafka Cluster**: External Kafka brokers for internal service communication
