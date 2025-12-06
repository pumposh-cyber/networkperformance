import time
import platform
import subprocess
import speedtest
from tcp_latency import measure_latency
from prometheus_client import start_http_server, Gauge

# Create Prometheus gauges for the metrics we want to export
DOWNLOAD_SPEED = Gauge('internet_download_speed_mbps', 'Download speed in Mbps', ['ssid'])
UPLOAD_SPEED = Gauge('internet_upload_speed_mbps', 'Upload speed in Mbps', ['ssid'])
LATENCY = Gauge('internet_latency_ms', 'Latency in ms', ['ssid'])
JITTER = Gauge('internet_jitter_ms', 'Jitter in ms', ['ssid'])
PACKET_LOSS = Gauge('internet_packet_loss_percent', 'Packet loss in percent', ['ssid'])

def get_wifi_ssid():
    """Gets the SSID of the currently connected WiFi network."""
    os_name = platform.system()
    try:
        if os_name == "Windows":
            command = "netsh wlan show interfaces | findstr SSID"
            result = subprocess.check_output(command, shell=True, text=True)
            ssid = result.split(":")[1].strip()
        elif os_name == "Linux":
            command = "iwgetid -r"
            ssid = subprocess.check_output(command, shell=True, text=True).strip()
        elif os_name == "Darwin":
            command = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk -F': ' '/ SSID/{print $2}'"
            ssid = subprocess.check_output(command, shell=True, text=True).strip()
        else:
            ssid = "Unknown"
    except (subprocess.CalledProcessError, FileNotFoundError):
        ssid = "Unknown"
    return ssid

def get_internet_speed(ssid):
    """Measures internet speed and updates Prometheus gauges."""
    st = speedtest.Speedtest()
    st.get_best_server()
    download_speed = st.download() / 1_000_000  # Convert to Mbps
    upload_speed = st.upload() / 1_000_000  # Convert to Mbps
    DOWNLOAD_SPEED.labels(ssid=ssid).set(download_speed)
    UPLOAD_SPEED.labels(ssid=ssid).set(upload_speed)
    print(f"Download: {download_speed:.2f} Mbps, Upload: {upload_speed:.2f} Mbps")

def get_network_quality(ssid):
    """Measures network quality and updates Prometheus gauges."""
    latency_measurements = measure_latency(host='google.com', port=80, runs=10, timeout=2.5)

    if latency_measurements:
        # Filter out None values before calculations
        valid_measurements = [m for m in latency_measurements if m is not None]

        if valid_measurements:
            latency = sum(valid_measurements) / len(valid_measurements)
            jitter = max(valid_measurements) - min(valid_measurements)
            packet_loss = (1 - len(valid_measurements) / len(latency_measurements)) * 100

            LATENCY.labels(ssid=ssid).set(latency)
            JITTER.labels(ssid=ssid).set(jitter)
            PACKET_LOSS.labels(ssid=ssid).set(packet_loss)
            print(f"Latency: {latency:.2f} ms, Jitter: {jitter:.2f} ms, Packet Loss: {packet_loss:.2f}%")
        else:
            print("No valid latency measurements obtained.")
    else:
        print("Could not measure latency.")

def main():
    """Main function to start the exporter."""
    start_http_server(8000)
    print("Exporter is running on port 8000")

    while True:
        ssid = get_wifi_ssid()
        get_internet_speed(ssid)
        get_network_quality(ssid)
        time.sleep(60)

if __name__ == '__main__':
    main()
