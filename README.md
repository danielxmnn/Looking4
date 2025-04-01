# Looking4 Script

## Overview
This Bash script automates the process of subdomain enumeration and analysis using various tools. It collects subdomains, checks their availability, detects technologies, and identifies potential vulnerabilities.

## Features
- **Subdomain Enumeration**: Uses `subfinder`, `assetfinder`, `findomain`, and `amass` to gather subdomains.
- **HTTP/HTTPS Status Checks**: Identifies active subdomains and handles redirects.
- **Technology Detection**: Uses `httpx` to detect web technologies.
- **Vulnerability Scanning**: Runs `nuclei` for common vulnerabilities.
- **Organized Output**: Stores results in a structured directory with filtered lists.

## Requirements
Ensure the following tools are installed before running the script:

- `subfinder`
- `assetfinder`
- `findomain`
- `amass`
- `httpx`
- `nuclei`
- `katana`
- `curl`

You can install them using:
```bash
sudo apt install subfinder assetfinder amass curl
wget https://github.com/findomain/findomain/releases/latest/download/findomain-linux && chmod +x findomain-linux && sudo mv findomain-linux /usr/local/bin/findomain
GO111MODULE=on go get -v github.com/projectdiscovery/httpx/cmd/httpx
GO111MODULE=on go get -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei
GO111MODULE=on go get -v github.com/projectdiscovery/katana/cmd/katana
```

## Usage
Run the script with the following command:
```bash
./l4.sh <domain> [--v]
```
Example:
```bash
./l4.sh example.com --v
```
- `<domain>`: The target domain for subdomain enumeration.
- `--v` (optional): Enables verbose mode for debugging.

## Output
The script creates a directory named `<domain>_result` containing:
- `subdomains_all.txt`: All discovered subdomains.
- `subdomains_active.txt`: Subdomains that responded to HTTP requests.
- `technologies.txt`: Detected technologies.
- `summary.txt`: Overview of the results.
- Other files related to specific tools.

## Notes
- Run the script with proper permissions: `chmod +x script.sh`
- Some tools require API keys for better results (e.g., `amass`, `subfinder`).
- The script is optimized for Linux-based systems.

## License
This project is open-source and available under the MIT License.

