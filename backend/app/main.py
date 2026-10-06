import json
import logging
from datetime import date
from pathlib import Path

from fastapi import FastAPI, HTTPException, Response, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import TypeAdapter, ValidationError

from . import config
from .models import Day, Trip
from .repository import TripConflict, TripRepository
from .summary import summarize

log = logging.getLogger("diary")


def create_app(repo: TripRepository | None = None, seed_path: str | None = None) -> FastAPI:
    """App factory: run with `uvicorn --factory app.main:create_app`."""
    logging.basicConfig(level=logging.INFO, format="%(levelname)s:     %(name)s: %(message)s")
    repo = repo or TripRepository(config.DB_PATH, config.LOCAL_TZ)
    seed_path = seed_path if seed_path is not None else config.SEED_PATH
    if seed_path:
        import_trips(repo, Path(seed_path))

    app = FastAPI(title="Driver shift diary")
    app.state.repo = repo
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.CORS_ORIGINS,
        allow_methods=["GET", "POST"],
        allow_headers=["Content-Type"],
    )

    @app.get("/api/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/days")
    def list_days() -> list[date]:
        """Days that have trips, newest first: lets the client open on real data."""
        return repo.days()

    @app.get("/api/days/{day}")
    def get_day(day: date) -> Day:
        trips = repo.list_by_day(day)
        return Day(date=day, summary=summarize(trips), trips=trips)

    @app.post(
        "/api/trips",
        status_code=status.HTTP_201_CREATED,
        responses={
            200: {"description": "Same trip was already stored; nothing changed"},
            409: {"description": "Trip id already used with different data"},
        },
    )
    def add_trip(trip: Trip, response: Response) -> Trip:
        try:
            stored, created = repo.add(trip)
        except TripConflict as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"message": str(exc), "existing": exc.existing.model_dump(mode="json")},
            ) from exc
        if not created:
            response.status_code = status.HTTP_200_OK
        return stored

    return app


def import_trips(repo: TripRepository, path: Path) -> None:
    """Import a JSON array of trips. Already-imported trips are skipped, so restarts are safe."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    created = skipped = rejected = 0
    for item in raw:
        try:
            trip = TypeAdapter(Trip).validate_python(item)
            _, was_created = repo.add(trip)
            created += was_created
            skipped += not was_created
        except (ValidationError, TripConflict) as exc:
            rejected += 1
            trip_id = item.get("id") if isinstance(item, dict) else item
            log.warning("seed: rejected trip %s: %s", trip_id, exc)
    log.info("seed: %d created, %d already present, %d rejected", created, skipped, rejected)
