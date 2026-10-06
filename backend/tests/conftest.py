import pytest
from fastapi.testclient import TestClient

from app.config import LOCAL_TZ
from app.main import create_app
from app.repository import TripRepository


@pytest.fixture
def repo(tmp_path) -> TripRepository:
    return TripRepository(tmp_path / "test.sqlite3", LOCAL_TZ)


@pytest.fixture
def client(repo) -> TestClient:
    return TestClient(create_app(repo=repo, seed_path=""))


def trip(**overrides) -> dict:
    """The first trip from the task description; override fields per test."""
    data = {
        "id": "t1",
        "start": "2026-10-01T08:10:00+05:00",
        "end": "2026-10-01T08:32:00+05:00",
        "amount": 2400,
        "payment": "card",
        "commission": 360,
    }
    return data | overrides
