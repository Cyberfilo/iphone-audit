from iphone_audit.audit import gestalt


def test_modern_ios_emits_unavailable(empty_snap):
    findings = gestalt.check("0000-FAKE", empty_snap)
    assert any(f.id == "gestalt.unavailable_modern_ios" for f in findings)


def test_version_compare():
    assert gestalt._is_ios_17_4_or_later("18.6.2") is True
    assert gestalt._is_ios_17_4_or_later("17.4") is True
    assert gestalt._is_ios_17_4_or_later("17.3") is False
    assert gestalt._is_ios_17_4_or_later("16.0") is False
    assert gestalt._is_ios_17_4_or_later("26.3.1") is True
    assert gestalt._is_ios_17_4_or_later("") is False
