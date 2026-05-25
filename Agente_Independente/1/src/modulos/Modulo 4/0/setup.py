from setuptools import setup, find_packages

setup(
    name="modulo4-expert",
    version="1.0.0",
    packages=find_packages("src"),
    package_dir={"": "src"},
    install_requires=[
        "pydantic>=2.0",
        "jinja2>=3.0",
    ],
    python_requires=">=3.10",
)