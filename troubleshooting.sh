#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print section header
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    local required_tools=(
        "aws:AWS CLI for interacting with AWS services"
        "docker:Docker for container operations"
        "terraform:Terraform for infrastructure management"
        "jq:JSON processor for parsing AWS output"
        "curl:HTTP client for health checks"
    )
    
    for tool_info in "${required_tools[@]}"; do
        tool="${tool_info%%:*}"
        description="${tool_info#*:}"
        if ! command_exists "$tool"; then
            missing_tools+=("$tool ($description)")
        else
            echo -e "${GREEN}✓${NC} Found $tool"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "\n${RED}Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "  - $tool"
        done
        exit 1
    fi
}

# Function to check AWS credentials and permissions
check_aws_credentials() {
    print_header "Checking AWS Configuration"
    
    echo "Verifying AWS credentials..."
    if ! aws_identity=$(aws sts get-caller-identity 2>&1); then
        echo -e "${RED}✗ AWS credentials error:${NC}"
        echo "$aws_identity"
        exit 1
    fi
    
    account_id=$(echo "$aws_identity" | jq -r .Account)
    user_arn=$(echo "$aws_identity" | jq -r .Arn)
    echo -e "${GREEN}✓${NC} Using AWS Account: $account_id"
    echo -e "${GREEN}✓${NC} Authenticated as: $user_arn"
    
    # Check AWS region
    region=$(aws configure get region)
    echo -e "${GREEN}✓${NC} AWS Region: $region"
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "$(( bytes / 1048576 ))MB"
    fi
}

# Function to check ECR repository and image
check_ecr() {
    print_header "Checking ECR Status"
    
    # Get repository details
    echo "Checking ECR repository..."
    if ! repo_details=$(aws ecr describe-repositories --repository-name uptime-kuma 2>&1); then
        echo -e "${RED}✗ ECR repository error:${NC}"
        echo "$repo_details"
        return 1
    fi
    
    repo_uri=$(echo "$repo_details" | jq -r '.repositories[0].repositoryUri')
    echo -e "${GREEN}✓${NC} Found repository: $repo_uri"
    
    # Check image details
    echo -e "\nChecking latest image..."
    if ! image_details=$(aws ecr describe-images --repository-name uptime-kuma --image-ids imageTag=latest 2>&1); then
        echo -e "${RED}✗ Image not found or error:${NC}"
        echo "$image_details"
        return 1
    fi
    
    image_digest=$(echo "$image_details" | jq -r '.imageDetails[0].imageDigest')
    image_size=$(echo "$image_details" | jq -r '.imageDetails[0].imageSizeInBytes')
    image_pushed=$(echo "$image_details" | jq -r '.imageDetails[0].imagePushedAt')
    
    echo -e "${GREEN}✓${NC} Image digest: ${image_digest:0:12}..."
    echo -e "${GREEN}✓${NC} Image size: $(format_bytes $image_size)"
    echo -e "${GREEN}✓${NC} Pushed at: $image_pushed"
}

# Function to check ECS service status with detailed information
check_ecs_service() {
    print_header "Checking ECS Service Status"
    
    local cluster_name="uptime-kuma-cluster"
    local service_name="uptime-kuma"
    
    # Check cluster
    echo "Checking ECS cluster..."
    if ! cluster_info=$(aws ecs describe-clusters --clusters "$cluster_name" 2>&1); then
        echo -e "${RED}✗ Cluster error:${NC}"
        echo "$cluster_info"
        return 1
    fi
    
    cluster_status=$(echo "$cluster_info" | jq -r '.clusters[0].status')
    echo -e "${GREEN}✓${NC} Cluster status: $cluster_status"
    
    # Check service
    echo -e "\nChecking ECS service..."
    if ! service_info=$(aws ecs describe-services --cluster "$cluster_name" --services "$service_name" 2>&1); then
        echo -e "${RED}✗ Service error:${NC}"
        echo "$service_info"
        return 1
    fi
    
    # Extract service details
    service_status=$(echo "$service_info" | jq -r '.services[0].status')
    desired_count=$(echo "$service_info" | jq -r '.services[0].desiredCount')
    running_count=$(echo "$service_info" | jq -r '.services[0].runningCount')
    pending_count=$(echo "$service_info" | jq -r '.services[0].pendingCount')
    
    echo -e "${GREEN}✓${NC} Service status: $service_status"
    echo -e "${GREEN}✓${NC} Desired tasks: $desired_count"
    echo -e "${GREEN}✓${NC} Running tasks: $running_count"
    echo -e "${GREEN}✓${NC} Pending tasks: $pending_count"
    
    # Check deployments
    echo -e "\nChecking deployments..."
    deployments=$(echo "$service_info" | jq -r '.services[0].deployments[]')
    if [ ! -z "$deployments" ]; then
        echo "$deployments" | jq -r '. | "Status: \(.status), Desired: \(.desiredCount), Running: \(.runningCount), Pending: \(.pendingCount)"'
    fi
    
    # Check recent events
    echo -e "\nRecent events:"
    echo "$service_info" | jq -r '.services[0].events[0:3][] | "- \(.createdAt): \(.message)"'
}

# Function to check RDS status with enhanced details
check_rds() {
    print_header "Checking RDS Status"
    
    echo "Checking RDS instance..."
    if ! db_info=$(aws rds describe-db-instances --query 'DBInstances[?DBInstanceIdentifier==`uptime-kuma-db`]' 2>&1); then
        echo -e "${RED}✗ RDS error:${NC}"
        echo "$db_info"
        return 1
    fi
    
    if [ "$db_info" == "[]" ]; then
        echo -e "${RED}✗ RDS instance 'uptime-kuma-db' not found${NC}"
        return 1
    fi
    
    # Extract and display detailed information
    db_status=$(echo "$db_info" | jq -r '.[0].DBInstanceStatus')
    db_endpoint=$(echo "$db_info" | jq -r '.[0].Endpoint.Address')
    db_port=$(echo "$db_info" | jq -r '.[0].Endpoint.Port')
    db_engine=$(echo "$db_info" | jq -r '.[0].Engine')
    db_version=$(echo "$db_info" | jq -r '.[0].EngineVersion')
    
    echo -e "${GREEN}✓${NC} Instance status: $db_status"
    echo -e "${GREEN}✓${NC} Endpoint: $db_endpoint"
    echo -e "${GREEN}✓${NC} Port: $db_port"
    echo -e "${GREEN}✓${NC} Engine: $db_engine $db_version"
    
    # Check if database is accessible (if instance is available)
    if [ "$db_status" == "available" ]; then
        echo -e "\nChecking database connectivity..."
        if nc -z -w5 "$db_endpoint" "$db_port" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Database is accessible"
        else
            echo -e "${RED}✗ Cannot connect to database${NC}"
            echo "This might be due to security group rules or network configuration"
        fi
    fi
}

# Function to check ALB health with detailed target information
check_alb() {
    print_header "Checking Load Balancer Status"
    
    # Get ALB details
    echo "Checking ALB..."
    if ! alb_info=$(aws elbv2 describe-load-balancers --names uptime-kuma-alb 2>&1); then
        echo -e "${RED}✗ ALB error:${NC}"
        echo "$alb_info"
        return 1
    fi
    
    alb_arn=$(echo "$alb_info" | jq -r '.LoadBalancers[0].LoadBalancerArn')
    alb_dns=$(echo "$alb_info" | jq -r '.LoadBalancers[0].DNSName')
    echo -e "${GREEN}✓${NC} ALB DNS: $alb_dns"
    
    # Get target group details
    echo -e "\nChecking target group..."
    if ! tg_info=$(aws elbv2 describe-target-groups --names uptime-kuma-tg 2>&1); then
        echo -e "${RED}✗ Target group error:${NC}"
        echo "$tg_info"
        return 1
    fi
    
    tg_arn=$(echo "$tg_info" | jq -r '.TargetGroups[0].TargetGroupArn')
    
    # Check target health
    echo -e "\nChecking target health..."
    if ! target_health=$(aws elbv2 describe-target-health --target-group-arn "$tg_arn" 2>&1); then
        echo -e "${RED}✗ Target health check error:${NC}"
        echo "$target_health"
        return 1
    fi
    
    echo "$target_health" | jq -r '.TargetHealthDescriptions[] | "Target \(.Target.Id):\n  State: \(.TargetHealth.State)\n  Description: \(.TargetHealth.Description)\n  Reason: \(.TargetHealth.Reason)"'
    
    # Check ALB listener
    echo -e "\nChecking ALB listener..."
    if ! listener_info=$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" 2>&1); then
        echo -e "${RED}✗ Listener error:${NC}"
        echo "$listener_info"
        return 1
    fi
    
    listener_port=$(echo "$listener_info" | jq -r '.Listeners[0].Port')
    listener_protocol=$(echo "$listener_info" | jq -r '.Listeners[0].Protocol')
    echo -e "${GREEN}✓${NC} Listener: $listener_protocol:$listener_port"
}

# Function to check security groups with detailed rules
check_security_groups() {
    print_header "Checking Security Groups"
    
    local groups=(
        "*uptime-kuma-ecs-*:ECS"
        "*uptime-kuma-alb-*:ALB"
        "*uptime-kuma-rds-*:RDS"
    )
    
    for group_info in "${groups[@]}"; do
        group_name="${group_info%%:*}"
        group_type="${group_info#*:}"
        
        echo "Checking $group_type security group ($group_name)..."
        if ! sg_info=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$group_name" --query 'SecurityGroups[0]' 2>&1); then
            echo -e "${RED}✗ Security group error:${NC}"
            echo "$sg_info"
            continue
        fi
        
        sg_id=$(echo "$sg_info" | jq -r '.GroupId')
        if [ -z "$sg_id" ] || [ "$sg_id" == "null" ]; then
            echo -e "${RED}✗ Security group not found${NC}"
            continue
        fi
        
        echo -e "${GREEN}✓${NC} Found security group: $sg_id"
        
        echo "  Inbound rules:"
        if ! inbound_rules=$(echo "$sg_info" | jq -r '.IpPermissions[] | 
            "  - \(.IpProtocol) (\(.FromPort // "*")-\(.ToPort // "*")): \(.IpRanges[].CidrIp // .UserIdGroupPairs[].GroupId)"' 2>/dev/null); then
            echo "    No inbound rules found"
        else
            echo "$inbound_rules"
        fi
        
        echo "  Outbound rules:"
        if ! outbound_rules=$(echo "$sg_info" | jq -r '.IpPermissionsEgress[] | 
            "  - \(.IpProtocol) (\(.FromPort // "*")-\(.ToPort // "*")): \(.IpRanges[].CidrIp // .UserIdGroupPairs[].GroupId)"' 2>/dev/null); then
            echo "    No outbound rules found"
        else
            echo "$outbound_rules"
        fi
        echo
    done
}

# Function to check container logs
check_container_logs() {
    print_header "Checking Container Logs"
    
    echo "DEBUG: =================================================="
    echo "DEBUG: Starting comprehensive container log investigation"
    echo "DEBUG: =================================================="
    
    log_group_name="/ecs/uptime-kuma"
    
    echo "DEBUG: Getting last 50 log events from log group $log_group_name"
    
    # Get all log streams
    echo "DEBUG: Fetching all log streams..."
    if ! all_streams=$(aws logs describe-log-streams \
        --log-group-name "$log_group_name" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[*].logStreamName' \
        --output text 2>&1); then
        echo -e "${RED}✗ Unable to list log streams${NC}"
        echo "DEBUG: Log stream list error: $all_streams"
        return 1
    fi
    
    # Get last 50 events across all streams
    echo "DEBUG: Fetching last 50 events across all streams..."
    if ! log_events=$(aws logs filter-log-events \
        --log-group-name "$log_group_name" \
        --interleaved \
        --query 'events[*].{timestamp:timestamp,message:message}' \
        --output json 2>&1); then
        echo -e "${RED}✗ Unable to fetch logs${NC}"
        echo "DEBUG: Log retrieval error: $log_events"
        return 1
    fi
    
    echo "DEBUG: Processing log events..."
    echo "$log_events" | jq -r 'sort_by(-.timestamp) | limit(50; .[]) | "\(.timestamp | strftime("%Y-%m-%d %H:%M:%S")) \(.message)"' | while IFS= read -r line; do
        if echo "$line" | grep -qi "error\|failed\|fatal\|exception"; then
            echo -e "${RED}$line${NC}"
        else
            echo "$line"
        fi
    done
    
    echo "DEBUG: =================================================="
    echo "DEBUG: Container log investigation complete"
    echo "DEBUG: =================================================="
}

# Function to check task definition
check_task_definition() {
    print_header "Checking Task Definition"
    
    local family="uptime-kuma"
    
    echo "Checking latest task definition..."
    if ! task_def=$(aws ecs describe-task-definition --task-definition "$family" 2>&1); then
        echo -e "${RED}✗ Task definition error:${NC}"
        echo "$task_def"
        return 1
    fi
    
    # Check container definition
    echo -e "\nContainer configuration:"
    container_def=$(echo "$task_def" | jq -r '.taskDefinition.containerDefinitions[0]')
    
    echo -e "${GREEN}✓${NC} Image: $(echo "$container_def" | jq -r .image)"
    echo -e "${GREEN}✓${NC} CPU: $(echo "$task_def" | jq -r '.taskDefinition.cpu')"
    echo -e "${GREEN}✓${NC} Memory: $(echo "$task_def" | jq -r '.taskDefinition.memory')"
    
    # Check environment variables
    echo -e "\nEnvironment variables:"
    echo "$container_def" | jq -r '.environment[] | "  \(.name)=\(.value)"'
    
    # Check port mappings
    echo -e "\nPort mappings:"
    echo "$container_def" | jq -r '.portMappings[] | "  \(.containerPort):\(.hostPort) (\(.protocol))"'
}

# Main function
main() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}   Uptime Kuma Troubleshooting Tool   ${NC}"
    echo -e "${BLUE}======================================${NC}"
    
    local failed=0
    
    check_prerequisites || failed=1
    check_aws_credentials || failed=1
    check_ecr || failed=1
    check_task_definition || failed=1
    check_ecs_service || failed=1
    check_rds || failed=1
    check_alb || failed=1
    check_security_groups || failed=1
    check_container_logs || failed=1
    
    if [ $failed -eq 1 ]; then
        echo -e "\n${RED}Some checks failed. Please review the output above.${NC}"
        exit 1
    else
        echo -e "\n${GREEN}All checks passed successfully!${NC}"
    fi
}

# Run main function
main 