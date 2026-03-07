import torch
import torch.nn as nn
import torch.nn.functional as F
from safetensors.torch import load_file
from torch.utils.mobile_optimizer import optimize_for_mobile

# --- 1. Decomposed Attention for Mobile Compatibility ---
class MobileAttention(nn.Module):
    def __init__(self, d_model=128, nhead=8):
        super().__init__()
        self.d_model = d_model
        self.nhead = nhead
        self.head_dim = d_model // nhead
        
        # We define these separately to avoid "native" fused ops
        self.q_proj = nn.Linear(d_model, d_model)
        self.k_proj = nn.Linear(d_model, d_model)
        self.v_proj = nn.Linear(d_model, d_model)
        self.out_proj = nn.Linear(d_model, d_model)

    def forward(self, x):
        batch_size, seq_len, _ = x.size()
        
        # Project and split into heads
        # Result shape: [Batch, Head, Seq, Head_Dim]
        q = self.q_proj(x).view(batch_size, seq_len, self.nhead, self.head_dim).transpose(1, 2)
        k = self.k_proj(x).view(batch_size, seq_len, self.nhead, self.head_dim).transpose(1, 2)
        v = self.v_proj(x).view(batch_size, seq_len, self.nhead, self.head_dim).transpose(1, 2)
        
        # Manual Scaled Dot Product
        scaling = float(self.head_dim) ** -0.5
        attn_scores = torch.matmul(q, k.transpose(-2, -1)) * scaling
        
        # Create Causal Mask (Lower Triangular)
        mask = torch.triu(torch.ones(seq_len, seq_len, device=x.device), diagonal=1).bool()
        attn_scores = attn_scores.masked_fill(mask, float('-inf'))
        
        attn_probs = F.softmax(attn_scores, dim=-1)
        attn_output = torch.matmul(attn_probs, v)
        
        # Recombine heads: [Batch, Seq, d_model]
        attn_output = attn_output.transpose(1, 2).contiguous().view(batch_size, seq_len, self.d_model)
        return self.out_proj(attn_output)

# --- 2. Decomposed Decoder Layer ---
class MobileDecoderLayer(nn.Module):
    def __init__(self, d_model=128, nhead=8, dim_feedforward=2048):
        super().__init__()
        self.self_attn = MobileAttention(d_model, nhead)
        self.linear1 = nn.Linear(d_model, dim_feedforward)
        self.linear2 = nn.Linear(dim_feedforward, d_model)
        self.norm1 = nn.LayerNorm(d_model)
        self.norm2 = nn.LayerNorm(d_model)

    def forward(self, x):
        # Sublayer 1: Attention + Residual + Norm
        x = self.norm1(x + self.self_attn(x))
        # Sublayer 2: Feed Forward + Residual + Norm
        ff_out = self.linear2(F.relu(self.linear1(x)))
        x = self.norm2(x + ff_out)
        return x

class MusicTransformer(nn.Module):
    def __init__(self, vocab_size=416, d_model=128):
        super().__init__()
        self.input_embedding = nn.Embedding(vocab_size, d_model)
        self.register_buffer("positional_encoding", torch.zeros(1, 2048, d_model)) 
        self.layers = nn.ModuleList([MobileDecoderLayer() for _ in range(6)])
        self.decoder_norm = nn.LayerNorm(d_model)
        self.final = nn.Linear(d_model, vocab_size)

    def forward(self, x):
        x = self.input_embedding(x.long()) + self.positional_encoding[:, :x.size(1), :]
        for layer in self.layers:
            x = layer(x)
        return self.final(self.decoder_norm(x))

# --- 3. The Conversion & Weight Splitting Logic ---
def convert():
    model = MusicTransformer()
    weights = load_file("model.safetensors")
    
    new_sd = model.state_dict()
    
    for i in range(6):
        base = f"decoder.layers.{i}."
        target = f"layers.{i}."
        
        # 1. SPLIT in_proj_weight [384, 128] -> Q, K, V [128, 128]
        in_proj_w = weights[f"{base}self_attn.in_proj_weight"]
        in_proj_b = weights[f"{base}self_attn.in_proj_bias"]
        
        q_w, k_w, v_w = torch.split(in_proj_w, 128, dim=0)
        q_b, k_b, v_b = torch.split(in_proj_b, 128, dim=0)
        
        new_sd[f"{target}self_attn.q_proj.weight"] = q_w
        new_sd[f"{target}self_attn.q_proj.bias"] = q_b
        new_sd[f"{target}self_attn.k_proj.weight"] = k_w
        new_sd[f"{target}self_attn.k_proj.bias"] = k_b
        new_sd[f"{target}self_attn.v_proj.weight"] = v_w
        new_sd[f"{target}self_attn.v_proj.bias"] = v_b
        
        # 2. Map the rest of the layer
        new_sd[f"{target}self_attn.out_proj.weight"] = weights[f"{base}self_attn.out_proj.weight"]
        new_sd[f"{target}self_attn.out_proj.bias"] = weights[f"{base}self_attn.out_proj.bias"]
        new_sd[f"{target}linear1.weight"] = weights[f"{base}linear1.weight"]
        new_sd[f"{target}linear1.bias"] = weights[f"{base}linear1.bias"]
        new_sd[f"{target}linear2.weight"] = weights[f"{base}linear2.weight"]
        new_sd[f"{target}linear2.bias"] = weights[f"{base}linear2.bias"]
        new_sd[f"{target}norm1.weight"] = weights[f"{base}norm1.weight"]
        new_sd[f"{target}norm1.bias"] = weights[f"{base}norm1.bias"]
        new_sd[f"{target}norm2.weight"] = weights[f"{base}norm2.weight"]
        new_sd[f"{target}norm2.bias"] = weights[f"{base}norm2.bias"]

    # 3. Map Global weights
    new_sd["input_embedding.weight"] = weights["input_embedding.weight"]
    new_sd["positional_encoding"] = weights["positional_encoding"]
    new_sd["decoder_norm.weight"] = weights["decoder.norm.weight"]
    new_sd["decoder_norm.bias"] = weights["decoder.norm.bias"]
    new_sd["final.weight"] = weights["final.weight"]
    new_sd["final.bias"] = weights["final.bias"]

    model.load_state_dict(new_sd)
    model.eval()

    # Trace and Save
    example = torch.randint(0, 416, (1, 128))
    traced = torch.jit.trace(model, example)
    optimized = optimize_for_mobile(traced)
    optimized._save_for_lite_interpreter("MusicTransformer.ptl")
    print("SUCCESS: Decomposed model created for iOS.")

#if __name__ == "__main__":
convert()