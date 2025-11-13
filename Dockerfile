# syntax = docker/dockerfile:1

# Adjust NODE_VERSION as desired
ARG NODE_VERSION=22.21.1
FROM node:${NODE_VERSION}-slim AS base

LABEL fly_launch_runtime="Node.js"

# Node.js app lives here
WORKDIR /app

# Set production environment by default (will override in build stage)
ENV NODE_ENV="production"

# Install pnpm
ARG PNPM_VERSION=latest
RUN npm install -g pnpm@$PNPM_VERSION


# Throw-away build stage to reduce size of final image
FROM base AS build

# For the build, we want devDependencies too
ENV NODE_ENV="development"

# Install packages needed to build node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      node-gyp \
      pkg-config \
      python-is-python3 && \
    rm -rf /var/lib/apt/lists/*

# Copy the entire repo so pnpm can see the workspace (pnpm-workspace.yaml, packages/*, etc.)
# .dockerignore will ensure node_modules and other junk are not copied.
COPY . .

# Install all dependencies (including devDependencies) for the whole workspace
RUN pnpm install --frozen-lockfile --prod=false

# Build application (this runs: pnpm --filter=@plebeian/app run build -> vite build)
RUN pnpm run build

# Prune dev dependencies to keep final image small
RUN pnpm prune --prod


# Final stage for app image
FROM base

# Final runtime is production
ENV NODE_ENV="production"

# Copy built application (including production node_modules) from build stage
COPY --from=build /app /app

# Expose port and start the server
EXPOSE 3000
CMD [ "node", "index.js" ]
