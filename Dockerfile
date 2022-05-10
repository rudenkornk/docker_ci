FROM ubuntu:22.04

USER root
WORKDIR /root

# The image supports several use cases:
#  1. Using it for local testing with mounting of existing repository
#  2. Using it for local testing with downloading repo into container
#  3. Using it in GitHub Actions with its native docker support
#  4. Use it as base image
# The first one should use a normal user with user id matching user id of the host system
# We cannot user root for local testing since it will create its output inaccessible by the host user (unless they summon admin privileges)
# In contrary, native docker support of GitHub Actions CI requires that last USER command is root.
# GitHub Actions do not run any provided entrypoint script, but rather its own, which bootstraps all GitHub's tweaks and tools.
# See also https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions
#
# In order to support these use cases we use the following strategy:
# For the first use case we promise that we run local testing only with "--user ci_user" option and default entrypoint script, which changes ci_user's id
# For the third use case we leave root as the default user for image, and on client side run config script.

# Create new user "ci_user" for local CI
# Temprorarily give ci_user admin privileges
# The latter is needed when "docker run" is used with "--user ci_user" option.
# Without sudo rights, ci_user will not be able to run entrypoint script and change its id
# Use /home/repo as mounting point, instead of home dir, since
# entrypoint script can change ownership of everything in home dir
# Install git for GitHub Actions
RUN : \
  && adduser --disabled-password --gecos "" ci_user \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    sudo \
    git \
  && usermod --append --groups sudo ci_user \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
  && mkdir --parents --mode=777 /home/repo \
  && echo "cd /home/repo" >> /home/ci_user/.profile

WORKDIR /home/repo

# Entrypoint allows to change ci_user's id and removes admin privileges from them
# Copy it to ci_user's directory to allow access both to root and ci_user
# Also copy config_github_actions.sh, which acts like entrypoint on client's side in GitHub Actions
COPY --chown=ci_user \
  license.md \
  readme.md \
  entrypoint.sh \
  entrypoint_usermod.sh \
  entrypoint_continue.sh \
  /home/ci_user/

ENTRYPOINT ["/home/ci_user/entrypoint.sh"]

# See https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.authors="Nikita Rudenko"
LABEL org.opencontainers.image.vendor="Nikita Rudenko"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="Docker image for general CI"
LABEL org.opencontainers.image.base.name="ubuntu:22.04"

ARG IMAGE_NAME
LABEL org.opencontainers.image.ref.name="${IMAGE_NAME}"
LABEL org.opencontainers.image.url="https://hub.docker.com/repository/docker/${IMAGE_NAME}"
LABEL org.opencontainers.image.source="https://github.com/${IMAGE_NAME}"

ARG VERSION
LABEL org.opencontainers.image.version="${VERSION}"

