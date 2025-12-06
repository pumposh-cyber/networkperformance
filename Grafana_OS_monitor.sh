set -x && \
brew install grafana/grafana/alloy && \
ARCH="arm64" && \
GCLOUD_HOSTED_METRICS_URL="${GCLOUD_HOSTED_METRICS_URL:-https://prometheus-prod-36-prod-us-west-0.grafana.net/api/prom/push}" && \
GCLOUD_HOSTED_METRICS_ID="${GCLOUD_HOSTED_METRICS_ID:-2847204}" && \
GCLOUD_SCRAPE_INTERVAL="${GCLOUD_SCRAPE_INTERVAL:-60s}" && \
GCLOUD_HOSTED_LOGS_URL="${GCLOUD_HOSTED_LOGS_URL:-https://logs-prod-021.grafana.net/loki/api/v1/push}" && \
GCLOUD_HOSTED_LOGS_ID="${GCLOUD_HOSTED_LOGS_ID:-1419279}" && \
GCLOUD_RW_API_KEY="${GCLOUD_RW_API_KEY}" && \
if [ -z "$GCLOUD_RW_API_KEY" ]; then \
  echo "Error: GCLOUD_RW_API_KEY environment variable must be set" >&2; \
  exit 1; \
fi && \
curl -fsSL https://storage.googleapis.com/cloud-onboarding/alloy/scripts/install-macos-homebrew.sh | /bin/sh && \
brew services stop alloy && \
CONFIG_PATH=$(brew --prefix)/etc/alloy/config.alloy && \
rm -f $CONFIG_PATH && \
mkdir -p $(dirname $CONFIG_PATH) && \
cat > $CONFIG_PATH <<EOF
prometheus.exporter.self "alloy_check" { }

discovery.relabel "alloy_check" {
  targets = prometheus.exporter.self.alloy_check.targets

  rule {
    target_label = "instance"
    replacement  = constants.hostname
  }

  rule {
    target_label = "alloy_hostname"
    replacement  = constants.hostname
  }

  rule {
    target_label = "job"
    replacement  = "integrations/alloy-check"
  }
}

prometheus.scrape "alloy_check" {
  targets    = discovery.relabel.alloy_check.output
  forward_to = [prometheus.relabel.alloy_check.receiver]

  scrape_interval = "60s"
}

prometheus.relabel "alloy_check" {
  forward_to = [prometheus.remote_write.metrics_service.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "(prometheus_target_sync_length_seconds_sum|prometheus_target_scrapes_.*|prometheus_target_interval.*|prometheus_sd_discovered_targets|alloy_build.*|prometheus_remote_write_wal_samples_appended_total|process_start_time_seconds)"
    action        = "keep"
  }
}

prometheus.remote_write "metrics_service" {
  endpoint {
    url = "${GCLOUD_HOSTED_METRICS_URL}"

    basic_auth {
      username = "${GCLOUD_HOSTED_METRICS_ID}"
      password = "${GCLOUD_RW_API_KEY}"
    }
  }
}

loki.write "grafana_cloud_loki" {
  endpoint {
    url = "${GCLOUD_HOSTED_LOGS_URL}"

    basic_auth {
      username = "${GCLOUD_HOSTED_LOGS_ID}"
      password = "${GCLOUD_RW_API_KEY}"
    }
  }
}

prometheus.exporter.unix "integrations_node_exporter" { }

discovery.relabel "integrations_node_exporter" {
	targets = prometheus.exporter.unix.integrations_node_exporter.targets

	rule {
		target_label = "instance"
		replacement  = constants.hostname
	}

	rule {
		target_label = "job"
		replacement  = "integrations/macos-node"
	}
}

prometheus.scrape "integrations_node_exporter" {
	targets    = discovery.relabel.integrations_node_exporter.output
	forward_to = [prometheus.relabel.integrations_node_exporter.receiver]
	job_name   = "integrations/node_exporter"
}

prometheus.relabel "integrations_node_exporter" {
	forward_to = [prometheus.remote_write.metrics_service.receiver]

	rule {
		source_labels = ["__name__"]
		regex         = "up|node_boot_time_seconds|node_cpu_seconds_total|node_disk_io_time_seconds_total|node_disk_read_bytes_total|node_disk_written_bytes_total|node_filesystem_avail_bytes|node_filesystem_files|node_filesystem_files_free|node_filesystem_readonly|node_filesystem_size_bytes|node_load1|node_load15|node_load5|node_memory_compressed_bytes|node_memory_internal_bytes|node_memory_purgeable_bytes|node_memory_swap_total_bytes|node_memory_swap_used_bytes|node_memory_total_bytes|node_memory_wired_bytes|node_network_receive_bytes_total|node_network_receive_drop_total|node_network_receive_errs_total|node_network_receive_packets_total|node_network_transmit_bytes_total|node_network_transmit_drop_total|node_network_transmit_errs_total|node_network_transmit_packets_total|node_os_info|node_textfile_scrape_error|node_uname_info"
		action        = "keep"
	}
}

local.file_match "logs_integrations_integrations_node_exporter_direct_scrape" {
	path_targets = [{
		__address__ = "localhost",
		__path__    = "/var/log/*.log",
		instance    = constants.hostname,
		job         = "integrations/macos-node",
	}]
}

loki.process "logs_integrations_integrations_node_exporter_direct_scrape" {
	forward_to = [loki.write.grafana_cloud_loki.receiver]

	stage.multiline {
		firstline     = "^([\\w]{3} )?[\\w]{3} +[\\d]+ [\\d]+:[\\d]+:[\\d]+|[\\w]{4}-[\\w]{2}-[\\w]{2} [\\w]{2}:[\\w]{2}:[\\w]{2}(?:[+-][\\w]{2})?"
		max_lines     = 0
		max_wait_time = "10s"
	}

	stage.regex {
		expression = "(?P<timestamp>([\\w]{3} )?[\\w]{3} +[\\d]+ [\\d]+:[\\d]+:[\\d]+|[\\w]{4}-[\\w]{2}-[\\w]{2} [\\w]{2}:[\\w]{2}:[\\w]{2}(?:[+-][\\w]{2})?) (?P<hostname>\\S+) (?P<sender>.+?)\\[(?P<pid>\\d+)\\]:? (?P<message>(?s:.*))$"
	}

	stage.labels {
		values = {
			hostname = null,
			pid      = null,
			sender   = null,
		}
	}

	stage.match {
		selector = "{sender!=\"\", pid!=\"\"}"

		stage.template {
			source   = "message"
			template = "{{ .sender }}[{{ .pid }}]: {{ .message }}"
		}

		stage.label_drop {
			values = ["pid"]
		}

		stage.output {
			source = "message"
		}
	}
}

loki.source.file "logs_integrations_integrations_node_exporter_direct_scrape" {
	targets    = local.file_match.logs_integrations_integrations_node_exporter_direct_scrape.targets
	forward_to = [loki.process.logs_integrations_integrations_node_exporter_direct_scrape.receiver]
}
EOF
brew services start alloy && brew services restart alloy