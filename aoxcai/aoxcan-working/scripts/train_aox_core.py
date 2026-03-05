import os
import torch
import datetime
import logging
import sys
from transformers import (
    AutoModelForCausalLM, 
    AutoTokenizer, 
    TrainingArguments, 
    Trainer, 
    DataCollatorForLanguageModeling
)
from datasets import load_dataset
from peft import LoraConfig, get_peft_model

# --- [LOGGING CONFIG] ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("AOXCORE-ENGINE")

# --- [🆔 SERİ NO VE İSİMLENDİRME] ---
CURRENT_DATE = datetime.datetime.now().strftime("%Y%m%d")
SERIAL_ID = "XLYR-002" # v2 Uyanış Serisi
MODEL_IDENTITY = f"aoxcan-core-{SERIAL_ID}-SN{CURRENT_DATE}"
OUTPUT_DIR = f"./outputs/{MODEL_IDENTITY}"

print(f"\n{'='*65}")
print(f"🛡️  AOXCORE NEURAL DEPLOYMENT [v2]: {MODEL_IDENTITY}")
print(f"⚙️  MODE: DEEP-AWAKENING | EPOCHS: 5 | RAM: 1GB LIMIT")
print(f"{'='*65}\n")

# --- 1. MODEL YÜKLEME ---
MODEL_PATH = "./model_hub"
print(f"📦 Loading base zeka from: {MODEL_PATH}...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
tokenizer.pad_token = tokenizer.eos_token

try:
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH,
        device_map={"": "cpu"},
        low_cpu_mem_usage=True,
        trust_remote_code=True
    )
except Exception as e:
    print(f"❌ [CRITICAL ERROR] Model yüklenemedi: {e}")
    sys.exit(1)

# --- 2. X-LAYER (LoRA) KONFİGÜRASYONU ---
lora_config = LoraConfig(
    r=16,           # Kapasiteyi artırdık (8 -> 16)
    lora_alpha=32,  # Etkiyi artırdık
    target_modules=["q_proj", "v_proj"], 
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)
model = get_peft_model(model, lora_config)
model.print_trainable_parameters()

# --- 3. DATASET YÜKLEME ---
print(f"📚 Reading Core logic data...")
DATA_FILE = "./data/master_train.jsonl"
dataset = load_dataset("json", data_files=DATA_FILE, split="train")

def tokenize_func(examples):
    return tokenizer(
        examples["text"], 
        truncation=True, 
        max_length=128, 
        padding="max_length"
    )

tokenized_ds = dataset.map(tokenize_func, batched=True, remove_columns=["text"])

# --- 4. EĞİTİM AYARLARI (Hassas Ayarlı v2) ---
train_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    per_device_train_batch_size=1,      
    gradient_accumulation_steps=8,      # Batch size etkisini artırdık
    learning_rate=5e-5,                 # Daha hassas öğrenme hızı
    num_train_epochs=5,                 # 5 TUR (Gerçek öğrenme burada başlar)
    logging_steps=1,
    use_cpu=True,                       
    save_strategy="epoch",              # Her tur sonunda kaydet (Sigorta)
    report_to="none",
    gradient_checkpointing=True         
)

# --- 5. ATEŞLEME ---
trainer = Trainer(
    model=model,
    args=train_args,
    train_dataset=tokenized_ds,
    data_collator=DataCollatorForLanguageModeling(tokenizer=tokenizer, mlm=False)
)

print(f"\n🔥 [ENGINE v2 ONLINE] Serial: {SERIAL_ID} | Deep Learning in progress...")
try:
    trainer.train()
except Exception as e:
    print(f"❌ [TRAINING FAILED] Eğitim sırasında hata: {e}")
    sys.exit(1)

# --- 6. MÜHÜRLEME ---
model.save_pretrained(OUTPUT_DIR)
tokenizer.save_pretrained(OUTPUT_DIR)

print(f"\n{'='*65}")
print(f"✅ [SUCCESS] AOX-CORE v2 AWAKENING SEALED.")
print(f"📂 STORED AT: {OUTPUT_DIR}")
print(f"{'='*65}\n")
