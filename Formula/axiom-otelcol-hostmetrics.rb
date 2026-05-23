class AxiomOtelcolHostmetrics < Formula
  desc "Ship host metrics to Axiom via OpenTelemetry Collector"
  homepage "https://opentelemetry.io"
  version "0.152.1"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/otelcol-contrib_#{version}_darwin_arm64.tar.gz"
      sha256 "32778c05c60d1387ef90fb0e576d0a27c8197e52a82d57caeacea98c9b532161"
    end
    on_intel do
      url "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/otelcol-contrib_#{version}_darwin_amd64.tar.gz"
      sha256 "6e5127fc74c0b4b302c9f1149edcc3a47f6644fe201f8c1d7a8ebeea21525683"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/otelcol-contrib_#{version}_linux_arm64.tar.gz"
      sha256 "d427f97da8f4e2a867042dc6016d979b481404c1e5b3446c667c6202b5866f4b"
    end
    on_intel do
      url "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/otelcol-contrib_#{version}_linux_amd64.tar.gz"
      sha256 "3de9fa228d52aedae0a0341bc3bf78a90f9e319c9615066a75dcf27cd7e8bab5"
    end
  end

  def install
    bin.install "otelcol-contrib" => "axiom-otelcol-hostmetrics"
    (etc/"axiom-otelcol-hostmetrics").mkpath

    full_name = "axiomhq/tap/axiom-otelcol-hostmetrics"

    (bin/"axiom-otelcol-hostmetrics-setup").write <<~SH
      #!/usr/bin/env bash
      set -euo pipefail
      CFG="#{etc}/axiom-otelcol-hostmetrics/config.yaml"
      FORMULA="#{full_name}"

      mkdir -p $(dirname "$CFG")

      read -rp  "Axiom dataset name: " DATASET
      read -rsp "Axiom API token (xaat-...): " TOKEN; echo
      read -rp  "Axiom edge deployment (e.g. us-east-1.aws.edge.axiom.co): " ENDPOINT

      umask 077
      cat > "$CFG" <<YAML
      receivers:
        hostmetrics:
          collection_interval: 10s
          scrapers: { cpu:, memory:, load:, disk:, filesystem:, network:, paging:, processes: }
      processors:
        resourcedetection: { detectors: [system, env] }
        batch:
      exporters:
        otlphttp/axiom:
          endpoint: https://${ENDPOINT}
          headers:
            authorization: "Bearer ${TOKEN}"
            x-axiom-dataset: "${DATASET}"
      service:
        pipelines:
          metrics:
            receivers: [hostmetrics]
            processors: [resourcedetection, batch]
            exporters: [otlphttp/axiom]
      YAML
      echo "Wrote $CFG"

      echo "(Re)starting $FORMULA..."
      brew services restart "$FORMULA"
    SH
    chmod 0755, bin/"axiom-otelcol-hostmetrics-setup"
  end

  def caveats
    <<~EOS
      Run the one-time setup to configure Axiom and start the collector:

        axiom-otelcol-hostmetrics-setup
    EOS
  end

  service do
    run [opt_bin/"axiom-otelcol-hostmetrics", "--config", etc/"axiom-otelcol-hostmetrics/config.yaml"]
    keep_alive true
    log_path       var/"log/axiom-otelcol-hostmetrics.log"
    error_log_path var/"log/axiom-otelcol-hostmetrics.log"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/axiom-otelcol-hostmetrics --version")
  end
end
