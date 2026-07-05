import sys
import re

# Ensure stdout supports UTF-8/unicode output
sys.stdout.reconfigure(encoding='utf-8')

log_path = r"C:\Users\anura\.gemini\antigravity\brain\30564d2c-4d77-4209-854c-4716def27519\.system_generated\tasks\task-46.log"

exclude_patterns = [
    r'dtc-route',
    r'venv',
    r'reconciled_stops',
    r'unresolved_stops',
    r'api_stops',
    r'pis\.txt',
    r'jquery',
    r'select2',
    r'node_modules',
    r'\.git'
]

with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        
        # Regex to parse the search log line: filepath:line:content
        # Note: on Windows, filepath starts with drive letter like C:\
        match = re.match(r'^([a-zA-Z]:\\[^:]+|[^\\][^:]+):(\d+):(.*)$', line)
        if match:
            filepath, line_num, content = match.groups()
            
            # Check if filepath should be excluded
            should_exclude = False
            for pattern in exclude_patterns:
                if re.search(pattern, filepath, re.IGNORECASE):
                    should_exclude = True
                    break
            
            if not should_exclude:
                print(f"File: {filepath} | Line: {line_num} | Match: {content[:100]}")


