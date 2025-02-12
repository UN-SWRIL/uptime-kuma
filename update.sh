#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Forcing new ECS deployment...${NC}"

# Force new deployment
aws ecs update-service \
    --cluster uptime-kuma-cluster \
    --service uptime-kuma \
    --force-new-deployment

# Wait for deployment to complete
echo -e "${YELLOW}Waiting for deployment to stabilize...${NC}"
aws ecs wait services-stable \
    --cluster uptime-kuma-cluster \
    --services uptime-kuma

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Deployment completed successfully!${NC}"
else
    echo -e "\033[0;31mDeployment failed to stabilize${NC}"
    exit 1
fi

# Show latest deployment status
echo -e "${YELLOW}Current deployment status:${NC}"
aws ecs describe-services \
    --cluster uptime-kuma-cluster \
    --services uptime-kuma \
    --query 'services[0].deployments[*].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Failed:failedTasks}' \
    --output table 