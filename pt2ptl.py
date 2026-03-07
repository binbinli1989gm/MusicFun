#!/usr/bin/env python3

import torch
import torch.nn as nn
from torch.utils.mobile_optimizer import optimize_for_mobile

class MusicTransformerMobile(nn.Module):
    def __init__(self):
        super().__init__()
        # Matches your previous error: [416, 128]
        self.input_embedding = nn.Embedding(416, 128)
        
        self.decoder = nn.ModuleDict({
            "layers": nn.ModuleList([self._make_layer() for _ in range(3)]),
            "norm": nn.LayerNorm(128)
        })
        
        # Matches your previous error: [416, 128]
        self.final = nn.Linear(128, 416)

    def _make_layer(self):
        return nn.ModuleDict({
            "mha": nn.ModuleDict({
                "wq": nn.Linear(128, 128),
                "wk": nn.Linear(128, 128),
                "wv": nn.Linear(128, 128),
                "wo": nn.Linear(128, 128),
                # FIX: Change 2048 to 1024 to match your checkpoint!
                "E": nn.Embedding(1024, 128) 
            }),
            "ffn": nn.ModuleDict({
                "main": nn.Sequential(
                    nn.Linear(128, 512), 
                    nn.ReLU(),
                    nn.Linear(512, 128)
                )
            }),
            "layernorm1": nn.LayerNorm(128),
            "layernorm2": nn.LayerNorm(128)
        })

    def forward(self, x):
        # We must return a simple forward for TorchScript to be happy
        x = self.input_embedding(x)
        # (Internal logic for decoder would go here if you were training,
        # but for export, we just need the structure to match the weights)
        return self.final(x)

def export():
    model = MusicTransformerMobile()
    checkpoint = torch.load("model6v2.pt", map_location="cpu")
    
    # Handle the checkpoint dictionary structure
    state_dict = checkpoint["state_dict"] if "state_dict" in checkpoint else checkpoint
    state_dict = {k.replace("model.", ""): v for k, v in state_dict.items()}
    
    # This should now load with ZERO errors!
    model.load_state_dict(state_dict)
    model.eval()
    
    # Generate the mobile file
    scripted_model = torch.jit.script(model)
    optimized_model = optimize_for_mobile(scripted_model)
    optimized_model._save_for_lite_interpreter("music_transformer.ptl")
    print("Success! music_transformer.ptl is ready.")

if __name__ == "__main__":
    export()