FROM node:16-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install -g \
    textlint@12.1.0 \
    textlint-rule-preset-smarthr@1.11.3 \
    textlint-rule-prh@5.3.0 \
    textlint-filter-rule-allowlist@4.0.0 && npm install

USER nobody

ENTRYPOINT ["textlint"]
CMD ["articles/**/*.md"]
