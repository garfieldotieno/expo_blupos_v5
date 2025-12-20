#!/usr/bin/env python

from setuptools import setup

def get_version():
    """Get version."""
    with open("backend.py", "r") as f:
        for line in f:
            if line.startswith("__version__"):
                return line.split("=")[1].strip().strip('"')

setup(
    name="expo_blupos_v5",
    version=get_version(),
    description="Point of Sale system",
    author="Garfield Otieno",
    packages=['.'],  # Install the current directory as a package
    include_package_data=True,
    install_requires=[
        # Add your dependencies here
    ],
    entry_points={
        'console_scripts': [
            'expo_blupos_v5=backend:run_heroku_mode',
        ],
    },
)
