import torch

# --- [PATH SETTINGS] ---
BASE_MODEL = "./model_hub"
# Burayı yeni eğitimler yaptıkça güncellersin:
ADAPTER_PATH = "./outputs/aoxcan-core-XLYR-001-SN20260305"

# --- [INFERENCE / CHAT SETTINGS] ---
# 0.1 - 0.2: Çok katı, kod yazımı ve audit için ideal.
# 0.7 - 0.9: Yaratıcı, yeni fikirler üretmek için.
GENERATION_CONFIG = {
    "max_new_tokens": 150,
    "temperature": 0.2,       # Disiplinli mod (C# saçmalığını engeller)
    "top_p": 0.9,             # En mantıklı kelime havuzunu daraltır
    "do_sample": True,
    "repetition_penalty": 1.2, # Kendini tekrar etmesini (AoxcModuleAoxcModule) engeller
}

# --- [HARDWARE SETTINGS] ---
DEVICE_MAP = {"": "cpu"}
TORCH_DTYPE = torch.float32 # 1GB RAM CPU için en stabil olan
