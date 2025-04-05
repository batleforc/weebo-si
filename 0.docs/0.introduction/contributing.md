# Contributing

## Pre-requisites

- [Cocogitto](https://github.com/cocogitto/cocogitto)
- [Python](https://www.python.org/downloads/)
- [Taskfile](https://taskfile.dev/#/installation)
- [A good text editor](https://code.visualstudio.com/)
- [Git](https://git-scm.com/downloads)

Before any contribution, please execute the following commands to ensure that the code is correctly formatted and that all tests pass:

```bash
# Create a virtual environment for the project
task init:init-venv
# Install Ansible and all dependencies in the 0.ansible/requirements.txt file
task init:install-ansible
# Install all needed dependencies for the project and check versions
task init:install-cli
# Install git hooks defined in the cog.toml file
task init:install-hook
```
