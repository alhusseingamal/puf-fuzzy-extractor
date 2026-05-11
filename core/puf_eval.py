import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.spatial.distance import pdist

def load_data(file_paths):
    """
    Loads hex data from multiple files into a 3D numpy array.
    Shape: (M measurements, K devices, N bits)
    """
    m_files = len(file_paths)
    data_list = []
    
    for f in file_paths:
        try:
            with open(f, 'r') as file:
                lines = [line.strip() for line in file if line.strip()]
                
            # convert hex strings to binary numpy arrays
            file_data = []
            for line in lines:
                num_bits = len(line) * 4
                bin_str = bin(int(line, 16))[2:].zfill(num_bits)
                file_data.append([int(b) for b in bin_str])
            
            data_list.append(file_data)
        except Exception as e:
            print(f"Error reading {f}: {e}")
            
    # convert to 3D array: (m_measurements, k_devices, n_bits)
    return np.array(data_list, dtype=np.uint8)

def evaluate_puf(data):
    M, K, N = data.shape
    print(f"Loaded Data: {M} measurements, {K} devices, {N} bits per device.\n")

    # 1. Uniformity
    uniformity_per_device = np.sum(data[0], axis=1) / N * 100
    avg_uniformity = np.mean(uniformity_per_device)

    # 2. Uniqueness (Inter-chip Hamming Distance)
    # Formula (1): Pairwise HD between all devices in the first measurement
    pairwise_hd_frac = pdist(data[0], metric='hamming') # pdist with 'hamming' returns the fractional difference between 0.0 and 1.0
    uniqueness_vals = pairwise_hd_frac * 100
    avg_uniqueness = np.mean(uniqueness_vals)

    # 3. Bit-aliasing
    # Formula (5): Fractional Hamming Weight of each bit across all devices (first measurement)
    bit_aliasing_per_bit = np.sum(data[0], axis=0) / K * 100
    avg_bit_aliasing = np.mean(bit_aliasing_per_bit)

    # 4. Reliability (Intra-chip Hamming Distance)
    # Formula (2 & 3): HD between reference measurement (t=0) and subsequent measurements (t>0)
    if M > 1:
        ref_data = data[0] # The first file acts as R_i
        
        # calculate HD_INTRA for each device across all (M-1) subsequent measurements
        hd_intra_sum = np.zeros(K)
        for t in range(1, M):
            # Compare measurement 't' to reference '0'
            diff = np.sum(data[t] != ref_data, axis=1)
            hd_intra_sum += (diff / N * 100)
            
        hd_intra_per_device = hd_intra_sum / (M - 1)
        reliability_per_device = 100 - hd_intra_per_device
        avg_reliability = np.mean(reliability_per_device)
    else:
        print("Warning: Only 1 measurement provided. Reliability requires at least 2 measurements/files.")
        reliability_per_device = np.array([100.0] * K)
        avg_reliability = 100.0

    # print a summary
    print("-" * 40)
    print("PUF METRICS SUMMARY (Ideal Values in Parentheses)")
    print("-" * 40)
    print(f"Uniformity:    {avg_uniformity:.2f}% (Ideal: 50%)")
    print(f"Uniqueness:    {avg_uniqueness:.2f}% (Ideal: 50%)")
    print(f"Bit-aliasing:  {avg_bit_aliasing:.2f}% (Ideal: 50%)")
    if M > 1:
        print(f"Reliability:   {avg_reliability:.2f}% (Ideal: 100%)")
    print("-" * 40)

    # plotting
    fig, axs = plt.subplots(2, 2, figsize=(12, 10))
    fig.suptitle('PUF Characterization Metrics', fontsize=16)

    # Uniformity plot
    axs[0, 0].hist(uniformity_per_device, bins=30, color='skyblue', edgecolor='black')
    axs[0, 0].set_title(f'Uniformity\nAvg: {avg_uniformity:.2f}%')
    axs[0, 0].set_xlabel('Percentage of 1s (%)')
    axs[0, 0].set_ylabel('Frequency (Devices)')
    axs[0, 0].axvline(50, color='r', linestyle='dashed', linewidth=2, label='Ideal (50%)')
    axs[0, 0].legend()

    # Uniqueness plot
    axs[0, 1].hist(uniqueness_vals, bins=50, color='lightgreen', edgecolor='black')
    axs[0, 1].set_title(f'Uniqueness (Inter-chip HD)\nAvg: {avg_uniqueness:.2f}%')
    axs[0, 1].set_xlabel('Hamming Distance (%)')
    axs[0, 1].set_ylabel('Frequency (Pairs)')
    axs[0, 1].axvline(50, color='r', linestyle='dashed', linewidth=2, label='Ideal (50%)')
    axs[0, 1].legend()

    # Reliability plot
    axs[1, 0].hist(reliability_per_device, bins=30, color='salmon', edgecolor='black')
    axs[1, 0].set_title(f'Reliability\nAvg: {avg_reliability:.2f}%')
    axs[1, 0].set_xlabel('Reliability (%)')
    axs[1, 0].set_ylabel('Frequency (Devices)')
    axs[1, 0].axvline(100, color='r', linestyle='dashed', linewidth=2, label='Ideal (100%)')
    axs[1, 0].set_xlim([min(80, np.min(reliability_per_device)-5), 105])
    axs[1, 0].legend()

    # Bit-aliasing plot
    axs[1, 1].plot(range(N), bit_aliasing_per_bit, color='purple', alpha=0.7)
    axs[1, 1].set_title(f'Bit-aliasing\nAvg: {avg_bit_aliasing:.2f}%')
    axs[1, 1].set_xlabel('Bit Index')
    axs[1, 1].set_ylabel('Percentage of 1s (%)')
    axs[1, 1].axhline(50, color='r', linestyle='dashed', linewidth=2, label='Ideal (50%)')
    axs[1, 1].set_ylim([0, 100])
    axs[1, 1].legend()

    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    plt.savefig('docs/puf_metrics_plot.png')
    plt.show()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python puf_eval.py <file1.txt> <file2.txt> ...")
        print("Example: python puf_eval.py puf_data_*.txt")
        sys.exit(1)
        
    files = sys.argv[1:]
    data_matrix = load_data(files)
    
    if data_matrix.size > 0:
        evaluate_puf(data_matrix)
    else:
        print("Error: No valid data loaded.")