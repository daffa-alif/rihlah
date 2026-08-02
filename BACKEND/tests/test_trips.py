from BACKEND.tests.conftest import API


def test_create_and_get_trip(client, sample_trip):
    created = client.post(f"{API}/trips", json=sample_trip)
    assert created.status_code == 201

    trip_id = created.json()["id"]
    fetched = client.get(f"{API}/trips/{trip_id}")

    assert fetched.status_code == 200
    assert fetched.json()["title"] == sample_trip["title"]


def test_list_trips_is_paginated(client, sample_trip):
    for index in range(3):
        client.post(f"{API}/trips", json={**sample_trip, "title": f"Trip {index}"})

    response = client.get(f"{API}/trips", params={"limit": 2, "offset": 0})
    body = response.json()

    assert response.status_code == 200
    assert body["total"] == 3
    assert len(body["items"]) == 2


def test_list_trips_filters_by_destination(client, sample_trip):
    client.post(f"{API}/trips", json=sample_trip)
    client.post(f"{API}/trips", json={**sample_trip, "destination": "Kyoto, Japan"})

    response = client.get(f"{API}/trips", params={"destination": "kyoto"})

    assert response.json()["total"] == 1


def test_update_trip(client, sample_trip):
    trip_id = client.post(f"{API}/trips", json=sample_trip).json()["id"]

    response = client.patch(f"{API}/trips/{trip_id}", json={"title": "Renamed"})

    assert response.status_code == 200
    assert response.json()["title"] == "Renamed"
    assert response.json()["destination"] == sample_trip["destination"]


def test_delete_trip(client, sample_trip):
    trip_id = client.post(f"{API}/trips", json=sample_trip).json()["id"]

    assert client.delete(f"{API}/trips/{trip_id}").status_code == 204
    assert client.get(f"{API}/trips/{trip_id}").status_code == 404


def test_missing_trip_returns_error_envelope(client):
    response = client.get(f"{API}/trips/does-not-exist")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_end_date_before_start_date_is_rejected(client, sample_trip):
    response = client.post(
        f"{API}/trips", json={**sample_trip, "end_date": "2026-09-01"}
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
