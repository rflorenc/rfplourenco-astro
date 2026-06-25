.PHONY: dev build preview publish clean new-post new-project

dev:
	npm run dev

build:
	npm run build

preview: build
	npm run preview

publish:
	git add -A
	git diff --cached --quiet && echo "Nothing to publish." || \
		(git commit -m "Update site content" && git push)

clean:
	rm -rf dist/ .astro/

new-post:
	@test -n "$(SLUG)" || (echo "Usage: make new-post SLUG=my-post-title" && exit 1)
	@mkdir -p src/content/blog
	@echo '---' > src/content/blog/$(SLUG).md
	@echo 'title: ""' >> src/content/blog/$(SLUG).md
	@echo 'description: ""' >> src/content/blog/$(SLUG).md
	@echo 'date: $(shell date +%Y-%m-%d)' >> src/content/blog/$(SLUG).md
	@echo 'tags: []' >> src/content/blog/$(SLUG).md
	@echo '---' >> src/content/blog/$(SLUG).md
	@echo "" >> src/content/blog/$(SLUG).md
	@echo "Created src/content/blog/$(SLUG).md"

new-project:
	@test -n "$(SLUG)" || (echo "Usage: make new-project SLUG=my-project" && exit 1)
	@mkdir -p src/content/projects
	@echo '---' > src/content/projects/$(SLUG).md
	@echo 'title: ""' >> src/content/projects/$(SLUG).md
	@echo 'description: ""' >> src/content/projects/$(SLUG).md
	@echo 'tech: []' >> src/content/projects/$(SLUG).md
	@echo 'repo: ""' >> src/content/projects/$(SLUG).md
	@echo 'order: 0' >> src/content/projects/$(SLUG).md
	@echo '---' >> src/content/projects/$(SLUG).md
	@echo "Created src/content/projects/$(SLUG).md"

help:
	@echo "make dev          - Start dev server"
	@echo "make build        - Build static site"
	@echo "make preview      - Build and preview locally"
	@echo "make publish      - Commit and push to deploy"
	@echo "make clean        - Remove build artifacts"
	@echo "make new-post     - Scaffold blog post  (SLUG=my-post)"
	@echo "make new-project  - Scaffold project    (SLUG=my-project)"
