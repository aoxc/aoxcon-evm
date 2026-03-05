#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
PROJECT: AOXCORE | AUTOMATED SOURCE CONTROL ENGINE
MODULE: DATASET GENERATOR FOR LLM TRAINING
AUTH: ORCUN [NS1]
DESC: Scans Solidity source files and packages them into a JSONL format.
      Optimized for absolute path resolution.
"""

import os
import json
import sys
from pathlib import Path

def create_dataset():
    # --- PRO-LEVEL PATH RESOLUTION ---
    # 1. Scriptin tam yerini bul (scripts/make_dataset.py)
    current_script_path = Path(__file__).resolve()
    
    # 2. Çalışma dizini (aoxcan-working)
    working_dir = current_script_path.parent.parent
    
    # 3. Proje kök dizini (aoxcai)
    aoxcai_dir = working_dir.parent
    
    # 4. Gerçek AOXCORE kök dizini (Work/AOXCORE)
    # Senin yapında: ~/Work/AOXCORE/src olduğu için bir tık yukarı çıkıyoruz
    aoxcore_root = aoxcai_dir.parent
    
    # HEDEFLER
    SRC_PATH = aoxcore_root / "src"
    OUTPUT_DIR = working_dir / "data"
    OUTPUT_FILE = OUTPUT_DIR / "master_train.jsonl"
    
    dataset = []

    print(f"\n{'='*65}")
    print(f"💠 AOXCORE DATA ENGINE | PATH RECOVERY MODE")
    print(f"📂 SOURCE (Solidity): {SRC_PATH}")
    print(f"💾 TARGET (JSONL)   : {OUTPUT_FILE}")
    print(f"{'='*65}")

    # 1. Çıkış klasörü kontrolü
    if not OUTPUT_DIR.exists():
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        print(f"✨ Created output directory: {OUTPUT_DIR}")

    # 2. Kaynak dosya taraması (Doğrulama)
    if not SRC_PATH.exists():
        print(f"❌ [ERROR] Source path not found!")
        print(f"   Expected: {SRC_PATH}")
        print("\n💡 MANUEL KONTROL: Lütfen terminalde 'ls ~/Work/AOXCORE/src' komutunu çalıştırın.")
        sys.exit(1)

    print(f"🔍 Crawling Solidity assets...")
    
    file_count = 0
    for root, _, files in os.walk(str(SRC_PATH)):
        for file in files:
            if file.endswith('.sol'):
                full_path = Path(root) / file
                try:
                    with open(full_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                        entry = {
                            "text": f"### FILE: {file}\n### SOLIDITY CODE:\n{content}"
                        }
                        dataset.append(entry)
                        file_count += 1
                        print(f"   [{file_count:03d}] Indexed: {file}")
                except Exception as e:
                    print(f"⚠️  [WARNING] Failed to read {file}: {str(e)}")

    # 3. JSONL Olarak Paketleme
    if not dataset:
        print(f"❌ [CRITICAL] No .sol files found in {SRC_PATH}!")
        sys.exit(1)

    try:
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            for item in dataset:
                f.write(json.dumps(item, ensure_ascii=False) + '\n')
        
        print(f"\n{'='*65}")
        print(f"🏆 DEPLOYMENT SUCCESS!")
        print(f"📦 Total Assets Packaged: {len(dataset)}")
        print(f"💾 Payload Ready: {OUTPUT_FILE}")
        print(f"{'='*65}\n")
        
    except Exception as e:
        print(f"❌ [CRITICAL] File write error: {str(e)}")

if __name__ == "__main__":
    create_dataset()
