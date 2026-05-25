.PHONY: install test run lint clean

install:
	poetry install

run:
	poetry run python src/main.py

test:
	poetry run pytest

lint:
	poetry run black .

clean:
	rm -rf __pycache__ .pytest_cache dist/ *.egg-info/