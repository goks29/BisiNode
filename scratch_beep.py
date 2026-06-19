import wave, struct, math
import os

sample_rate = 44100
freq = 800.0
duration = 0.15
filename = "c:/PERKULIAHANDUNIAWI/SEMESTER 4/pcd praktek/Tubes/BisiNode/assets/sounds/beep.wav"

os.makedirs(os.path.dirname(filename), exist_ok=True)

with wave.open(filename, 'w') as wav_file:
    wav_file.setnchannels(1)
    wav_file.setsampwidth(2)
    wav_file.setframerate(sample_rate)
    
    for i in range(int(sample_rate * duration)):
        # Apply a simple envelope to avoid clicks
        envelope = 1.0
        if i < 400:
            envelope = i / 400.0
        elif i > int(sample_rate * duration) - 400:
            envelope = (int(sample_rate * duration) - i) / 400.0
            
        value = int(32767.0 * 0.5 * envelope * math.sin(2.0 * math.pi * freq * i / sample_rate))
        wav_file.writeframes(struct.pack('<h', value))

print("Wav file created successfully")
