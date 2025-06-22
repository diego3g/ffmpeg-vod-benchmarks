# FFmpeg HLS Benchmark Results

## Test Environment

- **Input video**: 14-local-first.mp4
- **Test duration**: First 1 minute of video
- **CPU**: 10 cores (using 8 threads for optimized approaches)
- **Total benchmark time**: 00:03:33
- **Date**: Generated using hls_benchmark.sh

## Results Summary

| Rank | Approach | Encoding Time | 1080p Segment Size | Performance | Configuration |
|------|----------|---------------|-------------------|-------------|---------------|
| 🏆 1 | **Ultrafast (CRF 26)** | 00:00:13 ⚡ | 2.7 MB | **FASTEST** | Ultrafast preset for maximum speed |
| 2 | **Baseline (CRF 26, veryfast)** | 00:00:15 | 1.0 MB 💾 | +15% | CRF 26, veryfast preset, AAC audio |
| 3 | **Superfast (CRF 22)** | 00:00:15 | 4.4 MB 📁 | +15% | Better quality with CRF 22 |
| 4 | **Concurrent Baseline (CRF 26, veryfast)** | 00:00:15 | 1.0 MB | +15% | Same as baseline but concurrent processing |
| 5 | **Fast + Audio copy** | 00:00:22 | 2.0 MB | +69% | Skips audio re-encoding |
| 6 | **Fast + Film tune** | 00:00:23 | 2.1 MB | +76% | Fast preset optimized for film |
| 7 | **Multithreaded (8 threads)** | 00:00:24 | 2.0 MB | +84% | Multi-core CPU utilization |
| 8 | **Segment First (Fast)** | 00:00:32 | 1.1 MB | +146% | Pre-segment then convert |
| 9 | **x264 Optimized** | 00:00:54 🐌 | 2.6 MB | +315% | Advanced x264 parameters |

## Performance Analysis

### Speed Rankings
- ⚡ **Fastest**: Ultrafast (13s) - 15% faster than baseline
- 🐌 **Slowest**: x264 Optimized (54s) - 315% slower than fastest

### File Size Rankings  
- 💾 **Smallest**: Baseline & Concurrent Baseline (1.0 MB) - Best compression ratio
- 📁 **Largest**: Superfast CRF 22 (4.4 MB) - Highest quality

### Concurrent Processing Insight
- **Concurrent Baseline** achieved the same performance as **Sequential Baseline** (both 15s)
- No speed improvement observed, indicating the system already efficiently utilizes resources
- Concurrent approach may benefit systems with higher I/O bottlenecks or different workload patterns

## Key Insights

| Insight | Details |
|---------|---------|
| **Speed vs Size** | Ultrafast is 15% faster but produces 170% larger files than baseline |
| **Quality vs Speed** | Superfast CRF 22 produces highest quality at baseline speed |
| **Best Compression** | Baseline offers best compression ratio with good speed |
| **Concurrent Processing** | No performance gain on this system - sequential processing already optimal |
| **Audio Optimization** | Audio copy saves encoding time when audio quality is sufficient |
| **Multi-core Benefits** | Multithreading provides good balance for multi-core systems |
| **Segment Strategy** | Segment-first gives excellent compression but slower overall |

## Use Case Recommendations

| Use Case | Recommended Approach | Encoding Time | File Size | Reason |
|----------|---------------------|---------------|-----------|---------|
| **Live streaming** | Ultrafast | 00:00:13 | 2.7 MB | Maximum speed for real-time |
| **VOD with storage limits** | Baseline | 00:00:15 | 1.0 MB | Best compression ratio |
| **High-quality VOD** | Superfast CRF 22 | 00:00:15 | 4.4 MB | Balanced quality/speed |
| **Multi-core systems** | Multithreaded | 00:00:24 | 2.0 MB | Efficient CPU utilization |
| **Production workflows** | x264 Optimized | 00:00:54 | 2.6 MB | Maximum quality control |
| **Experimental/Testing** | Concurrent Baseline | 00:00:15 | 1.0 MB | Alternative processing pattern |

## Technical Details

- **HLS segments**: 4 seconds each
- **Test duration**: First 60 seconds of input video  
- **Resolutions tested**: 240p, 480p, 720p, 1080p
- **File sizes**: Averages of 1080p segments only
- **Performance**: Relative to fastest approach (Ultrafast)
- **Total approaches tested**: 9 different encoding strategies

> **Note**: Results may vary based on video content, hardware specifications, and system load. Concurrent processing benefits may vary depending on system architecture and resource availability. 