# FFmpeg HLS Benchmark Results

## Test Environment

- **Input video**: 14-local-first.mp4
- **Test duration**: First 1 minute of video
- **CPU**: 10 cores (using 8 threads for optimized approaches)
- **Total benchmark time**: 00:03:08
- **Date**: Generated using hls_benchmark.sh

## Results Summary

| Rank | Approach | Encoding Time | 1080p Segment Size | Performance | Configuration |
|------|----------|---------------|-------------------|-------------|---------------|
| 🏆 1 | **Ultrafast (CRF 26)** | 00:00:11 ⚡ | 2.7 MB | **FASTEST** | Ultrafast preset for maximum speed |
| 2 | **Baseline (CRF 26, veryfast)** | 00:00:14 | 1.0 MB 💾 | +27% | CRF 26, veryfast preset, AAC audio |
| 3 | **Superfast (CRF 22)** | 00:00:14 | 4.4 MB 📁 | +27% | Better quality with CRF 22 |
| 4 | **Fast + Audio copy** | 00:00:20 | 2.0 MB | +81% | Skips audio re-encoding |
| 5 | **Fast + Film tune** | 00:00:22 | 2.1 MB | +100% | Fast preset optimized for film |
| 6 | **Multithreaded (8 threads)** | 00:00:23 | 2.0 MB | +109% | Multi-core CPU utilization |
| 7 | **Segment First (Fast)** | 00:00:31 | 1.1 MB | +181% | Pre-segment then convert |
| 8 | **x264 Optimized** | 00:00:52 🐌 | 2.6 MB | +372% | Advanced x264 parameters |

## Performance Analysis

### Speed Rankings
- ⚡ **Fastest**: Ultrafast (11s) - 27% faster than baseline
- 🐌 **Slowest**: x264 Optimized (52s) - 372% slower than fastest

### File Size Rankings  
- 💾 **Smallest**: Baseline (1.0 MB) - Best compression ratio
- 📁 **Largest**: Superfast CRF 22 (4.4 MB) - Highest quality

## Key Insights

| Insight | Details |
|---------|---------|
| **Speed vs Size** | Ultrafast is 27% faster but produces 170% larger files than baseline |
| **Quality vs Speed** | Superfast CRF 22 produces highest quality at baseline speed |
| **Best Compression** | Baseline offers best compression ratio with good speed |
| **Audio Optimization** | Audio copy saves encoding time when audio quality is sufficient |
| **Multi-core Benefits** | Multithreading provides good balance for multi-core systems |
| **Segment Strategy** | Segment-first gives excellent compression but slower overall |

## Use Case Recommendations

| Use Case | Recommended Approach | Encoding Time | File Size | Reason |
|----------|---------------------|---------------|-----------|---------|
| **Live streaming** | Ultrafast | 00:00:11 | 2.7 MB | Maximum speed for real-time |
| **VOD with storage limits** | Baseline | 00:00:14 | 1.0 MB | Best compression ratio |
| **High-quality VOD** | Superfast CRF 22 | 00:00:14 | 4.4 MB | Balanced quality/speed |
| **Multi-core systems** | Multithreaded | 00:00:23 | 2.0 MB | Efficient CPU utilization |
| **Production workflows** | x264 Optimized | 00:00:52 | 2.6 MB | Maximum quality control |

## Technical Details

- **HLS segments**: 4 seconds each
- **Test duration**: First 60 seconds of input video  
- **Resolutions tested**: 240p, 480p, 720p, 1080p
- **File sizes**: Averages of 1080p segments only
- **Performance**: Relative to fastest approach (Ultrafast)

> **Note**: Results may vary based on video content, hardware specifications, and system load. 