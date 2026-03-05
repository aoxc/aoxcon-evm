import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import aox_config as cfg # Ayarları buradan çekiyoruz

def load_engine():
    print(f"\n{'='*50}")
    print(f"🛡️  AOXCORE NEURAL INTERFACE v1.0")
    print(f"⚙️  ADAPTER: {cfg.ADAPTER_PATH}")
    print(f"{'='*50}\n")

    # 1. Tokenizer ve Base Model
    tokenizer = AutoTokenizer.from_pretrained(cfg.BASE_MODEL)
    base_model = AutoModelForCausalLM.from_pretrained(
        cfg.BASE_MODEL,
        torch_dtype=cfg.TORCH_DTYPE,
        device_map=cfg.DEVICE_MAP,
        low_cpu_mem_usage=True
    )

    # 2. Adaptörü Giydir
    model = PeftModel.from_pretrained(base_model, cfg.ADAPTER_PATH)
    model.eval() # Eğitim modundan çıkar, çıkarım (inference) moduna al
    return model, tokenizer

def ask_aox(model, tokenizer, prompt_text):
    # Senin özel eğitim formatın
    full_prompt = f"### FILE: AoxcCore.sol\n### SOLIDITY CODE:\n{prompt_text}"
    inputs = tokenizer(full_prompt, return_tensors="pt").to("cpu")
    
    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            **cfg.GENERATION_CONFIG, # Tüm ayarlar config'den geliyor
            pad_token_id=tokenizer.eos_token_id
        )
    
    return tokenizer.decode(outputs[0], skip_special_tokens=True)

if __name__ == "__main__":
    aox_model, aox_tokenizer = load_engine()
    
    print("🚀 AOXCORE Hazır. Ne sormak istersin? (Çıkış için 'exit')")
    
    while True:
        user_input = input("\n👤 SEN: ")
        if user_input.lower() == 'exit': break
        
        print("\n🤖 AOXCORE Düşünüyor...")
        response = ask_aox(aox_model, aox_tokenizer, user_input)
        print(f"\n{'-'*30}\n{response}\n{'-'*30}")
