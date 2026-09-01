import urllib.request
import json
import time
import os
import zipfile
import io
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

TOKEN = "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"
REPO = "atdaniellimon/Newton-iOS"
HEADERS = {
    "Authorization": f"token {TOKEN}",
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "Newton-Builder"
}

def check_and_download():
    print("Waiting for iOS workflow to finish...")
    for _ in range(60):
        req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/actions/runs?per_page=5", headers=HEADERS)
        with urllib.request.urlopen(req, context=ctx) as resp:
            data = json.loads(resp.read().decode())
        
        ios_run = None
        for run in data.get("workflow_runs", []):
            if run.get("name") == "Build Newton iOS IPA":
                ios_run = run
                break
        
        if not ios_run:
            print("No iOS run found.")
            return False
        
        status = ios_run.get("status")
        conclusion = ios_run.get("conclusion")
        print(f"Workflow Status: {status}, Conclusion: {conclusion}")
        
        if status == "completed":
            if conclusion == "success":
                run_id = ios_run.get("id")
                # Get artifacts
                art_req = urllib.request.Request(f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}/artifacts", headers=HEADERS)
                with urllib.request.urlopen(art_req, context=ctx) as aresp:
                    art_data = json.loads(aresp.read().decode())
                
                for art in art_data.get("artifacts", []):
                    if "IPA" in art.get("name", ""):
                        dl_url = art.get("archive_download_url")
                        print(f"Downloading artifact {art.get('name')} from {dl_url}...")
                        dl_req = urllib.request.Request(dl_url, headers=HEADERS)
                        with urllib.request.urlopen(dl_req, context=ctx) as dl_resp:
                            zip_bytes = dl_resp.read()
                        
                        # Extract zip
                        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
                            z.extractall("build/Downloaded-IPA")
                        
                        if os.path.exists("build/Downloaded-IPA/Newton.ipa"):
                            os.system("cp build/Downloaded-IPA/Newton.ipa build/Downloaded-IPA/Newton_v3.5.ipa")
                        
                        print("Extracted IPA to build/Downloaded-IPA/Newton_v3.5.ipa")
                        return True
            else:
                print(f"Build failed with conclusion: {conclusion}")
                return False
        
        time.sleep(10)
    
    return False

if __name__ == "__main__":
    check_and_download()
