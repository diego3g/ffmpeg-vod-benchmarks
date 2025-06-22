# FFmpeg HLS Benchmark

Compares 9 different FFmpeg encoding approaches for creating HLS streams, measuring **speed**, **file size**, and **quality** trade-offs.

## Quick Start

```bash
# Make executable and run
chmod +x hls_benchmark.sh
./hls_benchmark.sh your-video.mp4
```

## Prerequisites

- FFmpeg installed
- Bash 3.2+ (works on macOS)
- Input video file

## What it tests

9 approaches across 4 resolutions (240p, 480p, 720p, 1080p):

1. **Baseline** - CRF 26, veryfast
2. **Ultrafast** - Maximum speed
3. **Superfast** - CRF 22 quality
4. **Fast + Film tune** - Film optimization
5. **Fast + Audio copy** - Skip audio encoding
6. **x264 Optimized** - Advanced parameters
7. **Multithreaded** - CPU optimization
8. **Segment First** - Pre-segment approach
9. **Concurrent Baseline** - Parallel resolution processing

## Example output

```
📊 APPROACH 2 COMPLETED: Ultrafast (CRF 26) took 00:00:13
   📁 Average 1080p segment size: 2.7 MB
   ✅ FASTER by 00:00:02 than previous approach

📊 APPROACH 9 COMPLETED: Concurrent Baseline (CRF 26, veryfast) took 00:00:15
   📁 Average 1080p segment size: 1.0 MB
   ✅ FASTER by 00:00:17 than previous approach

Results (sorted by speed):
1. 🏆 Ultrafast (CRF 26): 00:00:13 (FASTEST)
2. Baseline (CRF 26, veryfast): 00:00:15 (+15%)
3. Concurrent Baseline (CRF 26, veryfast): 00:00:15 (+15%)
...
```

## 📊 Benchmark Results

See [**benchmark_results.md**](benchmark_results.md) for complete test results with detailed analysis and recommendations.

## Quick recommendations

- **Live streaming**: Ultrafast preset
- **Storage-limited VOD**: Baseline (best compression)
- **High-quality VOD**: Superfast CRF 22
- **Multi-core systems**: Multithreaded approach
- **Experimental**: Concurrent Baseline (alternative processing pattern)

---

*Note: Processes first minute of video for faster benchmarking.* 