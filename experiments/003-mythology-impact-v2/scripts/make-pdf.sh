#!/usr/bin/env bash
set -euo pipefail

# Convert report.md → report.pdf via weasyprint.
# Usage: ./scripts/make-pdf.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT/report"
MD="$REPORT_DIR/report.md"
HTML="$REPORT_DIR/report.html"
PDF="$REPORT_DIR/report.pdf"
CSS="$REPORT_DIR/style.css"

if [[ ! -f "$MD" ]]; then
  echo "report.md not found. Run generate-report.sh first." >&2
  exit 2
fi

# Minimal CSS for professional PDF output.
cat > "$CSS" << 'STYLE'
@page {
  size: A4;
  margin: 2.5cm 2cm;
  @bottom-center {
    content: "Page " counter(page) " of " counter(pages);
    font-size: 9px;
    color: #666;
  }
}

body {
  font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
  font-size: 11pt;
  line-height: 1.5;
  color: #1a1a1a;
  max-width: 100%;
}

h1 {
  font-size: 22pt;
  margin-top: 0;
  padding-bottom: 8px;
  border-bottom: 2px solid #333;
}

h2 {
  font-size: 16pt;
  margin-top: 28px;
  padding-bottom: 4px;
  border-bottom: 1px solid #ccc;
  page-break-after: avoid;
}

h3 {
  font-size: 13pt;
  margin-top: 20px;
  page-break-after: avoid;
}

p, li {
  orphans: 3;
  widows: 3;
}

table {
  border-collapse: collapse;
  width: 100%;
  font-size: 9pt;
  margin: 12px 0;
  page-break-inside: avoid;
}

th, td {
  border: 1px solid #ccc;
  padding: 4px 6px;
  text-align: left;
}

th {
  background-color: #f5f5f5;
  font-weight: 600;
}

tr:nth-child(even) {
  background-color: #fafafa;
}

code {
  font-family: "SF Mono", "Fira Code", monospace;
  font-size: 9pt;
  background-color: #f4f4f4;
  padding: 1px 4px;
  border-radius: 3px;
}

pre {
  background-color: #f4f4f4;
  padding: 10px;
  border-radius: 4px;
  font-size: 9pt;
  overflow-x: auto;
}

blockquote {
  border-left: 3px solid #ccc;
  margin-left: 0;
  padding-left: 16px;
  color: #555;
}

hr {
  border: none;
  border-top: 1px solid #ddd;
  margin: 24px 0;
}

em {
  color: #555;
}

strong {
  color: #111;
}
STYLE

# Convert markdown to HTML via markdown_py CLI.
{
  echo '<!DOCTYPE html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css"></head><body>'
  markdown_py -x tables -x fenced_code "$MD"
  echo '</body></html>'
} > "$HTML"

weasyprint "$HTML" "$PDF"

echo "PDF written to $PDF"
