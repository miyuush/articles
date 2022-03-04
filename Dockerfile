FROM node:16-alpine

WORKDIR /app

COPY . .

RUN npm install -g \
    textlint@12.1.0 \
    textlint-rule-preset-smarthr \
    textlint-rule-prh \
    textlint-filter-rule-allowlist && npm install

USER nobody

ENTRYPOINT ["textlint"]
CMD ["articles/**/*.md"]
