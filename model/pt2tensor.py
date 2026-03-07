import torch
import torch.nn as nn
from math import sqrt
import os
from transformers import PretrainedConfig, PreTrainedModel
from safetensors.torch import save_file

# --- 1. CONFIGURATION CLASS ---
class MusicTransformerConfig(PretrainedConfig):
    model_type = "music_transformer"

    def __init__(
        self,
        vocab_size=388,
        d_model=512,
        num_layers=6,
        num_heads=8,
        d_ff=2048,
        max_rel_dist=1024,
        max_abs_position=2048,
        bias=True,
        dropout=0.1,
        layernorm_eps=1e-6,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.vocab_size = vocab_size
        self.d_model = d_model
        self.num_layers = num_layers
        self.num_heads = num_heads
        self.d_ff = d_ff
        self.max_rel_dist = max_rel_dist
        self.max_abs_position = max_abs_position
        self.bias = bias
        self.dropout = dropout
        self.layernorm_eps = layernorm_eps

# --- 2. HUGGING FACE WRAPPER CLASS ---
class MusicTransformer(PreTrainedModel):
    config_class = MusicTransformerConfig

    def __init__(self, config):
        super().__init__(config)
        self.config = config

        # Layers based on your provided __init__
        self.input_embedding = nn.Embedding(config.vocab_size, config.d_model)
        
        # Note: Ensure your abs_positional_encoding function is available in scope
        self.positional_encoding = nn.Parameter(
            torch.randn(1, config.max_abs_position, config.d_model), 
            requires_grad=False
        )
        self.input_dropout = nn.Dropout(config.dropout)

        # Standard Decoder stack
        # (Assuming DecoderLayer is your custom class)
        decoder_layer = nn.TransformerDecoderLayer(
            d_model=config.d_model,
            nhead=config.num_heads,
            dim_feedforward=config.d_ff,
            dropout=config.dropout,
            layer_norm_eps=config.layernorm_eps,
            batch_first=True  # Recommended for modern pipelines
        )
        
        self.decoder = nn.TransformerDecoder(
            decoder_layer,
            num_layers=config.num_layers,
            norm=nn.LayerNorm(config.d_model, eps=config.layernorm_eps)
        )

        self.final = nn.Linear(config.d_model, config.vocab_size)
        
        # Initialize weights
        self.post_init()

    def forward(self, x, mask=None):
        # Embed and Scale
        x = self.input_embedding(x)
        x *= sqrt(self.config.d_model)

        # Add Positional Encoding
        if self.config.max_abs_position > 0:
            seq_len = x.shape[1]
            x += self.positional_encoding[:, :seq_len, :]

        x = self.input_dropout(x)
        
        # Pass through Decoder
        # tgt_mask handles the causal/look-ahead masking
        x = self.decoder(x, memory=None, tgt_mask=mask)

        # Project to Logits
        return self.final(x)

# --- 3. CONVERSION EXECUTION ---
def convert_and_save(pt_path, output_dir):
    print(f"Loading weights from {pt_path}...")
    old_state_dict = torch.load(pt_path, map_location="cpu")

    if "state_dict" in old_state_dict:
        weights = old_state_dict["state_dict"]
    else:
        weights = old_state_dict

    # --- UPDATED CONFIG TO MATCH YOUR ERROR LOG ---
    config = MusicTransformerConfig(
        vocab_size=416,  # Matches torch.Size([416, ...])
        d_model=128,     # Matches torch.Size([..., 128])
        # You may also need to verify num_layers and num_heads 
        # based on your original training script
    ) 
    
    hf_model = MusicTransformer(config)

    # Now load the weights
    hf_model.load_state_dict(weights, strict=False)

    print(f"Saving Hugging Face model to {output_dir}...")
    hf_model.save_pretrained(output_dir)
    print("Success!")

#if __name__ == "__main__":
#    # Example usage:
#    # convert_and_save("my_old_model.pt", "./MusicFun-HF")
#    pass

convert_and_save("model.pt", "./MusicFun-HF")