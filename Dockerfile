FROM alpine:3.8

RUN apk add --no-cache build-base ruby-dev=2.5.1-r2 zlib-dev=1.2.11-r1 nodejs=8.11.4-r0
RUN echo "gem: --no-rdoc --no-ri" > /etc/gemrc
RUN gem install bundler

WORKDIR /mnt
COPY Gemfile /mnt/Gemfile
COPY Gemfile.lock /mnt/Gemfile.lock
RUN bundle


EXPOSE 4000
ENTRYPOINT ["sh"]
CMD ["-c", "bundle exec jekyll serve -w"]