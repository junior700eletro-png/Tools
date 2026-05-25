# Path: modulo 3/0/setup.py
from setuptools import setup, find_packages

setup(
    name="modulo3_orquestrador_autonomo",
    version="1.0.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    description="Orquestrador Autonomo para Modulo 3",
    author="User",
    python_requires=">=3.8",
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
    ],
)