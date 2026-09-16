FROM ruby:3.4-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev libsqlite3-dev pkg-config && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 4.0.10 --no-document
ENV BUNDLE_WITHOUT=development:test BUNDLE_DEPLOYMENT=true
RUN bundle install

FROM ruby:3.4-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 libsqlite3-0 ca-certificates && rm -rf /var/lib/apt/lists/* && useradd --create-home app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .
ENV RACK_ENV=production APP_ENV=production PORT=8000 BUNDLE_WITHOUT=development:test BUNDLE_DEPLOYMENT=true
USER app
EXPOSE 8000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "config.ru"]
