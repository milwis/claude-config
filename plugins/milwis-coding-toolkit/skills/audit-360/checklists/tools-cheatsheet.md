# Tool cheat sheet (reference for specialists during audit)

Each specialist runs a subset of these commands specific to its domain. Loaded on demand by the orchestrator when a specialist asks for tool guidance.

## PHP

```bash
vendor/bin/phpstan analyse --level=max --error-format=json src/
vendor/bin/psalm --taint-analysis --output-format=json
vendor/bin/phpcs --standard=PSR12 src/
vendor/bin/phpmd src/ json codesize,cleancode,design,naming,unusedcode
vendor/bin/rector process --dry-run src/
vendor/bin/phploc src/
semgrep --config=p/php --config=p/owasp-top-ten --config=p/security-audit
composer audit --format=json
gitleaks detect --source . --no-banner
trufflehog filesystem . --only-verified
vendor/bin/phpunit --coverage-clover /tmp/cov.xml --coverage-text
vendor/bin/infection --threads=4 --min-msi=70
vendor/bin/phpcpd src/ --min-lines 5
```

## Python

```bash
ruff check .
mypy --strict .
bandit -r . -ll
pip-audit
pytest --cov --cov-fail-under=80
mutmut run
semgrep --config=p/python --config=p/owasp-top-ten
```

## JavaScript / TypeScript

```bash
npx eslint --ext .js,.mjs,.ts,.tsx --format json .
npm audit --json
npx jscpd public/js/ --reporters json
npx semgrep --config=p/javascript --config=p/xss
npx depcheck
tsc --noEmit
vitest run --coverage --reporter=verbose
```

## Secrets / supply chain

```bash
gitleaks detect --source . -v
trufflehog filesystem . --only-verified
trufflehog git file://./.git --only-verified
```

## MySQL

```bash
mysqldump --no-data --skip-comments <db> > /tmp/schema.sql
mysqldumpslow /var/log/mysql/slow.log | head -30
mysql -e "SELECT digest_text, count_star FROM
  performance_schema.events_statements_summary_by_digest
  ORDER BY count_star DESC LIMIT 30"
```

## PostgreSQL

```bash
pg_dump --schema-only --no-owner <db> > /tmp/schema.sql
psql -c "SELECT * FROM pg_stat_user_indexes WHERE idx_scan = 0;"
psql -c "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) <query>"
```
