ARG BASE_IMAGE=ghcr.io/actions/actions-runner:latest
FROM ${BASE_IMAGE}

# Switch to root to install packages
USER root

# Install additional tools not in the base image
RUN apt-get update && apt-get install -y \
    # Additional CLI tools
    tree \
    htop \
    vim \
    nano \
    rsync \
    # Development tools
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (if not already present)
RUN if ! command -v aws &> /dev/null; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
        unzip awscliv2.zip && \
        ./aws/install && \
        rm -rf aws awscliv2.zip; \
    fi

# Install kubectl (if not already present)
RUN if ! command -v kubectl &> /dev/null; then \
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
        chmod +x kubectl && \
        mv kubectl /usr/local/bin/; \
    fi

# Install Helm (if not already present)
RUN if ! command -v helm &> /dev/null; then \
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
        apt-get update && \
        apt-get install helm -y && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Install Terraform (if not already present)
RUN if ! command -v terraform &> /dev/null; then \
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
        apt-get update && \
        apt-get install terraform -y && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Install additional Python packages
RUN pip3 install --no-cache-dir --user \
    boto3 \
    pytest \
    black \
    flake8 \
    mypy

# Switch back to runner user
USER runner

# The base image already handles runner configuration and startup