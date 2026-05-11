import os
import sys
from reedsolo import RSCodec, ReedSolomonError

KEY_SIZE = 16

def xor_bytes(b1,b2):
    return bytes(a^b for a,b in zip(b1,b2))

def enrollment_phase(golden_puf_hex):
    golden_puf_bytes = bytes.fromhex(golden_puf_hex)
    puf_len = len(golden_puf_bytes)

    K = os.urandom(KEY_SIZE)
    print(f"Original Key K = {K.hex()}")

    rs = RSCodec(puf_len - len(K))
    codeword = rs.encode(K)

    helper_data = xor_bytes(golden_puf_bytes,codeword)

    print(f"Public Helper Data W = {helper_data.hex()}")
    return K,helper_data


def reconstruction_phase(noisy_puf_hex, helper_data):
    noisy_puf_bytes = bytes.fromhex(noisy_puf_hex)
    puf_len = len(noisy_puf_bytes)
    
    noisy_codeword = xor_bytes(noisy_puf_bytes,helper_data)

    rs = RSCodec(puf_len-KEY_SIZE)
    
    try:
        recovered_key, fixed_codeword, err_count = rs.decode(noisy_codeword)
        print(f"Recovered 128-bit Key: {recovered_key.hex()}")
        print(f"SUCCESS: ECC fixed {err_count} byte error(s)!")
        return recovered_key
    except ReedSolomonError:
        print("FATAL ERROR: The PUF was too noisy. ECC failed to recover the key.")
        return None


if __name__ == "__main__":
    
    try:
        with open('data/puf_data_9.txt', 'r') as f0:
            # Read 2 lines and concatenate them for a 512-bit Golden PUF
            golden_puf = f0.readline().strip() + f0.readline().strip() 
        
        with open('data/puf_data_22.txt', 'r') as f1:
            # Read 2 lines for a 512-bit Noisy PUF
            noisy_puf = f1.readline().strip() + f1.readline().strip()
    except FileNotFoundError:
        print("Please ensure puf_data_0.txt and puf_data_1.txt are in this folder.")
        sys.exit(1)
    
    original_key, helper_data = enrollment_phase(golden_puf)
    recovered_key = reconstruction_phase(noisy_puf, helper_data)

    print("\n--- FINAL VERIFICATION ---")
    print(f"Original Key = {original_key.hex()}")
    print(f"Recovered Key = {recovered_key.hex()}")
    if recovered_key == original_key:
        print("Success! The raw PUF is now a stable AES key!")
    else:
        print("Failure: The recovered key does not match.")
