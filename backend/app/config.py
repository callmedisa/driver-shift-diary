import os
from pathlib import Path
from zoneinfo import ZoneInfo

# A trip belongs to the local calendar day on which it started. A named zone
# (not a fixed +05:00) keeps old data right: Almaty was UTC+6 until March 2024.
LOCAL_TZ = ZoneInfo(os.getenv("DIARY_TIMEZONE", "Asia/Almaty"))

DB_PATH = Path(os.getenv("DIARY_DB_PATH", "diary.sqlite3"))

# Optional JSON file with trips that is imported on startup (safe to re-run).
SEED_PATH = os.getenv("DIARY_SEED_PATH")

CORS_ORIGINS = os.getenv("DIARY_CORS_ORIGINS", "*").split(",")
