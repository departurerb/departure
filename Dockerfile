FROM ruby:3.0
MAINTAINER muffinista@gmail.com

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y \
  build-essential \
  percona-toolkit

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir -p /app /app/lib/departure
WORKDIR /app

# Install bundler - dependencies will be installed via volume mount
RUN gem install bundler

# Project root will be mounted as volume for live development

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
#CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
