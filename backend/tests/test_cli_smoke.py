"""Smoke test that the CLI imports and `--help` works without a device."""
from click.testing import CliRunner

from iphone_audit.cli import cli


def test_cli_help():
    runner = CliRunner()
    result = runner.invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "iPhone audit" in result.output


def test_subcommand_help_smoke():
    runner = CliRunner()
    for sub in ["list", "quick-scan", "advise", "harden", "verify",
                "secret", "pairing", "init-signing-cert", "daemon"]:
        result = runner.invoke(cli, [sub, "--help"])
        assert result.exit_code == 0, f"{sub} --help failed: {result.output}"
