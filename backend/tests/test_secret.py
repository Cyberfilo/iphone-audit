import base64

from iphone_audit.hardening.secret import generate_secret


def test_secret_length_and_entropy():
    s = generate_secret()
    assert len(s) == 32
    raw = base64.b64decode(s)
    assert len(raw) == 24


def test_secret_unique():
    samples = {generate_secret() for _ in range(10)}
    assert len(samples) == 10
