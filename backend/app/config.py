import os
from datetime import timedelta, timezone
from pathlib import Path

# Kazakhstan has used a single time zone, UTC+5, since March 2024.
# A trip belongs to the local calendar day on which it started.
LOCAL_TZ = timezone(timedelta(hours=int(os.getenv("DIARY_UTC_OFFSET_HOURS", "5"))))

DB_PATH = Path(os.getenv("DIARY_DB_PATH", "diary.sqlite3"))

# Optional JSON file with trips that is imported on startup (safe to re-run).
SEED_PATH = os.getenv("DIARY_SEED_PATH")

CORS_ORIGINS = os.getenv("DIARY_CORS_ORIGINS", "*").split(",")
