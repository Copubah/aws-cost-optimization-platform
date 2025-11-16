# AWS Cost Optimization & Reliability Platform - Architecture Diagrams

## High-Level Architecture

```mermaid
graph TB
    subgraph "Users & External"
        U[Users]
        OPS[Operations Team]
    end

    subgraph "AWS Cloud"
        subgraph "Cost Management Layer"
            B[AWS Budgets<br/>Monthly & Service Budgets]
            SNS1[SNS Topic<br/>Budget Alerts]
            L1[Lambda<br/>Budget Handler]
            L2[Lambda<br/>Cost Optimizer]
            EB[EventBridge<br/>Scheduled Rules]
        end

        subgraph "Application Layer"
            ALB[Application Load Balancer<br/>Multi-AZ]
            
            subgraph "Availability Zone 1"
                ECS1[ECS Fargate<br/>Tasks]
            end
            
            subgraph "Availability Zone 2"
                ECS2[ECS Fargate<br/>Tasks]
            end
            
            AS[Auto Scaling<br/>CPU & Memory Based]
        end

        subgraph "Data Layer"
            S3[S3 Buckets<br/>Lifecycle Policies]
            CWL[CloudWatch Logs<br/>Centralized Logging]
        end

        subgraph "Monitoring Layer"
            CW[CloudWatch Alarms<br/>8+ Alarms]
            SNS2[SNS Topic<br/>Operations Alerts]
            DASH[CloudWatch Dashboard<br/>Metrics Visualization]
        end

        subgraph "Network Layer"
            VPC[VPC<br/>10.0.0.0/16]
            PUB[Public Subnets]
            PRIV[Private Subnets]
            NAT[NAT Gateway]
            IGW[Internet Gateway]
        end

        subgraph "Security Layer"
            IAM[IAM Roles<br/>Least Privilege]
            SG[Security Groups<br/>Network Firewall]
            KMS[KMS Keys<br/>Encryption]
        end
    end

    U -->|HTTPS| ALB
    ALB -->|Route Traffic| ECS1
    ALB -->|Route Traffic| ECS2
    ECS1 -.->|Scale| AS
    ECS2 -.->|Scale| AS
    
    B -->|Threshold Alert| SNS1
    SNS1 -->|Trigger| L1
    L1 -->|Invoke| L2
    EB -->|Schedule| L2
    L2 -->|Stop/Scale| ECS1
    L2 -->|Stop/Scale| ECS2
    
    ECS1 -->|Store Data| S3
    ECS2 -->|Store Data| S3
    ECS1 -->|Logs| CWL
    ECS2 -->|Logs| CWL
    L1 -->|Logs| CWL
    L2 -->|Logs| CWL
    
    ECS1 -.->|Metrics| CW
    ECS2 -.->|Metrics| CW
    ALB -.->|Metrics| CW
    CW -->|Alert| SNS2
    SNS1 -->|Email| OPS
    SNS2 -->|Email| OPS
    CW -.->|Display| DASH
    
    ALB ---|Located in| PUB
    ECS1 ---|Located in| PRIV
    ECS2 ---|Located in| PRIV
    PUB -->|Route| IGW
    PRIV -->|Route| NAT
    NAT -->|Route| IGW
    
    IAM -.->|Authorize| L1
    IAM -.->|Authorize| L2
    IAM -.->|Authorize| ECS1
    IAM -.->|Authorize| ECS2
    SG -.->|Protect| ALB
    SG -.->|Protect| ECS1
    SG -.->|Protect| ECS2
    KMS -.->|Encrypt| S3
    KMS -.->|Encrypt| SNS1

    style B fill:#ff9999
    style L1 fill:#ffcc99
    style L2 fill:#ffcc99
    style ALB fill:#99ccff
    style ECS1 fill:#99ff99
    style ECS2 fill:#99ff99
    style CW fill:#ffff99
    style S3 fill:#cc99ff
    style IAM fill:#ff99cc
```

## Cost Optimization Flow

```mermaid
sequenceDiagram
    participant Budget as AWS Budget
    participant SNS as SNS Topic
    participant Handler as Budget Handler
    participant Optimizer as Cost Optimizer
    participant EC2 as EC2 Instances
    participant ECS as ECS Services
    participant Ops as Operations Team

    Budget->>Budget: Monitor Spending
    Budget->>Budget: Threshold Exceeded (80%)
    Budget->>SNS: Publish Alert
    SNS->>Handler: Trigger Lambda
    SNS->>Ops: Email Notification
    
    Handler->>Handler: Analyze Alert
    Handler->>Handler: Get Cost Details
    
    alt Critical (100%+)
        Handler->>Optimizer: Invoke (Aggressive Mode)
        Optimizer->>EC2: Stop Dev Instances
        Optimizer->>ECS: Scale Down to Min
        Optimizer->>SNS: Send Report
    else Warning (80-99%)
        Handler->>Optimizer: Invoke (Standard Mode)
        Optimizer->>EC2: Stop Tagged Instances
        Optimizer->>ECS: Scale Down Non-Prod
        Optimizer->>SNS: Send Report
    else Info (50-79%)
        Handler->>SNS: Send Monitoring Alert
    end
    
    SNS->>Ops: Detailed Report
    Ops->>Ops: Review Actions
```

## Scheduled Cost Optimization

```mermaid
sequenceDiagram
    participant EB as EventBridge
    participant Optimizer as Cost Optimizer
    participant EC2 as EC2 Instances
    participant RDS as RDS Instances
    participant ECS as ECS Services
    participant SNS as SNS Topic
    participant Ops as Operations Team

    Note over EB: Weekdays 6 PM UTC
    EB->>Optimizer: Trigger (stop_dev_instances)
    
    Optimizer->>EC2: Query Tagged Instances
    EC2-->>Optimizer: Return Dev Instances
    
    Optimizer->>Optimizer: Validate Tags
    Optimizer->>Optimizer: Check Environment != prod
    
    Optimizer->>EC2: Stop Instances
    EC2-->>Optimizer: Confirm Stopped
    
    Optimizer->>RDS: Query Tagged Databases
    RDS-->>Optimizer: Return Dev Databases
    
    Optimizer->>RDS: Stop Databases
    RDS-->>Optimizer: Confirm Stopped
    
    Note over EB: Weekdays 7 PM UTC
    EB->>Optimizer: Trigger (scale_ecs_tasks)
    
    Optimizer->>ECS: Query Services
    ECS-->>Optimizer: Return Services
    
    Optimizer->>ECS: Scale to Minimum
    ECS-->>Optimizer: Confirm Scaled
    
    Optimizer->>SNS: Send Report
    SNS->>Ops: Email Summary
```

## Reliability & Monitoring Flow

```mermaid
sequenceDiagram
    participant ECS as ECS Service
    participant ALB as Load Balancer
    participant CW as CloudWatch
    participant Alarm as Alarm
    participant SNS as SNS Topic
    participant AS as Auto Scaling
    participant Ops as Operations

    loop Every 1 minute
        ECS->>CW: Send Metrics (CPU, Memory)
        ALB->>CW: Send Metrics (Latency, Errors)
    end

    CW->>Alarm: Evaluate Thresholds
    
    alt CPU > 80%
        Alarm->>Alarm: State = ALARM
        Alarm->>SNS: Trigger Alert
        Alarm->>AS: Trigger Scale Out
        AS->>ECS: Add Tasks
        SNS->>Ops: Email Alert
    else Unhealthy Targets
        Alarm->>SNS: Critical Alert
        SNS->>Ops: Immediate Notification
        ECS->>ECS: Auto Replace Tasks
    else High Latency
        Alarm->>SNS: Warning Alert
        SNS->>Ops: Investigation Needed
    end

    Note over CW,Ops: Composite Alarm Logic
    Alarm->>Alarm: Aggregate Child Alarms
    
    alt Multiple Critical Alarms
        Alarm->>SNS: Service Critical Alert
        SNS->>Ops: Page On-Call
    end
```

## Network Architecture

```mermaid
graph TB
    subgraph "Internet"
        USERS[Users]
        INET[Internet]
    end

    subgraph "AWS Region: us-east-1"
        subgraph "VPC: 10.0.0.0/16"
            IGW[Internet Gateway]
            
            subgraph "Availability Zone A"
                subgraph "Public Subnet A: 10.0.0.0/24"
                    ALB1[ALB Node]
                    NAT1[NAT Gateway]
                end
                
                subgraph "Private Subnet A: 10.0.100.0/24"
                    ECS1[ECS Tasks]
                    LAMBDA1[Lambda Functions]
                end
            end
            
            subgraph "Availability Zone B"
                subgraph "Public Subnet B: 10.0.1.0/24"
                    ALB2[ALB Node]
                    NAT2[NAT Gateway]
                end
                
                subgraph "Private Subnet B: 10.0.101.0/24"
                    ECS2[ECS Tasks]
                    LAMBDA2[Lambda Functions]
                end
            end
        end
        
        subgraph "AWS Services (VPC Endpoints)"
            S3E[S3 Endpoint]
            ECRE[ECR Endpoint]
            CWLE[CloudWatch Logs]
        end
    end

    USERS -->|HTTPS| IGW
    IGW --> ALB1
    IGW --> ALB2
    ALB1 --> ECS1
    ALB2 --> ECS2
    
    ECS1 -->|Outbound| NAT1
    ECS2 -->|Outbound| NAT2
    NAT1 --> IGW
    NAT2 --> IGW
    
    ECS1 -.->|Private| S3E
    ECS2 -.->|Private| S3E
    ECS1 -.->|Private| ECRE
    ECS2 -.->|Private| ECRE
    ECS1 -.->|Private| CWLE
    ECS2 -.->|Private| CWLE
    LAMBDA1 -.->|Private| CWLE
    LAMBDA2 -.->|Private| CWLE

    style ALB1 fill:#99ccff
    style ALB2 fill:#99ccff
    style ECS1 fill:#99ff99
    style ECS2 fill:#99ff99
    style NAT1 fill:#ffcc99
    style NAT2 fill:#ffcc99
    style IGW fill:#ff99cc
```

## Security Architecture

```mermaid
graph TB
    subgraph "Identity & Access"
        IAM[IAM Roles & Policies]
        MFA[MFA Enforcement]
        TRAIL[CloudTrail Logging]
    end

    subgraph "Data Protection"
        KMS[KMS Encryption Keys]
        S3E[S3 Encryption at Rest]
        SNSE[SNS Encryption]
        TLS[TLS 1.2+ in Transit]
    end

    subgraph "Network Security"
        SG[Security Groups]
        NACL[Network ACLs]
        VPC[VPC Isolation]
        PRIV[Private Subnets]
    end

    subgraph "Detective Controls"
        CW[CloudWatch Alarms]
        GD[GuardDuty]
        CONFIG[AWS Config]
        LOGS[Centralized Logging]
    end

    subgraph "Application Layer"
        ALB[Load Balancer]
        ECS[ECS Tasks]
        LAMBDA[Lambda Functions]
        S3[S3 Buckets]
    end

    IAM -.->|Authorize| ECS
    IAM -.->|Authorize| LAMBDA
    IAM -.->|Authorize| S3
    MFA -.->|Require| IAM
    TRAIL -.->|Audit| IAM

    KMS -.->|Encrypt| S3E
    KMS -.->|Encrypt| SNSE
    S3E -.->|Protect| S3
    TLS -.->|Secure| ALB

    SG -.->|Filter| ALB
    SG -.->|Filter| ECS
    NACL -.->|Filter| PRIV
    VPC -.->|Isolate| ECS
    PRIV -.->|Hide| ECS

    CW -.->|Monitor| ECS
    CW -.->|Monitor| ALB
    GD -.->|Detect Threats| VPC
    CONFIG -.->|Compliance| IAM
    LOGS -.->|Audit| LAMBDA

    style IAM fill:#ff99cc
    style KMS fill:#ffcc99
    style SG fill:#99ccff
    style CW fill:#ffff99
    style ECS fill:#99ff99
```

## Data Flow Diagram

```mermaid
graph LR
    subgraph "User Request Flow"
        U[User] -->|1. HTTPS Request| ALB[Load Balancer]
        ALB -->|2. Route to Healthy Target| ECS[ECS Task]
        ECS -->|3. Process Request| APP[Application]
        APP -->|4. Read/Write| S3[S3 Storage]
        APP -->|5. Response| ECS
        ECS -->|6. Return| ALB
        ALB -->|7. HTTPS Response| U
    end

    subgraph "Logging Flow"
        ECS -.->|Application Logs| CWL[CloudWatch Logs]
        ALB -.->|Access Logs| S3L[S3 Logs Bucket]
        LAMBDA[Lambda] -.->|Function Logs| CWL
    end

    subgraph "Metrics Flow"
        ECS -.->|CPU, Memory| CW[CloudWatch Metrics]
        ALB -.->|Latency, Errors| CW
        CW -.->|Visualize| DASH[Dashboard]
        CW -.->|Evaluate| ALARM[Alarms]
    end

    subgraph "Cost Flow"
        BUDGET[AWS Budget] -.->|Monitor| COST[Cost & Usage]
        COST -.->|Report| CE[Cost Explorer]
        BUDGET -.->|Alert| SNS[SNS Topic]
        SNS -.->|Trigger| LAMBDA
    end

    style U fill:#99ccff
    style ECS fill:#99ff99
    style S3 fill:#cc99ff
    style CW fill:#ffff99
    style BUDGET fill:#ff9999
```

## Deployment Pipeline

```mermaid
graph LR
    subgraph "Development"
        CODE[Code Changes]
        GIT[Git Repository]
    end

    subgraph "CI/CD"
        TF[Terraform]
        VALIDATE[Validate]
        PLAN[Plan]
        APPLY[Apply]
    end

    subgraph "AWS Infrastructure"
        VPC[VPC]
        ECS[ECS]
        LAMBDA[Lambda]
        CW[Monitoring]
    end

    subgraph "Validation"
        TEST[Tests]
        HEALTH[Health Checks]
        VERIFY[Verification]
    end

    CODE --> GIT
    GIT --> TF
    TF --> VALIDATE
    VALIDATE --> PLAN
    PLAN --> APPLY
    
    APPLY --> VPC
    APPLY --> ECS
    APPLY --> LAMBDA
    APPLY --> CW
    
    VPC --> TEST
    ECS --> TEST
    LAMBDA --> TEST
    CW --> TEST
    
    TEST --> HEALTH
    HEALTH --> VERIFY
    
    VERIFY -.->|Success| CODE
    VERIFY -.->|Failure| GIT

    style CODE fill:#99ccff
    style APPLY fill:#99ff99
    style VERIFY fill:#ffff99
```

## Legend

```mermaid
graph LR
    subgraph "Component Types"
        COMP1[Compute]
        COMP2[Storage]
        COMP3[Messaging]
        COMP4[Monitoring]
        COMP5[Cost Management]
        COMP6[Security]
    end

    subgraph "Connection Types"
        A[Component A] -->|Data Flow| B[Component B]
        C[Component C] -.->|Monitoring/Logs| D[Component D]
        E[Component E] ---|Located In| F[Component F]
    end

    style COMP1 fill:#99ff99
    style COMP2 fill:#cc99ff
    style COMP3 fill:#ffcc99
    style COMP4 fill:#ffff99
    style COMP5 fill:#ff9999
    style COMP6 fill:#ff99cc
```

## How to View These Diagrams

### GitHub
These Mermaid diagrams render automatically on GitHub. Just view this file in your repository.

### VS Code
Install the "Markdown Preview Mermaid Support" extension.

### Online
Copy the Mermaid code to [Mermaid Live Editor](https://mermaid.live/)

### Export as Image
Use the Mermaid CLI or online editor to export as PNG/SVG:
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i ARCHITECTURE_DIAGRAM.md -o architecture.png
```
