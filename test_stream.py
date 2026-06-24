import requests
import time
import sys
import json
import os

os.system("chcp 65001 >nul 2>&1")
try:
    sys.stdout.reconfigure(encoding='utf-8')
except:
    pass

API_KEY = open("C:/Users/lee/Desktop/test/aip/server/key.config.txt", encoding="utf-8").read().strip()
API_URL = "https://apihub.agnes-ai.com/v1/chat/completions"
MODEL = "agnes-2.0-flash"

def test_stream(message="你好", thinking=False):
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    body = {
        "model": MODEL,

        "messages": [{"role": "user", "content": message}],
        "stream": True
    }
    if thinking:
        body["chat_template_kwargs"] = {"enable_thinking": True}

    print(f"Model: {MODEL} | Thinking: {thinking} | Msg: {message}")
    print("-" * 50)

    start = time.time()
    first_token_time = None
    content = ""
    reasoning = ""
    line_count = 0

    resp = requests.post(API_URL, headers=headers, json=body, stream=True, timeout=120)

    if resp.status_code != 200:
        print(f"Error: {resp.status_code} {resp.text[:200]}")
        return

    ttfb = time.time() - start
    print(f"TTFB: {ttfb:.2f}s")
    print("-" * 50)

    for raw_line in resp.iter_lines():
        if not raw_line:
            continue
        line = raw_line.decode("utf-8")
        if not line.startswith("data: "):
            continue
        data = line[6:].strip()
        if data == "[DONE]":
            break

        line_count += 1
        try:
            chunk = json.loads(data)
            delta = chunk["choices"][0]["delta"]
            rc = delta.get("reasoning_content", "")
            cc = delta.get("content", "")
            if rc:
                reasoning += rc
                if first_token_time is None:
                    first_token_time = time.time() - start
                sys.stdout.write(f"\033[90m{rc}\033[0m")
                sys.stdout.flush()
            if cc:
                content += cc
                if first_token_time is None:
                    first_token_time = time.time() - start
                sys.stdout.write(cc)
                sys.stdout.flush()
        except:
            pass

    total_time = time.time() - start
    print()
    print("-" * 50)
    print(f"First token: {first_token_time:.2f}s" if first_token_time else "First token: N/A")
    print(f"Total: {total_time:.2f}s")
    print(f"Lines: {line_count}")
    if reasoning:
        print(f"Reasoning({len(reasoning)}): {reasoning[:100]}...")
    print(f"Reply({len(content)}): {content}")

if __name__ == "__main__":
    msg = "人工智能的作用是什么"
    think = "--think" in sys.argv
    test_stream(msg, think)
