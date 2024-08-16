# Shell Script Automation

This repository provides a simple automation setup for shell scripting, allowing you to automatically source multiple scripts and their functions every time you open a terminal session. The setup involves two scripts: `activate.sh` and `setup.sh`.

## Setup Overview

1. **activate.sh**: This script ensures that the `setup.sh` script is sourced every time your terminal starts by adding the sourcing command to your `~/.zshrc` file.

2. **setup.sh**: This script sources all `.sh` files from the `functions` directory, making their functions available in your terminal session.

## Prerequisites

- **Zsh**: These scripts assume you are using the Zsh shell and have a `.zshrc` file.
- **functions directory**: Place all your `.sh` files containing functions inside a directory named `functions` in the same location as `activate.sh` and `setup.sh`.

## Naming Convention to Avoid Conflicts

To avoid conflicts with other terminal functions, it is important to enforce a naming convention for all custom functions. All function names should start with the prefix `cs_` (short for custom script). This ensures that your functions do not inadvertently override existing terminal commands or functions.

For example:
```bash
cs_my_function() {
    # Function code here
}
```

## How to Use
To automate the process, you only need to run activate.sh once. This will add a command to your .zshrc file to source the setup.sh script every time a new terminal session is started.

```
source activate.sh
```