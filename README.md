# spacelift-env-manager 🚀

A secure, local-first CLI toolkit for bulk-migrating environment variables and secrets into Spacelift Stacks or Contexts. 

This tool solves the "Environment Variable Tax"—the tedious process of manually entering dozens of variables into the Spacelift UI—while ensuring your sensitive data never leaves your local machine.

## 🛡️ Why Use This?

* **No "Click-Ops":** Stop copy-pasting 50+ variables into a UI one by one.
* **Local-First Security:** Your secrets stay on your machine. Never paste sensitive `.env` files into an LLM (like Claude or ChatGPT) to generate commands; this script runs entirely in your local shell.
* **Smart Secret Detection:** Automatically scans for keywords like `password`, `token`, and `secret` to toggle Spacelift's `--write-only` flag automatically.
* **Data Sanitization:** Handles shell quotes, trailing spaces, and invalid formatting that often break Terraform plans.

## 📋 Prerequisites

* **spacectl:** [Installed](https://github.com/spacelift-io/spacectl) and configured.
* **Authentication:** You must be logged in via `spacectl profile login`.
* **Environment File:** A standard `.env` file with `KEY=VALUE` pairs.

## 🚀 Quick Start

### 1. Installation
Clone this repository and make the script executable:
```bash
git clone https://github.com/YOUR_USERNAME/spacelift-env-manager.git
cd spacelift-env-manager
chmod +x spacelift-env.sh
```

### 2. Validate your .env file
Ensure your file is formatted correctly before pushing:
```bash
./spacelift-env.sh validate-file variables.env
```

### 3. Bulk Upload to a Stack
Push all variables from your file directly to a specific Spacelift Stack ID:
```bash
./spacelift-env.sh add-vars <STACK_ID> <ENV_FILE>
```

## 🛠️ Commands

| Command | Description |
| :--- | :--- |
| `add-vars` | Parses a `.env` file and pushes variables to Spacelift. |
| `list-stacks` | Lists all available Stacks in your current Spacelift account. |
| `list-files` | Scans the current directory for available `.env` files. |
| `validate-file` | Checks for formatting errors without pushing data. |

## 🔒 Security & Logic

* **Auto-Shielding:** Any variable containing `password`, `secret`, or `token` in the key name is automatically marked as **Write-Only** in Spacelift.
* **Quote Stripping:** Automatically handles both `"value"` and `'value'` formats to prevent Terraform provider syntax errors.
* **Clean Parsing:** Skips comments (`#`) and empty lines automatically to prevent corrupted imports.


