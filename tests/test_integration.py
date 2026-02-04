import subprocess
import time
import requests
import os

BACKEND_PORT = int(os.environ.get("BACKEND_PORT", "8001"))
FRONTEND_PORT = int(os.environ.get("FRONTEND_PORT", "3001"))


def wait_for(url, timeout=20):
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(url, timeout=2)
            if r.status_code == 200:
                return r
        except Exception:
            pass
        time.sleep(0.5)
    raise RuntimeError(f"Timeout waiting for {url}")


def test_frontend_and_backend_integration(tmp_path):
    # Start backend on BACKEND_PORT
    backend_proc = subprocess.Popen(
        ["python", "-m", "uvicorn", "app.main:app", "--port", str(BACKEND_PORT)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    # Build frontend
    subprocess.check_call(["npm", "install"], cwd="frontend")
    subprocess.check_call(["npm", "run", "build"], cwd="frontend")

    # Start frontend
    frontend_proc = subprocess.Popen(
        ["npx", "next", "start", "-p", str(FRONTEND_PORT)],
        cwd="frontend",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    try:
        # Wait for both services
        b = wait_for(f"http://127.0.0.1:{BACKEND_PORT}/docs", timeout=30)
        f = wait_for(f"http://127.0.0.1:{FRONTEND_PORT}/", timeout=60)

        assert "EGX Analytics" in f.text or "EGX-Analytics" in f.text

    finally:
        backend_proc.terminate()
        frontend_proc.terminate()
        backend_proc.wait(timeout=5)
        frontend_proc.wait(timeout=5)
