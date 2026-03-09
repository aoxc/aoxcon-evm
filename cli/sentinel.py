import os
import json
import click
import requests
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

console = Console()
BACKEND_URL = os.getenv("AOXC_SENTINEL_URL", "http://localhost:5000/api/v1")
SENTINEL_TOKEN = os.getenv("AOXC_SENTINEL_TOKEN", "")


def _headers() -> dict:
    h = {"Content-Type": "application/json"}
    if SENTINEL_TOKEN:
        h["x-sentinel-token"] = SENTINEL_TOKEN
    return h


@click.group()
def cli():
    """🛡️ AOXC NEURAL OS - Corporate Audit & Operations CLI"""
    pass


@cli.command()
def status():
    """Check backend health and show operational endpoint state."""
    try:
        resp = requests.get(f"{BACKEND_URL}/health", timeout=8)
        if resp.ok:
            data = resp.json()
            console.print(
                Panel(
                    f"[bold cyan]AOXC NEURAL OS v2.5[/bold cyan]\n"
                    f"[green]API Status: {data.get('status', 'ok')}[/green]\n"
                    f"[blue]Service: {data.get('service', 'sentinel-api')}[/blue]\n"
                    f"[magenta]Version: {data.get('version', 'v1')}[/magenta]",
                    title="Sentinel Dashboard",
                )
            )
        else:
            console.print(f"[red]Health check failed with status: {resp.status_code}[/red]")
    except Exception as exc:
        console.print(f"[red]Backend unreachable: {exc}[/red]")


@cli.command()
@click.argument("tx_hash")
@click.option("--context", default="", help="Optional context text for AI analysis")
def audit(tx_hash: str, context: str):
    """Run AI-assisted audit for a transaction hash against backend sentinel service."""
    payload = {"prompt": f"Audit transaction {tx_hash}", "context": context}
    try:
        resp = requests.post(
            f"{BACKEND_URL}/sentinel/analyze",
            headers=_headers(),
            data=json.dumps(payload),
            timeout=12,
        )
        if not resp.ok:
            console.print(f"[red]Audit failed ({resp.status_code}): {resp.text}[/red]")
            return

        data = resp.json()
        table = Table(title="Sentinel Analysis")
        table.add_column("Field", style="cyan")
        table.add_column("Value", style="white")
        table.add_row("Risk", str(data.get("risk")))
        table.add_row("Action", str(data.get("action")))
        table.add_row("Reason", str(data.get("reason")))
        table.add_row("Provider", str(data.get("provider")))
        console.print(table)
    except Exception as exc:
        console.print(f"[red]Audit request error: {exc}[/red]")


if __name__ == "__main__":
    cli()
