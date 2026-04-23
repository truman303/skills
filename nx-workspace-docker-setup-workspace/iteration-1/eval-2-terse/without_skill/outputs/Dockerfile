# Dev container image with both Node.js (for Nx / Angular) and the .NET SDK
# so we can run `nx` and `dotnet` side-by-side without installing anything
# on the host machine.

FROM mcr.microsoft.com/dotnet/sdk:8.0

ARG NODE_MAJOR=20

# Install Node.js + a few QoL tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates git \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Nx globally so `nx ...` works from any shell in the container.
RUN npm install -g nx@latest

WORKDIR /workspace

# Angular dev server (4200) + typical ASP.NET Core dev ports (5000/5001/7000/7001)
EXPOSE 4200 5000 5001 7000 7001

CMD ["bash"]
