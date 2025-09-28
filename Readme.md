# GitHub Self-Hosted Runner Setup (Scale-Friendly)

This Docker Compose setup provides self-hosted GitHub Actions runners using **official GitHub images** with easy scaling and multiple deployment profiles.

## 🚀 Key Improvements

- ✅ **Official Images**: Uses `ghcr.io/actions/actions-runner:latest`
- ✅ **Auto-Scaling**: Docker Compose native scaling with `docker-compose up --scale`
- ✅ **Profiles**: Different deployment configurations (basic, enhanced, cache, monitoring)
- ✅ **Management Script**: Easy CLI for common operations
- ✅ **Health Checks**: Built-in container health monitoring
- ✅ **Resource Limits**: Configurable CPU/memory constraints

## 📋 Available Profiles

| Profile | Description | Services |
|---------|-------------|----------|
| `default` | Basic runners only | Standard GitHub runners |
| `enhanced` | Extra tools included | Runners + AWS CLI, kubectl, Helm, etc. |
| `cache` | Docker registry cache | Runners + Registry mirror |
| `monitoring` | Management dashboard | Runners + Portainer |
| `all` | Everything enabled | All services |

## 🛠 Quick Start

### 1. Setup Environment
```bash
# Copy environment template
cp .env.example .env

# Edit with your GitHub details
vim .env
```

Required `.env` content:
```bash
GITHUB_OWNER=your-github-username
GITHUB_REPOSITORY=your-repo-name  # Optional for org runners
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

### 2. Start Runners

**Using the management script (recommended):**
```bash
# Make script executable
chmod +x runner-manager.sh

# Start 3 basic runners
./runner-manager.sh start 3

# Start 5 enhanced runners with cache
./runner-manager.sh start 5 --profile enhanced,cache

# Start with all features
./runner-manager.sh start 2 --profile all
```

**Using Docker Compose directly:**
```bash
# Start 2 basic runners
docker-compose up -d --scale github-runner=2

# Start with enhanced profile
docker-compose --profile enhanced up -d --scale github-runner=3

# Start everything
docker-compose --profile all up -d --scale github-runner=5
```

## 🎛 Management Commands

### Scaling Operations
```bash
# Scale to 10 runners
./runner-manager.sh scale 10

# Check current status
./runner-manager.sh status

# Restart with different count
./runner-manager.sh restart 5
```

### Monitoring & Logs
```bash
# View all logs
./runner-manager.sh logs

# View specific service logs
./runner-manager.sh logs github-runner

# Show runner status and resource usage
./runner-manager.sh status
```

### Maintenance
```bash
# Stop all runners
./runner-manager.sh stop

# Clean up resources
./runner-manager.sh clean

# List available profiles
./runner-manager.sh profiles
```

## 🏗 Architecture Comparison

### Official Images vs Custom Build

**✅ Using Official Images (Current Approach):**
- Faster startup (no build time)
- Always up-to-date with GitHub
- Smaller maintenance overhead
- Trusted and secure base
- Automatic updates available

**❌ Custom Build (Previous Approach):**
- Longer initial setup
- Manual updates required
- Larger attack surface
- More maintenance needed

### When to Use Enhanced Profile

**Use Enhanced Profile When You Need:**
- AWS CLI for cloud deployments
- kubectl for Kubernetes operations  
- Helm for Kubernetes package management
- Terraform for infrastructure as code
- Additional development tools

**Stick with Default Profile When:**
- Basic Docker builds are sufficient
- Minimizing resource usage
- Faster container startup needed
- Simple CI/CD workflows

## 🔧 Configuration Options

### Environment Variables

```bash
# Required
GITHUB_OWNER=myusername           # GitHub user/org
GITHUB_TOKEN=ghp_abc123           # PAT token

# Optional
GITHUB_REPOSITORY=myrepo          # Leave empty for org runners
RUNNER_LABELS=custom,labels       # Custom runner labels
RUNNER_NAME_PREFIX=my-runner      # Runner name prefix
RUNNER_GROUP=production           # Runner group
DISABLE_AUTO_UPDATE=false         # Disable runner auto-updates

# Docker Hub (for registry cache)
DOCKER_HUB_USERNAME=user          # Optional
DOCKER_HUB_PASSWORD=pass          # Optional
```

### Resource Limits

Modify in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'      # Max 4 CPU cores
      memory: 8G       # Max 8GB RAM
    reservations:
      cpus: '1.0'      # Reserve 1 core
      memory: 2G       # Reserve 2GB RAM
```

## 📊 Scaling Strategies

### Horizontal Scaling
```bash
# Scale based on workload
./runner-manager.sh scale 20    # Heavy workload
./runner-manager.sh scale 5     # Normal workload  
./runner-manager.sh scale 1     # Light workload
```

### Auto-scaling with External Tools

**Using Docker Swarm:**
```bash
# Deploy as Docker service
docker service create \
  --replicas 5 \
  --name github-runners \
  ghcr.io/actions/actions-runner:latest
```

**Using Kubernetes:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runners
spec:
  replicas: 10
  selector:
    matchLabels:
      app: github-runner
  template:
    spec:
      containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:latest
```

## 🔍 Monitoring & Health Checks

### Built-in Health Checks
```bash
# Check runner health
docker-compose ps

# View health status
docker inspect $(docker-compose ps -q) | jq '.[].State.Health'
```

### External Monitoring

**Prometheus + Grafana** (with monitoring profile):
```bash
# Start with monitoring
./runner-manager.sh start 3 --profile monitoring

# Access Portainer
open http://localhost:9000
```

## 🛡 Security Best Practices

### GitHub Token Permissions
Minimum required scopes:
- `repo` - Repository access
- `admin:org` - Organization runner management
- `workflow` - Workflow management

### Container Security
- Runs as non-root user (1001:123)
- No privileged mode required
- Minimal attack surface with official images
- Automatic security updates from GitHub

### Network Security
```yaml
networks:
  runner-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16    # Isolated network
```

## 📈 Performance Optimization

### Registry Cache
Enable Docker registry cache for faster builds:
```bash
./runner-manager.sh start 5 --profile cache
```

Configure in workflows:
```yaml
- name: Configure Docker cache
  run: |
    echo '{"registry-mirrors":["http://registry-cache:5000"]}' | \
    sudo tee /etc/docker/daemon.json
```

### Build Cache Volumes
```yaml
volumes:
  - docker_cache:/var/lib/docker
  - build_cache:/tmp/buildkit-cache
```

## 🐛 Troubleshooting

### Common Issues

**Runners not appearing in GitHub:**
```bash
# Check logs
./runner-manager.sh logs github-runner

# Verify environment
source .env && echo "Owner: $GITHUB_OWNER, Token: ${GITHUB_TOKEN:0:8}..."
```

**Docker permission denied:**
```bash
# Check Docker socket permissions
ls -la /var/run/docker.sock

# Add user to docker group (on host)
sudo usermod -aG docker $USER
```

**Out of resources:**
```bash
# Check system resources
docker system df
./runner-manager.sh status

# Clean up
./runner-manager.sh clean
```

### Debug Mode
```bash
# Enable debug logging
export ACTIONS_RUNNER_DEBUG=true
./runner-manager.sh restart 1
```

## 🔄 Updates & Maintenance

### Update Runner Images
```bash
# Pull latest images
docker-compose pull

# Restart with latest
./runner-manager.sh restart 5
```

### Automated Updates
```bash
# Add to crontab for daily updates
0 2 * * * cd /path/to/runners && docker-compose pull && ./runner-manager.sh restart 5
```

## 📝 Usage in Workflows

### Basic Usage
```yaml
name: CI
on: [push]
jobs:
  build:
    runs-on: [self-hosted, linux]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: docker build -t myapp .
```

### With Custom Labels
```yaml
jobs:
  deploy:
    runs-on: [self-hosted, enhanced]  # Uses enhanced runners
    steps:
      - name: Deploy with kubectl
        run: kubectl apply -f k8s/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes to `docker-compose.yml` or `runner-manager.sh`
4. Test with `./runner-manager.sh start 1`
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.