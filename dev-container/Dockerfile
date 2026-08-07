FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl ca-certificates git openssh-client sudo bash jq iputils-ping make \
  && rm -rf /var/lib/apt/lists/*


# install vim
RUN apt-get update && apt-get install -y vim neovim

# install golang
RUN curl -fsSL https://go.dev/dl/go1.26.2.linux-amd64.tar.gz -o /tmp/go.tar.gz \
      && rm -rf /usr/local/go \
      && tar -C /usr/local -xzf /tmp/go.tar.gz \
      && rm /tmp/go.tar.gz

# install Node.js (required for MCP servers)
RUN curl -fsSL https://deb.nodesource.com/setup_26.x | bash - \
  && apt-get update && apt-get install -y nodejs


# install playwright
RUN npm i -g @playwright/cli@latest

RUN apt-get update && apt-get  install -y sudo
RUN echo '%ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu

USER ubuntu
WORKDIR /home/ubuntu
ENV HOME=/home/ubuntu

# install opencode
RUN curl -fsSL https://opencode.ai/install | bash

# install claude code
RUN curl -fsSL https://claude.ai/install.sh | bash

# ensure opencode, go, and go tools on PATH for non-login shells
ENV PATH=/home/ubuntu/.opencode/bin:/home/ubuntu/go/bin:/usr/local/go/bin:/home/ubuntu/.local/bin:$PATH

# Install Go development tools as the ubuntu user so they land in ~/go/bin
RUN go install golang.org/x/tools/gopls@latest && \
    go install github.com/go-delve/delve/cmd/dlv@latest && \
    go install golang.org/x/tools/cmd/goimports@latest && \
    go install honnef.co/go/tools/cmd/staticcheck@latest && \
    curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $(go env GOPATH)/bin v2.12.2

RUN mkdir -p /home/ubuntu/.opencode && chmod -R u+w /home/ubuntu/.opencode
RUN mkdir -p /home/ubuntu/.config && chmod -R u+w /home/ubuntu/.config
RUN mkdir -p /home/ubuntu/.local/share && chmod -R u+w /home/ubuntu/.local

# The inner Docker daemon (installed below) is the precondition for the
# per-worktree dev stack at dev-container-inner/ — required when running tests
# under .worktrees/<name>/. See dev-container-inner/AGENTS.md.
# Install Docker
RUN curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
RUN sudo usermod -aG docker ubuntu
RUN sudo systemctl enable docker

# install codegraph
RUN curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
RUN codegraph install -t opencode -y

COPY --chmod=775 entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


