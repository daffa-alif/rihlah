from BACKEND.tests.conftest import API


def test_health_returns_ok(client):
    response = client.get(f"{API}/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_openapi_schema_is_served(client):
    response = client.get(f"{API}/openapi.json")

    assert response.status_code == 200
    assert response.json()["info"]["title"] == "Rihlah API"
