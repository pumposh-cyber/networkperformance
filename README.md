# Network Performance Monitoring with Grafana Cloud

This repository contains scripts to monitor network performance and system metrics, shipping them to Grafana Cloud.

## Prerequisites

- macOS (tested on macOS with Homebrew)
- Python 3.9+
- Homebrew installed
- Grafana Cloud account

## Setup

### 1. Get Grafana Cloud API Key

1. **Log in to Grafana Cloud**
   - Go to [https://grafana.com](https://grafana.com)
   - Sign in to your account

2. **Navigate to API Keys**
   - Click on your profile icon (top right)
   - Select **"My Account"** or go directly to: [https://grafana.com/orgs/YOUR_ORG/api-keys](https://grafana.com/orgs/YOUR_ORG/api-keys)
   - Replace `YOUR_ORG` with your organization name

3. **Create a New API Key**
   - Click **"Create API Key"** or **"New API Key"**
   - Give it a name (e.g., "Network Monitoring")
   - Select the role: **"MetricsPublisher"** or **"Admin"** (for full access)
   - Set expiration (optional, or leave as "No expiration")
   - Click **"Create"**

4. **Copy the API Key**
   - **Important**: Copy the API key immediately - it will only be shown once!
   - The key will look like: `glc_eyJvIjoi...` (starts with `glc_`)

### 2. Get Your Grafana Cloud Endpoint URLs and IDs

1. **Navigate to Connections**
   - In Grafana Cloud, go to **"Connections"** or **"Integrations"**
   - Or go to: [https://grafana.com/orgs/YOUR_ORG/connections](https://grafana.com/orgs/YOUR_ORG/connections)

2. **Find Prometheus Metrics Endpoint**
   - Look for **"Prometheus"** or **"Metrics"** connection
   - You'll need:
     - **Remote Write URL**: e.g., `https://prometheus-prod-36-prod-us-west-0.grafana.net/api/prom/push`
     - **Instance ID**: e.g., `2847204` (this is the username for basic auth)

3. **Find Loki Logs Endpoint**
   - Look for **"Loki"** or **"Logs"** connection
   - You'll need:
     - **Push URL**: e.g., `https://logs-prod-021.grafana.net/loki/api/v1/push`
     - **Instance ID**: e.g., `1419279` (this is the username for basic auth)

### 3. Set Environment Variables

You have several options to set the environment variables:

#### Option A: Export in Current Shell Session

```bash
export GCLOUD_RW_API_KEY="glc_your_api_key_here"

# Optional: Override defaults if needed
export GCLOUD_HOSTED_METRICS_URL="https://prometheus-prod-36-prod-us-west-0.grafana.net/api/prom/push"
export GCLOUD_HOSTED_METRICS_ID="2847204"
export GCLOUD_HOSTED_LOGS_URL="https://logs-prod-021.grafana.net/loki/api/v1/push"
export GCLOUD_HOSTED_LOGS_ID="1419279"
export GCLOUD_SCRAPE_INTERVAL="60s"
```

#### Option B: Create a `.env` File (Recommended for Development)

1. Create a `.env` file in the project root:
```bash
cat > .env <<EOF
GCLOUD_RW_API_KEY=glc_your_api_key_here
GCLOUD_HOSTED_METRICS_URL=https://prometheus-prod-36-prod-us-west-0.grafana.net/api/prom/push
GCLOUD_HOSTED_METRICS_ID=2847204
GCLOUD_HOSTED_LOGS_URL=https://logs-prod-021.grafana.net/loki/api/v1/push
GCLOUD_HOSTED_LOGS_ID=1419279
GCLOUD_SCRAPE_INTERVAL=60s
EOF
```

2. Source the `.env` file before running scripts:
```bash
source .env
# or
set -a; source .env; set +a
```

**Note**: The `.env` file is already in `.gitignore` and will not be committed to the repository.

#### Option C: Set Inline When Running Script

```bash
GCLOUD_RW_API_KEY="glc_eyJvIjoi..." bash Grafana_OS_monitor.sh
```

#### Option D: Add to Shell Profile (Permanent)

Add to your `~/.zshrc` or `~/.bash_profile`:

```bash
# Grafana Cloud Configuration
export GCLOUD_RW_API_KEY="glc_eyJvIjoi..."
export GCLOUD_HOSTED_METRICS_URL="https://prometheus-prod-36-prod-us-west-0.grafana.net/api/prom/push"
export GCLOUD_HOSTED_METRICS_ID="2847204"
export GCLOUD_HOSTED_LOGS_URL="https://logs-prod-021.grafana.net/loki/api/v1/push"
export GCLOUD_HOSTED_LOGS_ID="1419279"
export GCLOUD_SCRAPE_INTERVAL="60s"
```

Then reload your shell:
```bash
source ~/.zshrc  # or source ~/.bash_profile
```

### 4. Verify Environment Variables

Check that your environment variables are set:

```bash
echo $GCLOUD_RW_API_KEY
echo $GCLOUD_HOSTED_METRICS_URL
echo $GCLOUD_HOSTED_METRICS_ID
```

## Usage

### Install and Configure Grafana Alloy

```bash
# Make sure GCLOUD_RW_API_KEY is set first!
bash Grafana_OS_monitor.sh
```

This script will:
- Install Grafana Alloy via Homebrew
- Configure Alloy to scrape system metrics
- Set up remote write to Grafana Cloud
- Configure log shipping to Loki

### Run Network Speed Exporter

1. **Install Python Dependencies**
```bash
pip3 install -r requirements.txt
```

2. **Start the Exporter**
```bash
python3 exporter.py
```

The exporter will:
- Run speed tests every 60 seconds
- Measure download/upload speeds
- Measure latency, jitter, and packet loss
- Expose metrics on `http://localhost:8000/metrics`

3. **Verify Metrics**
```bash
curl http://localhost:8000/metrics | grep internet_
```

The Alloy service (configured by `Grafana_OS_monitor.sh`) will automatically scrape these metrics and ship them to Grafana Cloud.

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GCLOUD_RW_API_KEY` | **Yes** | None | Grafana Cloud API key (starts with `glc_`) |
| `GCLOUD_HOSTED_METRICS_URL` | No | `https://prometheus-prod-36-prod-us-west-0.grafana.net/api/prom/push` | Prometheus remote write endpoint |
| `GCLOUD_HOSTED_METRICS_ID` | No | `2847204` | Metrics instance ID (username for basic auth) |
| `GCLOUD_HOSTED_LOGS_URL` | No | `https://logs-prod-021.grafana.net/loki/api/v1/push` | Loki push endpoint |
| `GCLOUD_HOSTED_LOGS_ID` | No | `1419279` | Logs instance ID (username for basic auth) |
| `GCLOUD_SCRAPE_INTERVAL` | No | `60s` | Scrape interval for metrics |

## Security Notes

- **Never commit API keys to version control**
- The `.env` file is already in `.gitignore`
- Use environment variables or secure secret management in production
- Rotate API keys regularly
- Use the minimum required permissions for API keys

## Troubleshooting

### Error: "GCLOUD_RW_API_KEY environment variable must be set"

Make sure you've exported the API key:
```bash
export GCLOUD_RW_API_KEY="your_key_here"
```

### Alloy Service Not Starting

Check the logs:
```bash
tail -f /opt/homebrew/var/log/alloy.err.log
```

### Exporter Not Running

Check if the process is running:
```bash
ps aux | grep exporter.py
```

Check the exporter logs:
```bash
tail -f /tmp/exporter.log
```

## Viewing Metrics in Grafana Cloud

1. Log in to [Grafana Cloud](https://grafana.com)
2. Navigate to your Grafana instance
3. Go to **Explore** or create a dashboard
4. Query metrics like:
   - `internet_download_speed_mbps`
   - `internet_upload_speed_mbps`
   - `internet_latency_ms`
   - `node_cpu_seconds_total`
   - `node_memory_total_bytes`

## Support

For issues with:
- **Grafana Cloud**: Check [Grafana Cloud Documentation](https://grafana.com/docs/grafana-cloud/)
- **Alloy**: Check [Alloy Documentation](https://grafana.com/docs/alloy/)
- **This Repository**: Open an issue on GitHub

